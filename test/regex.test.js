'use strict';

const { rulelist, rule, rulename, alternation, concatenation, repetition, element, group, option, char_val, bin_val, dec_val, hex_val, num_val, prose_val } = require('../lib/abnf.js');
const assert = require('assert').strict;

describe('Regex', function () {
	describe('pattern', function () {
		it('pattern.fromFSM');
		it('pattern.match');
	});
});

