'use strict';

const assert = require('assert').strict;
const { PDA } = require('../lib/pda.js');

function FromTop(){
	return Array.from(arguments).reverse();
}

const ε = null;

describe('PDA', function(){
	function accept_a() {
		// Accepts "a", also has "b" in alphabet
		return new PDA(
			[ // map
				{ "a": 1, "b": 2 },
				{ "a": 2, "b": 2 },
				{ "a": 2, "b": 2 },
			],
			0, // initial
			[1], // finals
		);
	}

	function accept_b() {
		// accepts "b", also has "a" in alphabet
		return new PDA(
			[ // map
				{ "a": 2, "b": 1 },
				{ "a": 2, "b": 2 },
				{ "a": 2, "b": 2 },
			],
			0, // initial
			[1], // finals
		);
	}

	it('L_wwr', function test_happy() {
		const a = new PDA(
			[0,1,2], // states
			['0','1'], // input_alphabet
			['0','1','Z'], // stack_alphabet
			[ // transitions
				[ 0, '0', 'Z', [ [0, FromTop('0', 'Z')] ] ],
				[ 0, '1', 'Z', [ [0, FromTop('1', 'Z')] ] ],

				[ 0, '0', '0', [ [0, FromTop('0', '0')] ] ],
				[ 0, '0', '1', [ [0, FromTop('0', '1')] ] ],
				[ 0, '1', '0', [ [0, FromTop('1', '0')] ] ],
				[ 0, '1', '1', [ [0, FromTop('1', '1')] ] ],

				[ 0, ε, 'Z', [ [1, FromTop('Z')] ] ],	
				[ 0, ε, '0', [ [1, FromTop('0')] ] ],
				[ 0, ε, '1', [ [1, FromTop('1')] ] ],

				[ 1, '0', '0', [ [1, FromTop()] ] ],
				[ 1, '1', '1', [ [1, FromTop()] ] ],

				[ 1, ε, 'Z', [ [2, FromTop('Z')] ] ],

			],
			0, // start_state
			'Z', // start_symbol
			[2] // final_states
		);
		assert(a.accepts(""));
		assert(!a.accepts("0"));
		assert(!a.accepts("1"));
		assert(a.accepts("00"));
		assert(a.accepts("11"));
		assert(!a.accepts("01"));
		assert(!a.accepts("10"));
		assert(!a.accepts("001"));
		assert(!a.accepts("010"));
		assert(!a.accepts("101"));
		assert(!a.accepts("110"));
		assert(!a.accepts("0001"));
		assert(!a.accepts("0010"));
		assert(!a.accepts("0101"));
		assert(a.accepts("0110"));
		assert(a.accepts("1001"));
		assert(!a.accepts("1010"));
		assert(!a.accepts("1101"));
		assert(!a.accepts("1110"));
	});

	describe('PDA#alphabet', function () {
		it('alphabet', function () {
			const a = accept_a();
			assert.deepEqual([...a.alphabet()], ["a", "b"]);
		});
		it('a', function () {
			// Right now it returns an im.Set, but maybe it should return a regular Set
			// Being array-like is good enough for now
			assert.deepEqual([...accept_a().alphabet()], ['a', 'b']);
		});
		it('b', function () {
			// Right now it returns an im.Set, but maybe it should return a regular Set
			// Being array-like is good enough for now
			assert.deepEqual([...accept_b().alphabet()], ['a', 'b']);
		});
	});

	it('PDA#union', function(){

	});
});
