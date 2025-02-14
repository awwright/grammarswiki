'use strict';

const assert = require('assert').strict;
const { FSM, nil, epsilon, singleton, language } = require('../lib/fsm.js');

function accept_a() {
	// Accepts "a", also has "b" in alphabet
	return new FSM(
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
	return new FSM(
		[ // map
			{ "a": 2, "b": 1 },
			{ "a": 2, "b": 2 },
			{ "a": 2, "b": 2 },
		],
		0, // initial
		[1], // finals
	);
}

describe('FSM', function(){
	it('meta', function () {
		const a = accept_a();
		assert.equal(a.accepts(""), false);
		assert.equal(a.accepts("a"), true);
		assert.equal(a.accepts("b"), false);
		assert.equal(a.accepts("aa"), false);
		assert.equal(a.accepts("ab"), false);
		assert.equal(a.accepts("ba"), false);
		assert.equal(a.accepts("bb"), false);

		const b = accept_b();
		assert(!b.accepts(""));
		assert(!b.accepts("a"));
		assert(b.accepts("b"));
		assert.equal(b.accepts("aa"), false);
		assert.equal(b.accepts("ab"), false);
		assert.equal(b.accepts("ba"), false);
		assert.equal(b.accepts("bb"), false);
	});

	// The pumping lemma only describes FSMs over a certain length...
	// Which may be longer than any accepted string.
	// (I.e. it only applies to FSMs that may be indefinitely long.)
	// Write a function to compute it.
	it('Pumping lemma minimum input length');

	it('happy', function() {
		const a = new FSM(
			[ // map
				{ "a": 0, "b": 1 },
				{ "a": 1, "b": 1 },
			],
			0, // initial
			[1], // finals
		);
		assert(!a.accepts(""));
		assert(!a.accepts("a"));
		assert(a.accepts("b"));
	});

	it('nil', function() {
		assert(!nil().accepts("a"));
	});

	it('epsilon', function() {
		assert(epsilon().accepts(""));
		assert(!epsilon().accepts("a"));
	});

	it('singleton', function() {
		const word = singleton('word');
		assert.equal(word.accepts(""), false);
		assert.equal(word.accepts("word"), true);
		assert.equal(word.accepts("words"), false);
	});

	it('language', function() {
		const ac = language(['a', 'c']);
		assert.equal(ac.accepts(""), true);
		assert.equal(ac.accepts("a"), true);
		assert.equal(ac.accepts("ab"), false);
		assert.equal(ac.accepts("ac"), true);
	});

	describe('FSM#alphabet', function() {
		it('alphabet', function() {
			const a = accept_a();
			assert.deepEqual([...a.alphabet()], ["a", "b"]);
		});
		it('a', function() {
			// Right now it returns an im.Set, but maybe it should return a regular Set
			// Being array-like is good enough for now
			assert.deepEqual([...accept_a().alphabet()], ['a', 'b']);
		});
		it('b', function() {
			// Right now it returns an im.Set, but maybe it should return a regular Set
			// Being array-like is good enough for now
			assert.deepEqual([...accept_b().alphabet()], ['a', 'b']);
		});
	});

	describe('FSM#nextState', function() {
		it('nextState', function() {
			const a = accept_a();
			assert.deepEqual(a.nextState(0, 'a'), 1);
			assert.deepEqual(a.nextState(0, 'b'), 2);
			assert.deepEqual(a.nextState(0, 'c'), undefined);
		});
	});

	describe('FSM#nextStateArray', function() {
		it('get(Array)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateArray([0], 'a'), [1]);
			assert.deepEqual(a.nextStateArray([0], 'b'), [2]);
			assert.deepEqual(a.nextStateArray([0], 'c'), []);
			assert.deepEqual(a.nextStateArray([0,1], 'a'), [1,2]);
			assert.deepEqual(a.nextStateArray([0,1], 'b'), [2]);
			assert.deepEqual(a.nextStateArray([0,1], 'c'), []);
		});
		it('get(Set)', function(){
			const a = accept_a();
			assert.deepEqual(a.nextStateArray(new Set([0]), 'a'), [1]);
			assert.deepEqual(a.nextStateArray(new Set([0]), 'b'), [2]);
			assert.deepEqual(a.nextStateArray(new Set([0]), 'c'), []);
			assert.deepEqual(a.nextStateArray(new Set([0, 1]), 'a'), [1, 2]);
			assert.deepEqual(a.nextStateArray(new Set([0, 1]), 'b'), [2]);
			assert.deepEqual(a.nextStateArray(new Set([0, 1]), 'c'), []);
		});
	});

	describe('FSM#nextStateSet', function() {
		it('nextStateSet(Array)', function () {
			const a = accept_a();
			assert.deepEqual(a.nextStateSet([0], 'a'), new Set([1]));
			assert.deepEqual(a.nextStateSet([0], 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet([0], 'c'), new Set([]));
			assert.deepEqual(a.nextStateSet([0, 1], 'a'), new Set([1, 2]));
			assert.deepEqual(a.nextStateSet([0, 1], 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet([0, 1], 'c'), new Set([]));
		});
		it('nextStateSet(Set)', function(){
			const a = accept_a();
			assert.deepEqual(a.nextStateSet(new Set([0]), 'a'), new Set([1]));
			assert.deepEqual(a.nextStateSet(new Set([0]), 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet(new Set([0]), 'c'), new Set([]));
			assert.deepEqual(a.nextStateSet(new Set([0, 1]), 'a'), new Set([1, 2]));
			assert.deepEqual(a.nextStateSet(new Set([0, 1]), 'b'), new Set([2]));
			assert.deepEqual(a.nextStateSet(new Set([0, 1]), 'c'), new Set([]));
		});
	});

	it('FSM#toString');

	describe('FSM#union', function(){
		it('a|b', function() {
			const either = FSM.union([accept_a(), accept_b()]);
			assert(!either.accepts(""));
			assert(either.accepts("a"));
			assert(either.accepts("b"));
			assert(!either.accepts("aa"));
			assert(!either.accepts("ab"));
			assert(!either.accepts("bb"));
		});
	});

	describe('FSM.compare', function() {
		const compare = FSM.compare;
		it('disjoint', function() {
			const fsm_a = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([1]));
			const fsm_b = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([2]));
			assert.deepEqual(compare([fsm_a, fsm_b]), [false, false, true]);
		});
		it('superset', function() {
			const fsm_a = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([1, 2]));
			const fsm_b = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([2]));
			assert.deepEqual(compare([fsm_a, fsm_b]), [true, false, false]);
		});
		it('subset', function() {
			const fsm_a = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([1]));
			const fsm_b = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([1, 2]));
			assert.deepEqual(compare([fsm_a, fsm_b]), [false, true, false]);
		});
		it('equal', function() {
			const fsm_a = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([1]));
			const fsm_b = new FSM([
				{ 'a': 1, 'b': 2 },
				{},
				{},
			], 0, new Set([1]));
			assert.deepEqual(compare([fsm_a, fsm_b]), [true, true, false]);
		});
		it('partial overlap', function() {
			const fsm_a = new FSM([
				{ 'a': 1, 'b': 2, 'c': 3 },
				{},
				{},
				{},
			], 0, new Set([1, 3]));
			const fsm_b = new FSM([
				{ 'a': 1, 'b': 2, 'c': 3 },
				{},
				{},
				{},
			], 0, new Set([1, 2]));
			assert.deepEqual(compare([fsm_a, fsm_b]), [false, false, false]);
		});
	});

	describe('FSM#concatenate', function(){
		it('aa', function() {
			const a = accept_a();
			const concAA = a.concatenate(a);
			assert.equal(concAA.accepts(""), false);
			assert.equal(concAA.accepts("a"), false);
			assert(concAA.accepts("aa"));
			assert.equal(concAA.accepts("aaa"), false);
		});

		it('epsilon aa', function() {
			const a = accept_a();
			const concAA = epsilon().concatenate(a).concatenate(a);
			assert.equal(concAA.accepts(""), false);
			assert.equal(concAA.accepts("a"), false);
			assert.equal(concAA.accepts("aa"), true);
			assert.equal(concAA.accepts("aaa"), false);
		});

		it('ab', function() {
			const a = accept_a();
			const b = accept_b();
			const concAB = a.concatenate(b);
			assert.equal(concAB.accepts(""), false);
			assert.equal(concAB.accepts("a"), false);
			assert.equal(concAB.accepts("b"), false);
			assert.equal(concAB.accepts("aa"), false);
			assert.equal(concAB.accepts("ab"), true);
			assert.equal(concAB.accepts("ba"), false);
			assert.equal(concAB.accepts("bb"), false);
		});

		it('a epsilon a', function() {
			const a = accept_a();
			// verify epsilon transitions, e.g.
			// a()a
			const concAA = FSM.concatenate(a, epsilon(), a);
			assert(concAA.accepts("aa"));
			// a()()a
			const concAA2 = FSM.concatenate(a, epsilon(), epsilon(), a);
			assert(concAA2.accepts("aa"));
		});

		it('(a*)(b)', function() {
			const aa = new FSM([
				{ 'a': 0 },
			], 0, new Set([0]));
			const aab = aa.concatenate(accept_b());
		});
	});

	describe('FSM#star', function() {
		it('star a', function() {
			const a = accept_a();
			const astar = a.star();
			assert(astar.accepts(""));
			assert(astar.accepts("a"));
			assert(!astar.accepts("b"));
			assert(astar.accepts("aaaaaaaaa"));
		});
		it('star b*ab', function() {
			// b*ab
			const b_ab = new FSM(
				[ // map
					{ "a": 1, "b": 0 },
					{ "b": 2 },
					{},
				],
				0, // initial
				[2], // finals
			);
			// Test that this works as expected
			assert.equal(b_ab.accepts(""), false);
			assert.equal(b_ab.accepts("a"), false);
			assert.equal(b_ab.accepts("b"), false);
			assert.equal(b_ab.accepts("ab"), true);
			assert.equal(b_ab.accepts("bab"), true);
			assert.equal(b_ab.accepts("bbab"), true);
			assert.equal(b_ab.accepts("bbaba"), false);
			assert.equal(b_ab.accepts("bbabab"), false);
			assert.equal(b_ab.accepts("abab"), false);
			// (b*ab)*
			const star = b_ab.star();
			assert.equal(star.accepts(""), true);
			assert.equal(star.accepts("a"), false);
			assert.equal(star.accepts("b"), false);
			assert.equal(star.accepts("ab"), true);
			assert.equal(star.accepts("bab"), true);
			assert.equal(star.accepts("bbab"), true);
			assert.equal(star.accepts("bbbab"), true);
			// 2x
			assert.equal(star.accepts("abab"), true);
			assert.equal(star.accepts("babbab"), true);
			assert.equal(star.accepts("bbabbbab"), true);
			assert.equal(star.accepts("bbbabbbbab"), true);
			// 3x
			assert.equal(star.accepts("ababab"), true);
			assert.equal(star.accepts("babbabbab"), true);
			assert.equal(star.accepts("babbbabbbab"), true);
			assert.equal(star.accepts("bbbabbbbabbbbab"), true);
		});
		it('star (ab*)*', function() {
			// (ab*)
			const abstar = new FSM(
				[ // map
					{ 'a': 1 },
					{ 'b': 1 }
				],
				0, // initial
				[1], // finals
			);
			assert.equal(abstar.accepts(""), false);
			assert.equal(abstar.accepts("a"), true);
			assert.equal(abstar.accepts("b"), false);
			assert.equal(abstar.accepts("ab"), true);
			assert.equal(abstar.accepts("abb"), true);
			assert.equal(abstar.accepts("abba"), false);
			assert.equal(abstar.accepts("abbab"), false);
			// (ab*)*
			const abab = abstar.star();
			assert.equal(abab.accepts(""), true);
			assert.equal(abab.accepts("a"), true);
			assert.equal(abab.accepts("b"), false);
			assert.equal(abab.accepts("ab"), true);
			assert.equal(abab.accepts("abb"), true);
			assert.equal(abab.accepts("abba"), true);
			assert.equal(abab.accepts("abbab"), true);
		});
	});

	describe('FSM#optional', function () {
		it('a?', function() {
			const a = accept_a();
			const astar = a.optional();
			assert(astar.accepts(""));
			assert(astar.accepts("a"));
			assert(!astar.accepts("b"));
			assert(!astar.accepts("aaaaaaaaa"));
		});
		it('(b*ab)?', function() {
			// b*ab
			const b_ab = new FSM(
				[ // map
					{ "a": 1, "b": 0 },
					{ "b": 2 },
					{},
				],
				0, // initial
				[2], // finals
			);
			// (b*ab)*
			assert.equal(b_ab.accepts(""), false);

			const star = b_ab.optional();
			assert.equal(star.accepts(""), true);
			assert.equal(star.accepts("a"), false);
			assert.equal(star.accepts("b"), false);
			assert.equal(star.accepts("ab"), true);
			assert.equal(star.accepts("bab"), true);
			assert.equal(star.accepts("baba"), false);
			assert.equal(star.accepts("bbab"), true);
			assert.equal(star.accepts("bbaba"), false);
			// 2x
			assert.equal(star.accepts("abab"), false);
			assert.equal(star.accepts("babbab"), false);
			assert.equal(star.accepts("bbabbbab"), false);
			assert.equal(star.accepts("bbbabbbbab"), false);
		});
	});

	describe('FSM#reduce', function(){
		it('reduce identical states', function () {
			// (a*b) with many duplicate states
			const merged = new FSM(
				[ // map
					{ "a": 1, "b": 3 },
					{ "a": 2, "b": 3 },
					{ "a": 2, "b": 3 },
					{ "a": 4, "b": 4 },
					{ "a": 4, "b": 4 },
				],
				0, // initial
				[3], // finals
			).reduce();
			assert.equal(merged.states.length, 2);
		});
	});

	describe('FSM#repeat', function() {
		it('invalid count', function() {
			const a = accept_a();
			assert.throws(function() {
				const x = a.repeat(-1, 1);
			}, (err) => true);
			assert.throws(function() {
				const x = a.repeat(1, -1);
			}, (err) => true);
		});
		it('a {0,1}', function() {
			const a = accept_a().repeat(0, 1);
			assert.equal(a.accepts(""), true);
			assert.equal(a.accepts("a"), true);
			assert.equal(a.accepts("aa"), false);
			assert.equal(a.accepts("aaa"), false);
			// assert.equal(zeroA.equivalent(a.optional()), true);
		});
		it('a {1,1}', function() {
			const a = accept_a().repeat(1, 1);
			assert.equal(a.accepts(""), false);
			assert.equal(a.accepts("a"), true);
			assert.equal(a.accepts("aa"), false);
			assert.equal(a.accepts("aaa"), false);
			// assert.equal(zeroA.equivalent(a.optional()), true);
		});
		it('a {1,}', function() {
			const a = accept_a().repeat(1, 1 / 0);
			assert.equal(a.accepts(""), false);
			assert.equal(a.accepts("a"), true);
			assert.equal(a.accepts("aa"), true);
			assert.equal(a.accepts("aaa"), true);
			// assert.equal(zeroA.equivalent(a.optional()), true);
		});
		it('a {1,2}', function() {
			const aa = accept_a().repeat(1, 2);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("a"), true);
			assert.equal(aa.accepts("aa"), true);
			assert.equal(aa.accepts("aaa"), false);
		});
		it('a {2,}', function() {
			const aa = accept_a().repeat(2, 1/0);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("a"), false);
			assert.equal(aa.accepts("aa"), true);
			assert.equal(aa.accepts("aaa"), true);
			// assert.equal(zeroA.equivalent(a.optional()), true);
		});
		it('a {2,4}', function() {
			const aa = accept_a().repeat(2, 4);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("a"), false);
			assert.equal(aa.accepts("aa"), true);
			assert.equal(aa.accepts("aaa"), true);
			assert.equal(aa.accepts("aaaa"), true);
			assert.equal(aa.accepts("aaaaa"), false);
		});
		it('a {4,}', function() {
			const aa = accept_a().repeat(4, 1 / 0);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("a"), false);
			assert.equal(aa.accepts("aa"), false);
			assert.equal(aa.accepts("aaa"), false);
			assert.equal(aa.accepts("aaaa"), true);
			assert.equal(aa.accepts("aaaaa"), true);
			assert.equal(aa.accepts("aaaaaa"), true);
		});
		it('(ab){0,1}', function() {
			const a = accept_a().concatenate(accept_b()).repeat(0, 1);
			assert.equal(a.accepts(""), true);
			assert.equal(a.accepts("ab"), true);
			assert.equal(a.accepts("abab"), false);
			assert.equal(a.accepts("ababab"), false);
			// assert.equal(zeroA.equivalent(a.optional()), true);
		});
		it('(ab){2,4}', function() {
			const aa = accept_a().concatenate(accept_b()).repeat(2, 4);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("ab"), false);
			assert.equal(aa.accepts("abab"), true);
			assert.equal(aa.accepts("ababab"), true);
			assert.equal(aa.accepts("abababab"), true);
			assert.equal(aa.accepts("ababababab"), false);
		});
		it('(ab){3, 3}', function() {
			const aa = accept_a().concatenate(accept_b()).repeat(3, 3);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("ab"), false);
			assert.equal(aa.accepts("abab"), false);
			assert.equal(aa.accepts("ababab"), true);
			assert.equal(aa.accepts("abababab"), false);
			assert.equal(aa.accepts("ababababab"), false);
		});
		it('(ab){4,}', function() {
			const aa = accept_a().concatenate(accept_b()).repeat(4, 1 / 0);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("ab"), false);
			assert.equal(aa.accepts("abab"), false);
			assert.equal(aa.accepts("ababab"), false);
			assert.equal(aa.accepts("abababab"), true);
			assert.equal(aa.accepts("ababababab"), true);
			assert.equal(aa.accepts("abababababab"), true);
		});
		it('(a*b){2,4}', function() {
			const aa = accept_a().star().concatenate(accept_b()).repeat(2, 4);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("ab"), false);
			assert.equal(aa.accepts("abab"), true);
			assert.equal(aa.accepts("ababab"), true);
			assert.equal(aa.accepts("abababab"), true);
			assert.equal(aa.accepts("ababababab"), false);
		});
		it('(a*b){4,}', function() {
			const aa = accept_a().star().concatenate(accept_b()).repeat(4, 1/0);
			assert.equal(aa.accepts(""), false);
			assert.equal(aa.accepts("ab"), false);
			assert.equal(aa.accepts("abab"), false);
			assert.equal(aa.accepts("ababab"), false);
			assert.equal(aa.accepts("abababab"), true);
			assert.equal(aa.accepts("ababababab"), true);
			assert.equal(aa.accepts("abababababab"), true);
		});
	});

	describe('FSM#union', function(){
		it('alternation_a', function() {
			const a = accept_a();
			const altA = a.union(nil());
			assert(!altA.accepts(""));
			assert(altA.accepts("a"));
		});
		it('alternation_ab', function() {
			const a = accept_a();
			const b = accept_b();
			const altAB = a.union(b);
			assert(!altAB.accepts(""));
			assert(altAB.accepts("a"));
			assert(altAB.accepts("b"));
			assert(!altAB.accepts("aa"));
			assert(!altAB.accepts("ab"));
			assert(!altAB.accepts("ba"));
			assert(!altAB.accepts("bb"));
		});
	});

	describe('FSM#intersection', function(){
		it('intersection_ab', function() {
			const a = accept_a();
			const b = accept_b();
			const intAB = a.intersection(b);
			assert(!intAB.accepts(""));
			assert(!intAB.accepts("a"));
			assert(!intAB.accepts("b"));
		});
	});

	describe('FSM#symmetric_difference', function() {
		it('([ab]*) %2 [bc]', function() {
			const aorbstar = accept_a().union(accept_b()).star();
			assert.equal(aorbstar.accepts(""), true);
			assert.equal(aorbstar.accepts("a"), true);
			assert.equal(aorbstar.accepts("b"), true);
			assert.equal(aorbstar.accepts("aa"), true);
			assert.equal(aorbstar.accepts("bb"), true);
			assert.equal(aorbstar.accepts("ab"), true);

			const borc = accept_b().union(singleton('c'));
			assert.equal(borc.accepts(""), false);
			assert.equal(borc.accepts("a"), false);
			assert.equal(borc.accepts("b"), true);
			assert.equal(borc.accepts("c"), true);
			assert.equal(borc.accepts("aa"), false);
			assert.equal(borc.accepts("bb"), false);
			assert.equal(borc.accepts("cc"), false);

			const diff = aorbstar.symmetric_difference(borc);
			assert.equal(diff.accepts(""), true);
			assert.equal(diff.accepts("a"), true);
			assert.equal(diff.accepts("b"), false);
			assert.equal(diff.accepts("c"), true);
			assert.equal(diff.accepts("aa"), true);
			assert.equal(diff.accepts("bb"), true);
			assert.equal(diff.accepts("cc"), false);
		});
	});
	describe('FSM#relative_compliment', function() {
		it('([ab]*) \\ [bc]', function() {
			const aorbstar = accept_a().union(accept_b()).star();
			assert.equal(aorbstar.accepts(""), true);
			assert.equal(aorbstar.accepts("a"), true);
			assert.equal(aorbstar.accepts("b"), true);
			assert.equal(aorbstar.accepts("aa"), true);
			assert.equal(aorbstar.accepts("bb"), true);
			assert.equal(aorbstar.accepts("ab"), true);

			const borc = accept_b().union(singleton('c'));
			assert.equal(borc.accepts(""), false);
			assert.equal(borc.accepts("a"), false);
			assert.equal(borc.accepts("b"), true);
			assert.equal(borc.accepts("c"), true);
			assert.equal(borc.accepts("aa"), false);
			assert.equal(borc.accepts("bb"), false);
			assert.equal(borc.accepts("cc"), false);

			const diff = aorbstar.relative_compliment(borc);
			assert.equal(diff.accepts(""), true);
			assert.equal(diff.accepts("a"), true);
			assert.equal(diff.accepts("b"), false);
			assert.equal(diff.accepts("c"), false);
			assert.equal(diff.accepts("aa"), true);
			assert.equal(diff.accepts("bb"), true);
			assert.equal(diff.accepts("cc"), false);
		});
	});

	describe('FSM#inverse', function(){
		it('inverse a', function() {
			const a = accept_a().inverse(new Set(['a', 'b']));
			assert.equal(a.accepts(""), true);
			assert.equal(a.accepts("a"), false);
			assert.equal(a.accepts("b"), true);
		});

		it('inverse b', function() {
			const b = accept_b().inverse(new Set(['a', 'b']));
			assert.equal(b.accepts(""), true);
			assert.equal(b.accepts("a"), true);
			assert.equal(b.accepts("b"), false);
		});

		it('negation', function() {
			const ainv = accept_a().inverse(['a', 'b', 'c']);
			assert.equal(ainv.accepts(""), true);
			assert.equal(ainv.accepts("a"), false);
			assert.equal(ainv.accepts("b"), true);
			assert.equal(ainv.accepts("aa"), true);
			assert.equal(ainv.accepts("ab"), true);
			assert.equal(ainv.accepts("abc"), true);

			const inverseB = accept_a().inverse(['a', 'b', 'c']);
			assert.equal(inverseB.accepts(""), true);
			assert.equal(inverseB.accepts("a"), false);
			assert.equal(inverseB.accepts("b"), true);
			assert.equal(inverseB.accepts("aa"), true);
			assert.equal(inverseB.accepts("ab"), true);
			assert.equal(inverseB.accepts("abc"), true); // now c is in the alphabet and this would have been rejected by `a`
			assert.equal(inverseB.accepts("abcd"), false); // should reject because d is not in the alphabet
		});
	});

	describe('FSM#reverse', function(){
		it('reverse abc', function() {
			const abc = new FSM(
				[ // map
					{ "a": 1 },
					{ "b": 2 },
					{ "c": 3 },
					{},
				],
				0, // initial
				[3], // finals
			);
			assert.equal(abc.accepts("abc"), true);
			assert.equal(abc.accepts("cba"), false);

			const cba = abc.reverse();
			assert.equal(cba.accepts("abc"), false);
			assert.equal(cba.accepts("cba"), true);
		});

		it('reverse epsilon', function() {
			// epsilon reversed is epsilon
			assert(epsilon().reverse().accepts(""));
		});

		it('reverse star', function() {
			// (a|b)*a(a|b)
			const star = new FSM(
				[ // map
					{ "a": 1, "b": 3 },
					{ "a": 2, "b": 4 },
					{ "a": 2, "b": 4 },
					{ "a": 1, "b": 3 },
					{ "a": 1, "b": 3 },
				],
				0, // initial
				[2, 4], // finals
			);
			assert.equal(star.accepts(""), false);
			assert.equal(star.accepts("a"), false);
			assert.equal(star.accepts("b"), false);
			assert.equal(star.accepts("aa"), true);
			assert.equal(star.accepts("ab"), true);
			assert.equal(star.accepts("ba"), false);
			assert.equal(star.accepts("aab"), true);
			assert.equal(star.accepts("bab"), true);
			assert.equal(star.accepts("abbbbbbbab"), true);
			assert.equal(star.accepts("ba"), false);
			assert.equal(star.accepts("bb"), false);
			assert.equal(star.accepts("bbbbbbbbbbbb"), false);

			// (a|b)a(a|b)*
			const b2 = star.reverse();
			assert.equal(b2.accepts(""), false);
			assert.equal(b2.accepts("a"), false);
			assert.equal(b2.accepts("b"), false);
			assert.equal(b2.accepts("aa"), true);
			assert.equal(b2.accepts("ab"), false);
			assert.equal(b2.accepts("ba"), true);
			assert.equal(b2.accepts("baa"), true);
			assert.equal(b2.accepts("bab"), true);
			assert.equal(b2.accepts("babbbbbbba"), true);
			assert.equal(b2.accepts("ab"), false);
			assert.equal(b2.accepts("bb"), false);
			assert.equal(b2.accepts("bbbbbbbbbbbb"), false);
		});
	});

	it('FSM#islive');

	it('FSM#empty', function(){
		it('empty', function() {
			const a = accept_a();
			const b = accept_b();
			assert(!a.empty());
			assert(!b.empty());

			assert(new FSM(
				[{}, {}], // map
				0, // initial
				[1], // finals
				[], // alphabet
			).empty());

			assert(!new FSM(
				[{}], // map
				0, // initial
				[0], // finals
				[], // alphabet
			).empty());

			assert(new FSM(
				[
					{ "a": 1, "b": 1 },
					{ "a": 3, "b": 3 },
					{ "a": 3, "b": 3 },
					{ "a": 3, "b": 3 },
				], // map
				0, // initial
				[2], // finals
				["a", "b"], // alphabet
			).empty());
		});
	});

	describe('FSM#strings', function(){
		it('strings [ab]c?', function() {
			// [ab]c?
			const abc = accept_a().union(accept_b()).concatenate(singleton('c').optional());
			assert(abc.accepts('a'));
			assert(abc.accepts('b'));
			assert(abc.accepts('ac'));
			assert(abc.accepts('bc'));

			// Test string generator functionality.
			const gen = abc.strings();
			assert.deepEqual(gen.next().value, ["a"]);
			assert.deepEqual(gen.next().value, ["b"]);
			assert.deepEqual(gen.next().value, ["a", "c"]);
			assert.deepEqual(gen.next().value, ["b", "c"]);
			assert.deepEqual(gen.next().value, undefined);
		});

		it('strings [ab]{2,4}', function() {
			// [ab]{2,4}
			const aaaa = accept_a().union(accept_b()).repeat(2,4);
			assert(aaaa.accepts('aa'));
			assert(aaaa.accepts('abab'));

			// Test string generator functionality.
			const gen = aaaa.strings();
			assert.deepEqual(gen.next().value, ["a", "a"]);
			assert.deepEqual(gen.next().value, ["a", "b"]);
			assert.deepEqual(gen.next().value, ["b", "a"]);
			assert.deepEqual(gen.next().value, ["b", "b"]);
			assert.deepEqual(gen.next().value, ["a", "a", "a"]);
			assert.deepEqual(gen.next().value, ["a", "a", "b"]);
		});
	});

	describe('FSM#equivalent', function(){
		it('equivalent', function() {
			const a = accept_a();
			const b = accept_b();
			const ab = a.union(b);
			const ba = b.union(a);
			assert(ab.equivalent(ba));
		});
	});

	it('FSM#cardinality');

	describe('FSM#derive', function(){
		it('derive', function() {
			const a = accept_a();
			assert(a.derive("a").equivalent(epsilon()));
			assert(a.derive("b").equivalent(nil()));
			assert(a.repeat(3,3).derive("a").equivalent(a.repeat(2,2)));
			assert(a.star().relative_compliment(epsilon()).derive("a").equivalent(a.star()));
		});
	});

	it('divisible by 3', function(){
		// Binary numbers divisible by 3.
		// Disallows the empty string
		// Allows "0" on its own, but not leading zeroes.
		const div3 = new FSM(
			[ // map
				{"0": 4, "1": 2},
				{"0": 1, "1": 2},
				{"0": 3, "1": 1},
				{"0": 2, "1": 3},
				{},
			],
			0, // initial
			[1, 4], // finals
		);
		assert.equal(div3.accepts(""), false);
		assert(div3.accepts("0"));
		assert.equal(div3.accepts("1"), false);
		assert.equal(div3.accepts("00"), false);
		assert.equal(div3.accepts("01"), false);
		assert.equal(div3.accepts("10"), false);
		assert(div3.accepts("11"));
		assert.equal(div3.accepts("000"), false);
		assert.equal(div3.accepts("001"), false);
		assert.equal(div3.accepts("010"), false);
		assert.equal(div3.accepts("011"), false);
		assert.equal(div3.accepts("100"), false);
		assert.equal(div3.accepts("101"), false);
		assert(div3.accepts("110"));
		assert.equal(div3.accepts("111"), false);
		assert.equal(div3.accepts("0000"), false);
		assert.equal(div3.accepts("0001"), false);
		assert.equal(div3.accepts("0010"), false);
		assert.equal(div3.accepts("0011"), false);
		assert.equal(div3.accepts("0100"), false);
		assert.equal(div3.accepts("0101"), false);
		assert.equal(div3.accepts("0110"), false);
		assert.equal(div3.accepts("0111"), false);
		assert.equal(div3.accepts("1000"), false);
		assert(div3.accepts("1001"));
	});

	it('invalid initial', function(){
		// initial state 1 is not a state
		assert.throws(function(){
			new FSM(
				[], // map
				1, // initial
				[], // finals
			);
		}, (err) => true );
	});

	it('invalid transition', function() {
		// invalid transition for state 1, symbol "a"
		assert.throws(function(){
			new FSM(
				[ // map
					{"a" : 2}
				],
				1, // initial
				[], // finals
			);
		}, (err) => true );
	});
});
