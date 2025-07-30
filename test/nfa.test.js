'use strict';

const assert = require('assert').strict;
const { NFA, singleton } = require('../lib/nfa.js');
const { FSM } = require('../lib/fsm.js');

function accept_a() {
	// Accepts "a", also has "b" in alphabet
	return new NFA(
		[ // map
			{ "a": [1], "b": [2] },
			{ "a": [2], "b": [2] },
			{ "a": [2], "b": [2] },
		],
		0, // initial
		[1], // finals
	);
}

function accept_b() {
	// accepts "b", also has "a" in alphabet
	return new NFA(
		[ // map
			{ "a": [2], "b": [1] },
			{ "a": [2], "b": [2] },
			{ "a": [2], "b": [2] },
		],
		0, // initial
		[1], // finals
	);
}

describe('NFA', function(){
	describe('meta', function(){
		it('accept_a', function(){
			assert(!accept_a().accepts(''));
			assert(accept_a().accepts('a'));
			assert(!accept_a().accepts('ab'));
			assert(!accept_a().accepts('b'));
		})
	});

	it('Even number of 0s and 1s', function test_happy() {
		const nfa = new NFA(
			[
				{ '0': [2], '1': [1], },
				{ '0': [3], '1': [0], },
				{ '0': [0], '1': [3], },
				{ '0': [1], '1': [2], },
			],
			0,
			[ 0 ]
		);
		assert(nfa.accepts(''));
		assert(nfa.accepts('00'));
		assert(nfa.accepts('11'));
		assert(nfa.accepts('0011'));
		assert(nfa.accepts('1100'));
		assert(nfa.accepts('0101'));
		assert(nfa.accepts('1010'));
		assert(nfa.accepts('1001'));
		assert(nfa.accepts('0110'));
		assert(!nfa.accepts('0'));
		assert(!nfa.accepts('1'));
		assert(!nfa.accepts('0111'));
		assert(!nfa.accepts('1011'));
		assert(!nfa.accepts('1101'));
		assert(!nfa.accepts('1110'));
	});

	it('Ends in 01', function test_happy() {
		const nfa = new NFA(
			[
				{ '0': [ 0, 1 ], '1': [ 0 ] },
				{ '1': [ 2 ] },
				{},
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

	it('NFA#alphabet');

	describe('NFA#nextStateArray', function () {
		it('nextStateArray(state)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateArray(0, 'a'), [1]);
			assert.deepEqual(a.nextStateArray(0, 'b'), [2]);
			assert.deepEqual(a.nextStateArray(0, 'c'), []);
		});
		it('nextStateArray(Array)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateArray([0], 'a'), [1]);
			assert.deepEqual(a.nextStateArray([0], 'b'), [2]);
			assert.deepEqual(a.nextStateArray([0], 'c'), []);
			assert.deepEqual(a.nextStateArray([0, 1], 'a'), [1, 2]);
			assert.deepEqual(a.nextStateArray([0, 1], 'b'), [2]);
			assert.deepEqual(a.nextStateArray([0, 1], 'c'), []);
		});
		it('nextStateArray(Set)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateArray(new Set([0]), 'a'), [1]);
			assert.deepEqual(a.nextStateArray(new Set([0]), 'b'), [2]);
			assert.deepEqual(a.nextStateArray(new Set([0]), 'c'), []);
			assert.deepEqual(a.nextStateArray(new Set([0, 1]), 'a'), [1, 2]);
			assert.deepEqual(a.nextStateArray(new Set([0, 1]), 'b'), [2]);
			assert.deepEqual(a.nextStateArray(new Set([0, 1]), 'c'), []);
		});
	});

	describe('NFA#nextStateSet', function () {
		it('nextStateSet(state)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateSet(0, 'a'), new Set([1]));
			assert.deepEqual(a.nextStateSet(0, 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet(0, 'c'), new Set([]));
		});
		it('nextStateSet(Array)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateSet([0], 'a'), new Set([1]));
			assert.deepEqual(a.nextStateSet([0], 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet([0], 'c'), new Set([]));
			assert.deepEqual(a.nextStateSet([0, 1], 'a'), new Set([1, 2]));
			assert.deepEqual(a.nextStateSet([0, 1], 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet([0, 1], 'c'), new Set([]));
		});
		it('nextStateSet(Set)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateSet(new Set([0]), 'a'), new Set([1]));
			assert.deepEqual(a.nextStateSet(new Set([0]), 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet(new Set([0]), 'c'), new Set([]));
			assert.deepEqual(a.nextStateSet(new Set([0, 1]), 'a'), new Set([1, 2]));
			assert.deepEqual(a.nextStateSet(new Set([0, 1]), 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet(new Set([0, 1]), 'c'), new Set([]));
		});
	});

	it('Convert NFA to FSM');

	describe('NFA#homomorphism', function () {
		// Create a new FSM that translates from one symbol (or sequence of symbols) to another.
		// This is very useful for converting e.g. UTF-16 to UTF-32.
		// Accept a mapping of symbols, or a function.


		describe('Binary ⇄ Hex', function () {
			// This is a very simple conversion that we will use to test what happens when input symbols are not within the alphabet of the homomorphism.
			// There are times where we want to skip over the symbol, or times we want to fail the conversion.
			const homomorphism = new Map;
			for (var i = 0; i < 16; i++) {
				homomorphism.set(i.toString(2).padStart(4, '0'), i.toString(16));
			}
			// console.log(homomorphism);
		});

		describe('Decimal ⇄ BCD', function () {
			// Convert between decimal and binary-coded-decimal (a format found e.g. in SMPTE timecode)
			const homomorphism = new Map;
			for (var i = 0; i < 10; i++) {
				homomorphism.set(i.toString(10).split(''), i.toString(2).padStart(4, '0').split(''));
			}

			// Take a strategy where we try to convert individual components of the regex,
			// e.g. individual characters, if context allows.
			// but if the given homomorphism doesn't convert the whole space (e.g. it's too short)
			// then move up a level, compile that group as a FSM, and try that.
			// For example the individual characters in [89] can't be converted to [10001001] that's nonsensical,
			// the whole regex [89] has to be converted to a FSM, translated, then converted to the regexp 100[01]
			it('regex conversion');

			it('single string', function () {
				const language = singleton('99');
				const translation = language.homomorphism(homomorphism);
				assert(translation.accepts('10011001'));
				assert(!translation.accepts(''));
				assert(!translation.accepts('99'));

				const dfa = FSM.fromNFA(translation);
				assert(dfa.accepts('10011001'));
				assert(!dfa.accepts(''));
				assert(!dfa.accepts('99'));

				const strings = [...dfa.strings()];
				assert.deepEqual(strings, [ ['1', '0', '0', '1', '1', '0', '0', '1'] ]);
			});
		});

		it('mapping 1', function () {
			// A language of two strings: y and z
			const language = new NFA([
				{ 'a': [1], 'b': [1] },
				{ 'c': [1] }
			], 0, [1]);
			// console.log(language.toString());
			assert.equal(language.accepts(""), false);
			assert.equal(language.accepts("a"), true);
			assert.equal(language.accepts("b"), true);
			assert.equal(language.accepts("ab"), false);

			// h(a) => xy
			// h(b) => xyz
			const homomorphism = language.homomorphism(new Map(Object.entries({
				'a': ['x'],
				'b': ['x', 'y'],
				'c': ['z'],
			})));
			// console.log(homomorphism.toString());
			assert.equal(homomorphism.accepts(""), false);
			assert.equal(homomorphism.accepts("x"), true);
			assert.equal(homomorphism.accepts("xy"), true);
			assert.equal(homomorphism.accepts("xxy"), false);

			const dfa = FSM.fromNFA(homomorphism);
			// console.log(dfa.toString());
			const strings = [];
			for(var string of dfa.strings()){
				if(string.length > 5) break;
				strings.push(string.join(''));
			}
			assert.deepEqual(strings, ['x', 'xy', 'xz', 'xyz', 'xzz', 'xyzz', 'xzzz', 'xyzzz', 'xzzzz']);
		});

		it('Mapping many to single', function () {
			const language = singleton("aa");
			// console.log(language.toString());
			assert.equal(language.accepts(""), false);
			assert.equal(language.accepts("a"), false);
			assert.equal(language.accepts("aa"), true);
			assert.equal(language.accepts("ab"), false);

			// h(a) => xy
			// h(b) => xyz
			const homomorphism = language.homomorphism(new Map([
				[ ['a', 'a'], ['a'] ],
				[ ['b', 'b'], ['b'] ],
				[ ['c', 'c'], ['c'] ],
			]));
			// console.log(homomorphism.toString());
			assert.equal(homomorphism.accepts(""), false);
			assert.equal(homomorphism.accepts("a"), true);
			assert.equal(homomorphism.accepts("aa"), false);
			assert.equal(homomorphism.accepts("ab"), false);

			const dfa = FSM.fromNFA(homomorphism);
			// console.log(dfa.toString());
			const strings = [];
			for(var string of dfa.strings()){
				if(string.length > 5) break;
				strings.push(string.join(''));
			}
			assert.deepEqual(strings, ['a']);
		});

		it('Mapping epsilon to single', function () {
			const language = singleton("aa");
			// console.log(language.toString());
			assert.equal(language.accepts(""), false);
			assert.equal(language.accepts("a"), false);
			assert.equal(language.accepts("aa"), true);
			assert.equal(language.accepts("ab"), false);

			// h(a) => xy
			// h(b) => xyz
			const homomorphism = language.homomorphism(new Map([
				[ [], ['_'] ],
				[ ['a'], ['a'] ],
			]));
			// console.log(homomorphism.toString());
			assert.equal(homomorphism.accepts(""), false);
			assert.equal(homomorphism.accepts("_"), false);
			assert.equal(homomorphism.accepts("a"), false);
			assert.equal(homomorphism.accepts("aa"), true);
			assert.equal(homomorphism.accepts("_a"), false);
			assert.equal(homomorphism.accepts("_aa"), true);
			assert.equal(homomorphism.accepts("a_a"), true);
			assert.equal(homomorphism.accepts("aa_"), true);
			assert.equal(homomorphism.accepts("_aa_"), true);
			assert.equal(homomorphism.accepts("_a_a_"), true);
		});

	});

});
