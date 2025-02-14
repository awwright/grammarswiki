"use strict";
const assert = require('assert').strict;

// Include this property as a transition on a state that accepts
const final = Symbol('[FSM Final State]');

/* Represents a (Deterministic) Finite State Machine
A NON-deterministic Finite State Machine may be described with a PDA.
*/
class FSM {
	constructor(map, initial, finals){
		if (!Array.isArray(map)) {
			throw new Error('Expected `map` to be an Array');
		}
		map.forEach(function (st, i) {
			if (typeof st !== 'object') {
				throw new Error('Expected map[i] to be an object');
			}
			for (var symbol in st) {
				if (typeof st[symbol] !== 'number') {
					throw new Error('Expected map[' + JSON.stringify(i) + '][' + JSON.stringify(symbol) + '] to be a number, got ' + typeof st[symbol]);
				}
				if (st[symbol] >= map.length) {
					throw new Error('Expected map[' + JSON.stringify(i) + '][' + JSON.stringify(symbol) + '] to be a state in `fsm`');
				}
			}
		});

		this.states = map;
		this.initial = (typeof initial === 'number') ? initial : 0;
		if (this.states[this.initial] === undefined) throw new Error('`initial` not a state in `map`');
		this.finals = new Set(finals);
		Object.freeze(this.finals);
		Object.freeze(this);
	}

	/* Return the smallest alphabet necessary to produce an equivalent FSM.
	*/
	alphabet() {
		const self = this;
		const abc = new Set;
		self.states.forEach(function (transitions) {
			Object.keys(transitions).forEach(function (symbol) {
				abc.add(symbol);
			});
		});
		return abc;
	}

	/*
		Follow the given symbol from the given state (or set of states, or array of states)
	*/
	nextState(state, symbol){
		const self = this;
		assert(typeof state === 'number');
		// Return a number or undefined
		return self.states[state][symbol];
	}

	nextStateSet(states, symbol){
		const self = this;
		const nextStates = new Set;
		states.forEach(function(state){
			const next = self.states[state][symbol];
			if (next !== undefined) nextStates.add(next);
		})
		return nextStates;
	}

	nextStateArray(states, symbol){
		return [...this.nextStateSet(states, symbol)].sort();
	}

	/*
		Evaluate the supplied string against the FSM, return if it accepts.
	*/
	accepts(input){
		const self = this;
		// Permit an array or a string
		if (typeof input.length !== 'number') throw new Error;
		var state = self.initial;
		for(var i=0; i<input.length; i++){
			const symbol = input[i];
			if(!self.states[state] || self.states[state][symbol]===undefined){
				// Missing transition = transition to dead state
				if(this.dead_transition && this.dead_transition.has(symbol)){
					state = this.dead_transition.get(symbol);
					continue;
				}
				return false;
			}

			state = self.states[state][symbol];
		}
		return self.finals.has(state);
	}

	/* Generate a graphViz diagram for this FSM */
	toString(){
		const self = this;
		var str = '';
		str += 'digraph G {\n';
		str += '\t_initial [shape=point];\n';
		str += '\t_initial -> '+self.initial+';\n';
		self.states.forEach(function(transitions, state){
			const final = self.finals.has(state) ? ' [shape=doublecircle]' : '';
			str += '\t'+state+final+';\n';
			for(const symbol in transitions){
				str += '\t'+state+' -> '+transitions[symbol]+' [label='+JSON.stringify(symbol)+'];\n';
			}
		});
		str += '}\n';
		return str;
	}

	/* Execute a number of FSMs in parallel,
	producing a state for each different cross-product state that is used.
	This is a slightly optimized version of remap() below
	*/
	static parallel(fsms, final) {
		if (!Array.isArray(fsms)) throw new Error('Expected `fsms` to be an array of arrays');
		// fsms.forEach(verify);

		// By convention, start on the 0 state
		const cross_product_list = [fsms.map(v => v.initial)];
		// A handy mapping of each cross-product state to its reduced state
		const cross_product_map = new Map([[fsms.map(v => v.initial).join(','), 0]]);
		// The new states
		const combination_states = [];
		const combination_states_final = new Set;

		// iterate over a growing list
		for (var i = 0; i < cross_product_list.length; i++) {
			const state_i = cross_product_list[i];
			const state = state_i.map((i, j) => fsms[j].states[i]);

			// Compute the symbols used by each state
			// const alphabet = new Set(fsms.flatMap(v => [...v.transitions.keys()]));
			const alphabet = new Set(state.flatMap(fsm_st => fsm_st ? Object.keys(fsm_st) : []));

			// compute map for this state
			const transitions = {};
			for (const symbol of alphabet) {
				const next = state.map(function (fsm_st) {
					// Return undefined for the oblivion state
					return fsm_st && fsm_st[symbol];
				});
				// Generate a key name for this cross-product
				const nextKey = next.join(',');
				const nextId = cross_product_map.get(nextKey);
				if (nextId !== undefined) {
					// If there is already a state representing this cross-product, point to that
					transitions[symbol] = nextId;
				} else {
					// Create a new state
					transitions[symbol] = cross_product_list.length;
					cross_product_map.set(nextKey, cross_product_list.length);
					cross_product_list.push(next);
				}
			}

			combination_states[i] = transitions;
			if (final(state_i.map((j, k) => fsms[k].finals.has(j)))) combination_states_final.add(i);
		}

		return new FSM(combination_states, 0, combination_states_final);
	}

	union() {
		const fsms = Array.prototype.concat.apply([this], arguments);
		return FSM.parallel(fsms, v => v.some(w => w));
	}

	static union(fsms) {
		function final_union(states) {
			if (states.some(final => final && (Array.isArray(final) ? final.length : final))) {
				const items = states.flatMap(final => (final && Array.isArray(final)) ? final : []);
				return items.length ? items : true;
			} else {
				return false;
			}
		}
		return FSM.parallel(fsms, final_union);
	}

	optional() {
		return epsilon().union(this);
	}

	reduce() {
		// Take Brzozowski's Algorithm for FSM minimization
		// There may be faster ways to do this, e.g.
		// <http://www.cs.ru.nl/bachelors-theses/2017/Erin_van_der_Veen___4431200___The_Practical_Performance_of_Automata_Minimization_Algorithms.pdf>
		return this.reverse().reverse();
	}

	/*
	Follows a non-deterministic path given by next, and produce another FSM as output.
	*/
	static remap(initial, alphabet, next, final) {
		if (!Array.isArray(initial)) throw new Error('Expected `initial` to be an array');

		// Keep track of all of the states we are crawling, potentially many at the same time
		const new_state_to_old_states_map = [initial];
		// A handy mapping of each combination of states to a reduced state
		const old_states_to_new_state_id_map = new Map([[initial.join(';'), 0]]);
		// The new states
		const new_states_transitions = [];
		const new_final_states = new Set;

		// iterate over a growing list
		for (var i = 0; i < new_state_to_old_states_map.length; i++) {
			// Compute the symbols used by each state
			const cross_product = new_state_to_old_states_map[i];
			const state_alphabet = alphabet(cross_product);

			// compute map for this state
			const transitions = {};
			for (const symbol of state_alphabet) {
				// `next` can return multiple results, e.g. concatenation,
				// where a state machine can keep moving to another state in the same machine,
				// OR can jump to the initial state of the next FSM. This is "non-deterministic".
				const nextStatesMap = next(cross_product, symbol);
				const nextStates = nextStatesMap.values().toArray().sort();
				// console.log(i, symbol, nextStates);
				// Generate a key name for this cross-product
				const nextKey = nextStates.join(';');
				const nextId = old_states_to_new_state_id_map.get(nextKey);
				if (nextId !== undefined) {
					// If there is already a state representing this cross-product, point to that
					assert.equal(typeof nextId, 'number');
					transitions[symbol] = nextId;
				} else {
					// Create a new state
					transitions[symbol] = new_state_to_old_states_map.length;
					assert.equal(typeof new_state_to_old_states_map.length, 'number');
					old_states_to_new_state_id_map.set(nextKey, new_state_to_old_states_map.length);
					new_state_to_old_states_map.push(nextStates);
				}
			}

			new_states_transitions[i] = transitions;
			var final_state_i = final(cross_product);
			// console.log(i, cross_product, final_state_i);
			if (final_state_i) new_final_states.add(i);
		}

		return new FSM(new_states_transitions, 0, new_final_states);
	}

	concatenate(){
		const fsms = Array.prototype.concat.apply([this], arguments);
		return FSM.concatenate.apply(null, fsms);
	}

	static concatenate(){
		// Essentially, map the given FSMs to a NFA, then compile to a FSM (DFA)
		const fsms = Array.prototype.slice.apply(arguments);

		if (fsms.length === 0) return epsilon();

		function connect_epsilons(fsm_i, substate) {
			// Connect the FSMs together by an implicit epsilon-transition from each final state
			// to the initial state in the next FSM.
			const result = [ [fsm_i, substate] ];
			// Make sure to follow epsilons recursively
			for (var i = fsm_i; i < fsms.length - 1 && fsms[i].finals.has(substate);) {
				i++
				substate = fsms[fsm_i].initial;
				result.push([i, substate]);
			}
			return result;
		}

		// Use a superset containing states from all FSMs at once.
		// We start at the start of the first FSM. If this state is final in the
		// first FSM, then we are also at the start of the second FSM. And so on.
		var initial = fsms.length ? connect_epsilons(0, fsms[0].initial) : [];

		function alphabet(states){
			const state_fsms = states.map((v) => [v[0], fsms[v[0]].states[v[1]]]).filter(v => v[1]);
			return new Set(state_fsms.flatMap(fsm_st => fsm_st ? Object.keys(fsm_st[1]) : []));
		}

		function next(current, symbol) {
			var states = new Map;
			function add(fsm_i, state) {
				const key = fsm_i + ',' + state;
				if (!states.has(key)) states.set(key, [fsm_i, state]);
			}
			current.forEach(function (val) {
				const [fsm_i, substate] = val;
				var fsm = fsms[fsm_i];
				if (!fsm) return;
				const transitions = fsm.states[substate];
				if (!transitions) return;
				if (transitions[symbol] !== undefined) {
					connect_epsilons(fsm_i, transitions[symbol]).forEach(v => add(v[0], v[1]));
				}
			});
			return states;
		}

		function final(state_list) {
			/// If you're in a final state of the final FSM, it's final
			return state_list.some(function (state_val) {
				const [fsm_i, substate] = state_val;
				return fsm_i == fsms.length - 1 && fsms[fsm_i].finals.has(substate);
			});
		}
	
		return FSM.remap(initial, alphabet, next, final);
	}

	star() {
		const self = this;
		const initial = [self.initial];

		function alphabet(states) {
			const state_fsms = states.map((v) => self.states[v]).filter(v => (v!==undefined));
			return new Set(state_fsms.flatMap(fsm_st => fsm_st ? Object.keys(fsm_st) : []));
		}

		function next(current, symbol) {
			var states = [];
			current.forEach(function (substate) {
				const transitions = self.states[substate];
				if (transitions && transitions[symbol]!==undefined) {
					// Follow transitions normally
					if (!states.some(v => (v === transitions[symbol]))){
						states.push(transitions[symbol]);
					}
					// If this is a final state, also follow from the initial
					if (self.finals.has(transitions[symbol]) && !states.some(v => (v === self.initial))) {
						states.push(self.initial);
					}
				}
			});
			return states;
		}

		function final(state_list) {
			return state_list.some(function (state_val) {
				return self.finals.has(state_val);
			});
		}

		return FSM.remap(initial, alphabet, next, final).optional();
	}

	// Run a variation of concat and star
	// maxRepeat may also be 1/0 = Math.POSITIVE_INFINITY
	repeat(minRepeat, maxRepeat) {
		if (!(minRepeat >= 0)) {
			throw new Error('Expected minRepeat >= 0');
		}
		if (!(minRepeat <= maxRepeat)){
			throw new Error('Expected minRepeat <= maxRepeat');
		}
		const self = this;
		// If no limit, then use minRepeat
		const fsms = (maxRepeat >= 1 / 0) ? new Array(minRepeat).fill(self) : new Array(maxRepeat).fill(self);
		const initial = [[0, self.initial]];

		function alphabet(states) {
			const state_fsms = states.map((v) => [v[0], fsms[v[0]].states[v[1]]]).filter(v => v[1]);
			return new Set(state_fsms.flatMap(fsm_st => fsm_st ? Object.keys(fsm_st[1]) : []));
		}

		function next(current, symbol) {
			var states = new Map;
			function add(fsm_i, state) {
				const key = fsm_i + ',' + state;
				if (!states.has(key)) states.set(key, [fsm_i, state]);
			}
			current.forEach(function (val) {
				const [fsm_i, substate] = val;
				var fsm = fsms[fsm_i];
				if (!fsm) return;
				const transitions = fsm.states[substate];
				if (transitions && transitions[symbol] !== undefined) {
					// Follow transitions normally
					add(fsm_i, transitions[symbol]);
					// If this is a final state, also follow from the initial
					if (self.finals.has(transitions[symbol])) {
						if (fsms[fsm_i + 1]){
							add(fsm_i+1, self.initial);
						} else if (maxRepeat === 1/0) {
							add(fsm_i, self.initial);
						}
					}
				}
			});
			return states;
		}

		function final(state_list) {
			return state_list.some(function (state_val) {
				// the 0th FSM tests for the 1st repeat, so add +1
				return state_val[0]+1>=minRepeat && state_val[0]+1<=maxRepeat && self.finals.has(state_val[1]);
			});
		}

		if(minRepeat === 0){
			// The final callback doesn't make an epsilon input final, so add it now
			return FSM.remap(initial, alphabet, next, final).optional();
		}else{
			return FSM.remap(initial, alphabet, next, final);
		}
	}

	static intersection(){
		const fsms = Array.prototype.concat.apply([], arguments);
		return FSM.parallel(fsms, v=>v.every(w=>w))
	}

	/* Find the FSM that accepts strings accepted by all of the given FSMs
	*/
	intersection(){
		const fsms = Array.prototype.concat.apply([this], arguments);
		return FSM.parallel(fsms, v=>v.every(w=>w))
	}
	
	/* Find the FSM that accepts strings accepted by one of the two (or odd number) of FSMs
	*/
	symmetric_difference(fsm){
		if(arguments.length===1){
			return FSM.parallel([this, fsm], (accepts)=>(accepts.filter(v=>v).length % 2) );
		}else{
			const fsms = Array.prototype.concat.apply([this], arguments);
			return FSM.parallel(fsms, (accepts)=>(accepts.filter(v=>v).length % 2));
		}
	}
	/* Find a FSM where all the strings are in exclusively one or the other
	i.e. similar to xor
	*/
	static symmetric_difference(fsms){

		if(arguments.length===1){
			return FSM.parallel(fsms, (accepts)=>(accepts.filter(v=>v).length % 2));
		}else{
			const fsms = Array.prototype.slice.apply(arguments);
			return FSM.parallel(fsms, (accepts)=>(accepts.filter(v=>v).length % 2));
		}
	}

	/* Find inverse with respect to some alphabet */
	inverse(alphabet){
		if (alphabet){
			return this.symmetric_difference(language(alphabet));
		} else {
			// Warning, this is liable to have odd behavior for symbols that always
			// transition to oblivion states, depending on if there's arrows
			// or implicit oblivion
			return this.symmetric_difference(this.alphabet());
		}
	}

	/*
		Return a new FSM that accepts any string this would accept supplied backwards
		e.g. /abcd/ becomes /dcba/
	*/
	// TODO: This can probably be rewritten as a NFA (non-deterministic FSM)
	reverse(){
		const self = this;
		// The start of the FSM is every possible final state
		const initial = self.finals.values().toArray().map(v => [0, v]);

		// Walk the paths backwards
		const reverse = self.states.map(_ => ({}));
		self.states.forEach(function (symbols, left) {
			for (const symbol in symbols){
				const right = symbols[symbol];
				reverse[right][symbol] = reverse[right][symbol] || new Set;
				reverse[right][symbol].add(left);
			}
		});

		function alphabet(states){
			return new Set(states.flatMap(fsm_st => Object.keys(reverse[fsm_st[1]])));
		}

		function next(current, symbol) {
			var states = new Map;
			function add(fsm_i, state) {
				const key = fsm_i + ',' + state;
				if (!states.has(key)) states.set(key, [fsm_i, state]);
			}
			current.forEach(function (val) {
				const [fsm_i, substate] = val;
				if (reverse[substate][symbol]){
					reverse[substate][symbol].forEach(v => add(0, v));
				}
			});
			return states;
		}

		// Does this combination contain any initial state?
		function final(state_list) {
			return state_list.some(function (state_val) {
				return state_val[1] === self.initial;
			});
		}

		return FSM.remap(initial, alphabet, next, final);
	}

	/* Simple way to compare the size of two languages */
	compare(fsm){
		return fsm.compare([this, fsm]);
	}

	/* Simple way to compare the size of two languages */
	static compare(fsms) {
		if (fsms.length !== 2) {
			throw new Error('Expected 2 fsms to compare');
		}
		var isSuperset = true, isSubset = true, isDisjoint = true;
		function final_union(states) {
			const a = Array.isArray(states[0]) ? states[0].length : states[0];
			const b = Array.isArray(states[1]) ? states[1].length : states[1];
			if (!a && b) isSuperset = false;
			if (a && !b) isSubset = false;
			if (!!a && !!b) isDisjoint = false; // set to false when there are some final elements in common
		}
		FSM.parallel(fsms, final_union);
		return [isSuperset, isSubset, isDisjoint];
	}

	islive(state){
		const self = this;
		// A state is "live" if a final state can be reached from it.
		const reachable = [state];
		for(var i=0; i<reachable.length; i++){
			const current = reachable[i];
			if(self.finals.has(current)){
				return true;
			}
			if(self.states[current]){
				Object.keys(self.states[current]).forEach(function(symbol){
					const next = self.states[current][symbol];
					if(reachable.indexOf(next) < 0){
						reachable.push(next);
					}
				});
			}
		}
		return false;
	}

	/*
		An FSM is empty if it recognizes no strings. An FSM may be arbitrarily
		complicated and have arbitrarily many final states while still recognizing
		no strings because those final states may all be inaccessible from the
		initial state. Equally, an FSM may be non-empty despite having an empty
		alphabet if the initial state is final.
	*/
	empty(){
		return !this.islive(this.initial);
	}

	/* Produce a list of strings accepted by this FSM
	*/
	*strings(){
		const self = this;

		// Many FSMs have "dead states". Once you reach a dead state, you can no
		// longer reach a final state. Since many strings may end up here, it's
		// advantageous to constrain our search to live states only.
		const live = self.states.map((_, state)=>self.islive(state));

		// We store a list of tuples. Each tuple consists of an input string and the
		// state that this input string leads to. This means we don't have to run the
		// state machine from the very beginning every time we want to check a new
		// string.
		const strings = [];
		const states = [];

		// Initial entry (or possibly not, in which case this is a short one)
		if (live[self.initial]){
			if (self.finals.has(self.initial)){
				yield [];
			}
			strings.push([]);
			states.push(self.initial);
		}
		const alphabets = self.states.map(function(s){
			return Object.keys(s).sort();
		});

		for(var i=0; i<strings.length; i++){
			const string = strings[i];
			const state = states[i];
			const alphabet = alphabets[state];
			if(!self.states[state]) continue;
			for (var j = 0; j < alphabet.length; j++){
				const symbol = alphabet[j];
				const nstate = self.states[state][symbol];
				const nstring = string.concat([symbol]);
				if(live[nstate]){
					if(self.finals.has(nstate)){
						yield nstring;
					}
					strings.push(nstring);
					states.push(nstate);
				}
			}
		}
	}

	equivalent(other){
		return this.symmetric_difference(other).empty();
	}

	/* Find this FSM, removing all strings in `other` */
	relative_compliment(other){
		const fsms = Array.prototype.concat.apply([this], arguments);
		return FSM.parallel(fsms, (accepts)=>(accepts.every( (v,w)=>(!v !== !w) )) );
	}

	static relative_compliment(){
		const fsms = Array.prototype.slice.call(arguments);
		return FSM.parallel(fsms, (accepts)=>(accepts.every( (v,w)=>(!v !== !w) )) );
	}

	/* cardinality describes the size of a set;
	the size of a language generated by a FSM is either an unsigned integer or infinity
	*/
	cardinality(){
		const self = this;
		// Cache the cardinality of this FSM
		if(Object.isFrozen(this) && fsm_cardinality.has(this)){
			return fsm_cardinality.get(this);
		}
		const num_strings = new Map;
		const cardinality = get_num_strings(this.initial);
		if(Object.isFrozen(this)){
			fsm_cardinality.set(this, cardinality);
		}
		return cardinality;

		function get_num_strings(state){
			// Many FSMs have at least one oblivion state
			if(self.islive(state)){
				if (num_strings.has(state)){
					if(num_strings.get(state) === null){ // "computing..."
						// Recursion! There are infinitely many strings recognised
						// throw new OverflowError(state);
						return 1/0;
					}
					return num_strings.get(state);
				}
				num_strings.set(state, null); // i.e. "computing..."

				var n = 0;
				if(self.finals.has(state)){
					n += 1;
				}
				if(self.states[state]){
					self.states[state].forEach(function(transition){
						n += get_num_strings(transition);
					});
				}
				num_strings.set(state, n);
			}else{
				// Dead state
				num_strings.set(state, 0);
			}

			return num_strings.get(state);
		}
	}

	get length() {
		return this.cardinality();
	}

	/* Create an FSM that starts off after the given input */
	derive(input){
		const self = this;
		// Consume the input string.
		var state = self.initial;
		// Allow for an array or a string
		for(var i=0; i<input.length; i++){
			const symbol = input[i];
			// Missing transition = transition to dead state
			if(!self.states[state] || self.states[state][symbol]===undefined){
				return nil();
			}
			state = self.states[state][symbol];
		}
		return new FSM(self.states, state, self.finals);
	}
}

/* An FSM that accepts nothing.
*/
function nil(){
	return new FSM([{}], 0, []);
}

/* An FSM that accepts only the empty string.
*/
function epsilon() {
	return new FSM([{}], 0, [0]);
}

/* An FSM that accepts only the empty string.
*/
function singleton(string) {
	const states = Array.from({length: string.length}).map(function(_, i){
		return {[string[i]]: i+1};
	}).concat([{}]);
	return new FSM(states, 0, [string.length]);
}

/* a FSM that accepts all inputs made up from the given alphabet */
function language(alphabet) {
	assert(typeof alphabet.forEach === 'function', 'alphabet must be an array/Set');
	const transitions = {};
	alphabet.forEach(symbol => { transitions[symbol] = 0 });
	return new FSM([transitions], 0, [0]);
}

module.exports = { FSM, nil, epsilon, singleton, language, final };
