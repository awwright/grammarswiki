"use strict";
const assert = require('assert').strict;

// Include this property as a transition on a state that accepts
const final = Symbol('[FSM Final State]');


const ε = Symbol('[Epsilon Transition]');


/* Represents a Non-deterministic Finite State Machine
This doesn't need to have many features except the ability to 
*/
class NFA {
	constructor(states, initial, finals){
		if (!Array.isArray(states)) {
			throw new Error('Expected `map` to be an Array');
		}
		states.forEach(function (state) {
			assert(typeof state === 'object');
			for (var symbol in state) {
				state[symbol].forEach( v => assert(typeof v === 'number') );
				state[symbol].forEach( v => assert(v < states.length) );
			}
		});

		this.states = states;
		this.initial = (typeof initial === 'number') ? initial : 0;
		if (this.states[this.initial] === undefined) throw new Error('`initial` not a state in `map`');
		this.finals = new Set(finals);
		Object.freeze(this.finals);
		Object.freeze(this);
	}

	/* Return the smallest alphabet necessary to produce an equivalent FSM.
	*/
	alphabet(states) {
		const self = this;
		if(states === undefined){
			states = self.states;
		}else if(Array.isArray(states)){
			states = states.map(v => self.states[v]);
		}else if(typeof states.toArray === 'function'){
			states = states.toArray().map(v => self.states[v]);
		}
		const abc = new Set;
		states.forEach(function (transitions) {
			Object.keys(transitions).forEach(function (symbol) {
				abc.add(symbol);
			});
		});
		return abc;
	}

	// Use this when you need the states in a sorted order
	alphabetArray(states) {
		return [...this.alphabet(states)].sort();
	}

	getAllSet(states){
		// I'm just going to assume for the time being that
		// Array#indexOf is cheaper most of the time
		return new Set(this.getAllArray(states));
	}

	getAllArray(states){
		const self = this;
		if (typeof states === 'number') states = [states];
		const expanded = [...states];
		states.forEach(function (state) {
			const transitions = self.states[state][ε];
			if (transitions === undefined) return;
			for (var j = 0; j < transitions.length; j++) {
				if (expanded.indexOf(transitions[j]) === -1) expanded.push(transitions[j]);
			}
		});
		return expanded.sort();
	}

	nextStateSet(states, symbol) {
		const self = this;
		if(typeof states === 'number') states = [states];

		if (symbol === undefined || symbol === ε) {
			return this.getAll([...states]);
		}

		if (typeof states === 'number') {
			// Return a number or undefined
			return self.states[states][symbol] ? this.getAll(self.states[states][symbol]) : new Set([]);
		} else if (Array.isArray(states) || states instanceof Set) {
			// Return a Set (possibly empty)
			const newStates = new Set;
			states.forEach(function (st) {
				const newState = self.states[st][symbol];
				if (newState === undefined) return;
				newState.forEach(function (v) {
					if (typeof v === 'number') newStates.add(v);
				});
			});
			return self.getAllSet(newStates);
		}
	}

	nextStateArray(states, symbol){
		return [...this.nextStateSet(states, symbol)].sort();
	}

	/*
		Evaluate the supplied string against the FSM, return if it accepts.
	*/
	accepts(input){
		const self = this;
		var current = Array.isArray(self.initial) ? self.initial : [self.initial];
		for(var i=0; i<input.length; i++){
			current = self.nextStateArray(current, input[i]);
			if(current.length === 0) return false;			
		}
		return current.some(v => self.finals.has(v));
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
				transitions[symbol].forEach(function(target){
					const label = JSON.stringify(symbol || 'ε');
					str += '\t' + state + ' -> ' + target + ' [label=' + label + '];\n';
				});
			}
		});
		str += '}\n';
		return str;
	}

	union() {
		// TODO add the additional FSMs and point to them from the initial state with an epsilon-transition
	}

	static union(fsms) {
		// TODO add the additional FSMs and point to them from the initial state with an epsilon-transition
	}

	optional() {
		return epsilon().union(this);
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

		return new NFA(new_states_transitions, 0, new_final_states);
	}

	concatenate(){
		// This is also easily modeled as an epsilon-transition from final states to the next initial state
	}

	static concatenate(){
		// This is also easily modeled as an epsilon-transition from final states to the next initial state
	}

	star() {
		// This is just the current FSM with an epsilon transition from final states to the initial
	}

	repeat(minRepeat, maxRepeat) {
		// This is just a special case of concat()
	}

	/*
		Return a new FSM that accepts any string this would accept supplied backwards
		e.g. /abcd/ becomes /dcba/
	*/
	reverse(){
		// Literally just reverse all of the transitions and initial-final states, and return it
	}

	/*
		Create a new FSM that translates from one symbol (or sequence of symbols) to another.
		This can convert grammars between different character sets, e.g. UTF-8 to UTF-16.
		Accept a mapping of symbols, or a function.
	*/
	homomorphism(symbol_mapping){
		const self = this;
		// Use a function to produce different new empty objects for every state
		const new_states = self.states.map(v => ({}));
		for(var source=0; source<self.states.length; source++){
			for(var [sourceSymbols, targetSymbols] of symbol_mapping){
				var targetStates = new Set([source]);
				if(!Array.isArray(sourceSymbols)) sourceSymbols = [sourceSymbols];
				if (!Array.isArray(targetSymbols)) targetSymbols = [targetSymbols];
				for(var sourceSymbol of sourceSymbols){
					targetStates = self.nextStateSet(targetStates, sourceSymbol);
				}
				targetStates.forEach(function(target){
					if (targetSymbols.length === 0) {
						// Add an epsilon-transition between source and target
						addTransition(source, ε, target);
					}else{
						var intermediate = source;
						for (var i = 0; i < targetSymbols.length - 1; i++) {
							var current = new_states.length;
							new_states[current] = {};
							addTransition(intermediate, targetSymbols[i], current);
							intermediate = current;
						}
						addTransition(intermediate, targetSymbols[targetSymbols.length - 1], target);
					}
				});
			}
		}

		function addTransition(source, symbol, target){
			// console.log(`${source} --${symbol}--> ${target}`);
			const transitions = new_states[source] = new_states[source] || {};
			const targets = transitions[symbol] = transitions[symbol] || [];
			targets.push(target);
		}
		return new NFA(new_states, self.initial, self.finals);
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
			if (self.states[current]){
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

	/* Create an FSM that starts off after the given input */
	derive(input){
	}
}

/* An FSM that accepts nothing.
*/
function nil(){
	return new NFA([{}], 0, []);
}

/* An FSM that accepts only the empty string.
*/
function epsilon() {
	return new NFA([{}], 0, [0]);
}

/* An FSM that accepts only the empty string.
*/
function singleton(string) {
	const states = Array.from({length: string.length}).map(function(_, i){
		return {[string[i]]: [i+1]};
	}).concat([{}]);
	return new NFA(states, 0, [string.length]);
}

/* a FSM that accepts all inputs made up from the given alphabet */
function language(alphabet) {
	assert(typeof alphabet.forEach === 'function', 'alphabet must be an array/Set');
	const transitions = {};
	alphabet.forEach(symbol => { transitions[symbol] = 0 });
	return new NFA([transitions], 0, [0]);
}

module.exports = { NFA, ε, nil, epsilon, singleton, language, final };
