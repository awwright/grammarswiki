"use strict";

// An Instantaneous Description is a representation of a Pushdown Automata at a particular point in the course of processing the input.
// Consuming an input (or performing an epsilon transition) will cause the ID of the state machine to change to one of the described states and may modify the top of the stack.
function ID(state, stack){
	this.state = state;
	this.stack = stack;
}
ID.prototype.toString = function toString() {
	const self = this;
	return `(${self.state}, ${self.stack.join('')})`;
}
ID.prototype.matchesTop = function (state, stack_top) {
	const self = this;
	return self.state===state && self.stack[self.stack.length-1]===stack_top;
}
ID.prototype.matchesFinal = function (final_states) {
	const self = this;
	return final_states.some(state => self.state===state);
}
ID.prototype.transition = function(state, stack){
	const self = this;
	return new ID(state, self.stack.slice(0, self.stack.length-1).concat(stack));
}

// A PDA is a PushDown Automata. It is capable of describing resurcive regular structures.
function PDA(states, input_alphabet, stack_alphabet, transitions, initial_state, initial_symbol, final_states){
	this.states = states;
	this.input_alphabet = input_alphabet;
	this.stack_alphabet = stack_alphabet;
	this.transitions = transitions;
	this.initial_state = initial_state;
	this.initial_symbol = initial_symbol;
	this.final_states = final_states;
}

PDA.fromNFA = function fromNFA(states, input_alphabet, transitions, initial_state, final_states){
	// A NFA/Nondeterministic FSM is just a PDA that doesn't add to (change the size of) the stack.
	const pda_transitions = transitions.map(function(tr){
		return [ tr[0], tr[1], 'Z', tr[2].map(state => [ state, ['Z'] ]) ];
	});
	return new PDA(states, input_alphabet, ['Z'], pda_transitions, initial_state, 'Z', final_states);
}

PDA.prototype.toString = function toString(){
	const transitions = this.transitionsString();
	return `({${this.states}}, {${this.input_alphabet}}, {${this.stack_alphabet}}, {\n${transitions}}, ${this.initial_state}, ${this.initial_symbol}, {${this.final_states}})`;
}

PDA.prototype.transitionsString = function toString(){
	function input(v){
		const s = (v[1] === null) ? 'ε' : v[1];
		return `\t${v[0]}, ${s}, ${v[2]} → {${v[3].map(output).join(',')}}`;
	}
	function output(v){
		return `(${v[0]}, ${v[1]})`;
	}
	return this.transitions.map(input).join('\n') + '\n';
}

PDA.prototype.toHTML = function toHTML(){

}

PDA.prototype.alphabet = function alphabet(){
	const self = this;
	const abc = new Set;
	self.states.forEach(function (transitions) {
		Object.keys(transitions).forEach(function (symbol) {
			abc.add(symbol);
		});
	});
	return abc;
}

PDA.prototype.toEmptyStackPDA = function toEmptyStackPDA(){
	// Convert a final-state PDA to an empty-stack (null) PDA.
}

PDA.prototype.toFinalStatePDA = function toFinalStatePDA(){
	// Convert a final-state PDA to an empty-stack (null) PDA.
}

PDA.prototype.matchTransitions = function matchTransitions(state, symbol, stack_top) {
	return this.transitions.filter(function(transition){
		return state === transition[0] && symbol === transition[1] && stack_top===transition[2];
	}).flatMap(function(transition){
		return transition[3];
	});
}

PDA.prototype.derive = function derive(input) {
	// Convert an empty-stack (null) PDA to a final-state PDA.
	const self = this;
}

PDA.prototype.accepts = function accepts(input) {
	const self = this;

	// The PDA is non-deterministic, so keep an array of all concurrent execution states
	// and evaluate them simultaneously
	var states = [new ID(self.initial_state, [self.initial_symbol])];

	// Follow ε-transitions until there's no more in the state list
	function resolveε(){
		for(var i=0; i<states.length; i++){
			const transitions = self.matchTransitions(states[i].state, null, states[i].stack[states[i].stack.length-1]);
			for (var j = 0; j < transitions.length; j++){
				states.push(states[j].transition(transitions[j][0], transitions[j][1]));
			}
		}
	}
	resolveε();

	// Step through each input, compute the new set of states
	for(var i=0; i<input.length; i++){
		const symbol = input[i];
		states = states.flatMap(function(id) {
			return self.matchTransitions(id.state, symbol, id.stack[id.stack.length-1]).map(function (newpair) {
				return id.transition(newpair[0], newpair[1]);
			});
		});
		if (states.length === 0) break;
		resolveε();
	}

	// Determine which of the states are accepting
	if (this.final_states){
		return states.some(st => st.matchesFinal(self.final_states));
	}else{
		return states.some(st => (st.stack.length===0));
	}
}

PDA.prototype.toGrammar = function toGrammar(Grammar){
	// Convert a final-state PDA to an empty-stack (null) PDA.
	// Convert to a PDA that accepts by null stack, then convert that to a grammar.
	return this.toNPDA().toGrammar();
}

// Taking the union of two PDAs is easy, combine the state transitions
// and point to the initial states from an epsilon transition.
// Or just 
PDA.union = function union(pdas){
	const state_offsets = pdas.map(_ => 0);

    // Define the transition function of the union PDA
    const δ3 = {};
	// Step through the possible inputs of the transition function δ
    for (const q in δ) {
        for (const σ in δ[q]) {
            for (const γ of δ[q][σ]) {
                const [q_, γ_] = δ[q][σ][γ];
                if (δ2.hasOwnProperty(q_) && δ2[q_][σ].has(γ_)) {
                    δ3[`${q},${σ}`] = δ3[`${q},${σ}`] || new Map();
                    δ3[`${q},${σ}`].set(`${γ}`, [q_, γ_]);
                } else if (δ2.hasOwnProperty(q_) && !δ2[q_][σ].has(γ_)) {
                    δ3[`${q},${σ}`] = δ3[`${q},${σ}`] || new Map();
                    δ3[`${q},${σ}`].set(`${γ}`, [q_, γ]);
                }
            }
        }
    }

    // Combine the accepting states
    const F3 = [...F, ...F2];

    return {
        Σ: Σ3,
        Γ: Γ3,
        δ: δ3,
        q0: q0,
        F: F3
    };

}

module.exports = {ID, PDA};
