'use strict';

const assert = require('assert').strict;
const { Grammar } = require('../lib/grammar.js');

describe('Grammar', function(){
	it('G_pal', function test_happy() {
		// Test a sample grammar
		const g = new Grammar(
			['P'],
			['0', '1'],
			[
				['P', ''],
				['P', '0'],
				['P', '1'],
				['P', '0P0'],
				['P', '0P1'],
			],
			'E'
		);
		assert.equal(g.toAlternatesString(), 'P →  | 0 | 1 | 0P0 | 0P1')
	});

	it('expressions', function test_happy() {
		// Test a sample grammar
		const g = new Grammar(
			['E', 'I'],
			['+', '*', '(', ')', 'a', 'b', '0', '1'],
			[
				['E', 'I'],
				['E', 'E+E'],
				['E', 'E*E'],
				['E', '(E)'],
				['I', 'a'],
				['I', 'b'],
				['I', 'Ia'],
				['I', 'Ib'],
				['I', 'I0'],
				['I', 'I1'],
			],
			'E'
		);
		assert.equal(g.toAlternatesString(), 'E → I | E+E | E*E | (E)\nI → a | b | Ia | Ib | I0 | I1')
	});

});
