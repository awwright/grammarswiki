'use strict';

const assert = require('assert').strict;
const { PDA } = require('../lib/pda.js');

describe('NFA', function(){
	it('Even number of 0s and 1s', function test_happy() {
		const dfa = PDA.fromNFA(
			[0, 1, 2, 3],
			[ '0', '1' ],
			[
				[ 0, '0', [2] ],
				[ 0, '1', [1] ],
				[ 1, '0', [3] ],
				[ 1, '1', [0] ],
				[ 2, '0', [0] ],
				[ 2, '1', [3] ],
				[ 3, '0', [1] ],
				[ 3, '1', [2] ],
			],
			0,
			[ 0 ]
		);
		assert(dfa.accepts(''));
		assert(dfa.accepts('00'));
		assert(dfa.accepts('11'));
		assert(dfa.accepts('0011'));
		assert(dfa.accepts('1100'));
		assert(dfa.accepts('0101'));
		assert(dfa.accepts('1010'));
		assert(dfa.accepts('1001'));
		assert(dfa.accepts('0110'));
		assert(!dfa.accepts('0'));
		assert(!dfa.accepts('1'));
		assert(!dfa.accepts('0111'));
		assert(!dfa.accepts('1011'));
		assert(!dfa.accepts('1101'));
		assert(!dfa.accepts('1110'));
	});

	it('Ends in 01', function test_happy() {
		const nfa = PDA.fromNFA(
			[0, 1, 2],
			[ '0', '1' ],
			[
				[ 0, '0', [ 0, 1 ] ],
				[ 0, '1', [ 0 ] ],
				[ 1, '1', [ 2 ] ],
			],
			0,
			[ 2 ]
		);
		assert(nfa.accepts('01'));
		assert(nfa.accepts('001'));
		assert(nfa.accepts('101'));
		assert(nfa.accepts('0001'));
		assert(nfa.accepts('0101'));
		assert(nfa.accepts('1001'));
		assert(nfa.accepts('1101'));
		assert(!nfa.accepts(''));
		assert(!nfa.accepts('0'));
		assert(!nfa.accepts('1'));
		assert(!nfa.accepts('00'));
		assert(!nfa.accepts('10'));
		assert(!nfa.accepts('11'));
		assert(!nfa.accepts('000'));
		assert(!nfa.accepts('010'));
		assert(!nfa.accepts('011'));
		assert(!nfa.accepts('100'));
		assert(!nfa.accepts('110'));
		assert(!nfa.accepts('111'));
		assert(!nfa.accepts('0100'));
		assert(!nfa.accepts('0110'));
		assert(!nfa.accepts('0111'));
		assert(!nfa.accepts('10111'));
		assert(!nfa.accepts('010101010101010101011'));
	});

	it('Convert NFA to FSM');
});
