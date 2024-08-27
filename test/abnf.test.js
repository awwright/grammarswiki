'use strict';

const { rulelist, rule, rulename, alternation, concatenation, repetition, element, group, option, char_val, bin_val, dec_val, hex_val, num_val, prose_val } = require('../lib/abnf.js');
const assert = require('assert').strict;

describe('ABNF', function(){
	describe('rulelist', function(){
		it('rulelist.match', function(){
			const actual = rulelist.match('a = b\r\nb = "c"\r\n');
			const expected = new rulelist([
				rule.parse('a = b\r\n'),
				rule.parse('b = "c"\r\n'),
			]);
			assert.deepEqual(actual, [expected, 16]);
		});
		it('rulelist.match', function(){
			const actual = rulelist.match('rule =\r\n\ta\r\nrulename =  b\r\n');
			const expected = new rulelist([
				rule.parse('rule = a\r\n'),
				rule.parse('rulename = b\r\n'),
			]);
			assert.deepEqual(actual, [expected, 27]);
		});
		it('rulelist.match', function(){
			const actual = rulelist.match('\r\nrule           =  rulename defined-as elements c-nl\r\n\t\t; continues if next line starts\r\n\t\t;  with white space\r\n\r\nrulename       =  ALPHA *(ALPHA / DIGIT / "-")\r\n');
			const expected = new rulelist([
				rule.parse('rule = rulename defined-as elements c-nl\r\n'),
				rule.parse('rulename = ALPHA *(ALPHA / DIGIT / "-")\r\n'),
			]);
			assert.deepEqual(actual, [expected, 163]);
		});
		it('rulelist#toString', function(){
			const actual = rulelist.parse('\r\nrule           =  rulename defined-as elements c-nl\r\n\t\t; continues if next line starts\r\n\t\t;  with white space\r\n\r\nrulename       =  ALPHA *(ALPHA / DIGIT / "-")\r\n');
			const expected = 'rule = rulename defined-as elements c-nl\r\nrulename = ALPHA *(ALPHA / DIGIT / "-")\r\n';
			assert.equal(actual.toString(), expected);
		});
	});

	describe('rule', function(){
		it('rule.match', function(){
			assert.deepEqual(rule.match('a = "a"\r\n'), [new rule('a', '=', alternation.parse('"a"')), 9]);
		});
		it('rule.match 2', function(){
			const actual = rule.match('name       =\r\n\t1*( rule / (*c-wsp c-nl) )\r\n');
			const expected = new rule('name', '=', alternation.parse('1*( rule / (*c-wsp c-nl) )'));
			assert.deepEqual(actual, [expected, 43]);
		});
		it('rule.match with repetition', function(){
			const actual = rule.match('name       =\r\n\t1*rule\r\n');
			const expected = new rule('name', '=', alternation.parse('1*rule'));
			assert.deepEqual(actual, [expected, 23]);
		});
		it('rule.match with group', function(){
			const actual = rule.match('name =\r\n\t1*( rule )\r\n');
			const expected = new rule('name', '=', alternation.parse('1*( rule )'));
			assert.deepEqual(actual, [expected, 21]);
		});
		it('rule#toString', function(){
			const actual = rule.parse('rule           =  rulename defined-as elements c-nl\r\n');
			const expected = 'rule = rulename defined-as elements c-nl\r\n';
			assert.equal(actual.toString(), expected);
		});
	});

	describe('rulename', function(){
		it('rulename.match', function(){
			assert.deepEqual(rulename.match('foo'), [new rulename('foo'), 3]);
		});
		it('rulename#toString', function(){
			assert.equal(new rulename('therulename').toString(), 'therulename');
			assert.equal(rulename.parse('therulename').toString(), 'therulename');
		});
	});

	describe('alternation', function(){
		it('alternation.match simple', function(){
			assert.deepEqual(alternation.match('"a"'), [new alternation([
				concatenation.parse('"a"'),
			]), 3]);
		});
		it('alternation.match between two', function(){
			assert.deepEqual(alternation.match('a / b'), [new alternation([
				concatenation.parse('a'),
				concatenation.parse('b'),
			]), 5]);
		});
		it('alternation.match 3', function(){
			assert.deepEqual(alternation.match('"a" / "b" / "c"'), [new alternation([
				concatenation.parse('"a"'),
				concatenation.parse('"b"'),
				concatenation.parse('"c"'),
			]), 15]);
		});
		it('alternation.match 4', function(){
			assert.deepEqual(alternation.match('1*("." 1*BIT) / ("-" 1*BIT)'), [new alternation([
				concatenation.parse('1*("." 1*BIT)'),
				concatenation.parse('("-" 1*BIT)'),
			]), 27]);
		});
		it('alternation.match with repetition', function(){
			assert.deepEqual(alternation.match('1*( rule / (c-nl) )'), [new alternation([
				concatenation.parse('1*( rule / (c-nl) )'),
			]), 19]);
		});
		it('alternation.match with group', function(){
			assert.deepEqual(alternation.match('rule / (*c-wsp c-nl)'), [new alternation([
				concatenation.parse('rule'),
				concatenation.parse('(*c-wsp c-nl)'),
			]), 20]);
		});
		it('alternation#toFSM', function () {
			const fsm = alternation.parse('"a" / "0" / "-"').toFSM();
			assert.equal(fsm.accepts('A'), true);
			assert.equal(fsm.accepts('0'), true);
			assert.equal(fsm.accepts('-'), true);
			assert.equal(fsm.accepts('/'), false);
		});
		it.skip('alternation#toFSM (rulename)', function(){
			// This won't pass for the time being because there's no way to dereference rule names
			const fsm = alternation.parse('ALPHA / DIGIT / "-"').toFSM();
			assert.equal(fsm.accepts('A'), true);
			assert.equal(fsm.accepts('0'), true);
			assert.equal(fsm.accepts('-'), true);
			assert.equal(fsm.accepts('/'), false);
		});
	});

	describe('concatenation', function(){
		it('concatenation.match 1', function(){
			assert.deepEqual(concatenation.match('a b c'), [new concatenation([
				repetition.parse('a'),
				repetition.parse('b'),
				repetition.parse('c'),
			]), 5]);
		});
		it('concatenation.match 2', function(){
			assert.deepEqual(concatenation.match('"a" %x20 <prose>'), [new concatenation([
				repetition.parse('"a"'),
				repetition.parse('%x20'),
				repetition.parse('<prose>'),
			]), 16]);
		});
		it('concatenation.match 3', function(){
			assert.deepEqual(concatenation.match('"b" 1*BIT [ 1*("." 1*BIT) / ("-" 1*BIT) ]'), [new concatenation([
				repetition.parse('"b"'),
				repetition.parse('1*BIT'),
				repetition.parse('[ 1*("." 1*BIT) / ("-" 1*BIT) ]'),
			]), 41]);
		});
		it('concatenation.match with alternates', function(){
			// Concatenation does not include alternates, unless in a group
			assert.deepEqual(concatenation.match('a b / c d'), [new concatenation([
				repetition.parse('a'),
				repetition.parse('b'),
			]), 3]);
			assert.deepEqual(concatenation.match('a ( b / c ) d'), [new concatenation([
				repetition.parse('a'),
				repetition.parse('( b / c )'),
				repetition.parse('d'),
			]), 13]);
		});
		it('toRegExpStr');
	});

	describe('repetition', function(){
		it('repetition.match', function(){
			assert.deepEqual(repetition.match('*rulename'), [new repetition(new rulename('rulename'), 0, 1/0), 9]);
			assert.deepEqual(repetition.match('1*rulename'), [new repetition(new rulename('rulename'), 1, 1/0), 10]);
			assert.deepEqual(repetition.match('1*2rulename'), [new repetition(new rulename('rulename'), 1, 2), 11]);
			assert.deepEqual(repetition.match('*2rulename'), [new repetition(new rulename('rulename'), 0, 2), 10]);
		});
		it('repetition.match 2', function(){
			assert.deepEqual(
				repetition.match('[ 1*("." 1*BIT) / ("-" 1*BIT) ]'), [new repetition(option.parse('[ 1*("." 1*BIT) / ("-" 1*BIT) ]'), 1, 1), 31]);
		});
	});

	describe('element', function(){
		it('element.match rulename', function(){
			assert.deepEqual(element.match('rulename'), [new rulename('rulename'), 8]);
		});
		it('element.match group', function(){
			assert.deepEqual(element.match('(rulename)'), [new group(alternation.parse('rulename')), 10]);
		});
		it('element.match option', function(){
			assert.deepEqual(element.match('[rulename]'), [new option(alternation.parse('rulename')), 10]);
		});
		it('element.match char-val', function(){
			assert.deepEqual(element.match('"chars"'), [new char_val('chars'), 7]);
		});
		it('element.match num-val', function(){
			assert.deepEqual(element.match('%x20'), [num_val.parse('%x20'), 4]);
		});
		it('element.match prose-val', function(){
			assert.deepEqual(prose_val.match('<some text>'), [new prose_val('some text'), 11]);
		});
	});

	describe('prose_val', function(){
		it('prose_val.match', function(){
			assert.deepEqual(prose_val.match('<remark>'), [new prose_val("remark"), 8]);
		});
		it('prose_val.toString', function(){
			assert.deepEqual(new prose_val("remark").toString(), '<remark>');
		});
		it('prose_val.toRegExpStr', function(){
			assert.equal(new prose_val("remark").toRegExpStr(), '');
		});
	});

	describe('char_val', function(){
		it('char_val.match', function(){
			assert.deepEqual(char_val.match('" "'), [new char_val(" "), 3]);
		});
		it('char_val.toString', function(){
			assert.deepEqual(new char_val(" ").toString(), '" "');
		});
		it('char_val.toRegExpStr', function(){
			assert.equal(new char_val(" ").toRegExpStr(), '');
		});
	});

	describe('group', function(){
		it('group.match', function(){
			assert.deepEqual(group.match('(rulename)'), [new group(alternation.parse('rulename')), 10]);
			assert.deepEqual(group.match('(*c-wsp c-nl)'), [new group(alternation.parse('*c-wsp c-nl')), 13]);
		});
		it('group.match with group', function(){
			assert.deepEqual(group.match('((rulename))'), [new group(alternation.parse('(rulename)')), 12]);
		});
		it('group.toString', function(){
			assert.deepEqual(new group(alternation.parse('rulename')).toString(), '(rulename)');
		});
	});

	describe('option', function(){
		it('option.match', function(){
			assert.deepEqual(option.match('[rulename]'), [new option(alternation.parse('rulename')), 10]);
		});
		it('option.match 2', function(){
			assert.deepEqual(option.match('[ 1*("." 1*BIT) / ("-" 1*BIT) ]'), [new option(alternation.parse('1*("." 1*BIT) / ("-" 1*BIT)')), 31]);
		});
		it('option.toString', function(){
			assert.deepEqual(new option(alternation.parse('rulename')).toString(), '[rulename]');
		});
	});

	describe('num_val', function(){
		it('num_val.match', function(){
			// assert.deepEqual(num_val.match('x0'), [new num_val(''), 1]);
			assert.deepEqual(num_val.match('%x20'), [new num_val('x', [new hex_val(0x20)]), 4]);
			assert.deepEqual(num_val.match('%x20.21.22'), [new num_val('x', [new hex_val(0x20), new hex_val(0x21), new hex_val(0x22)]), 10]);
			assert.deepEqual(num_val.match('%x20-21'), [new num_val('x', [new hex_val(0x20, 0x21)]), 7]);
		});
		it('num_val#toString', function(){
			// assert.deepEqual(num_val.match('x0'), [new num_val(''), 1]);
			assert.deepEqual(new num_val('x', [new hex_val(0x20)]).toString(), '%x20');
			assert.deepEqual(new num_val('x', [new hex_val(0x20), new hex_val(0x21), new hex_val(0x22)]).toString(), '%x20.21.22');
			assert.deepEqual(new num_val('x', [new hex_val(0x20, 0x21)]).toString(), '%x20-21');
		});
	});

	describe('bin_val', function(){
		it('bin_val.match', function(){
			// assert.deepEqual(bin_val.match('x0'), [new bin_val(''), 1]);
			assert.deepEqual(bin_val.match('100000'), [new bin_val(0x20), 6]);
			assert.deepEqual(bin_val.match('100001-1000000'), [new bin_val(0x21, 0x40), 14]);
		});
	});

	describe('dec_val', function(){
		it('dec_val.match', function(){
			assert.deepEqual(dec_val.match('32'), [new dec_val(0x20), 2]);
			assert.deepEqual(dec_val.match('33-64'), [new dec_val(0x21, 0x40), 5]);
		});
	});

	describe('hex_val', function(){
		it('hex_val.match', function(){
			assert.deepEqual(hex_val.match('20'), [new hex_val(0x20), 2]);
			assert.deepEqual(hex_val.match('21-40'), [new hex_val(0x21, 0x40), 5]);
		});
		it('hex_val#toString', function () {
			assert.deepEqual(new hex_val(0x21).toString(), '21');
			assert.deepEqual(new hex_val(0x21, 0x30).toString(), '21-30');
		});
		it('hex_val#toFSM', function () {
			const fsm = hex_val.parse('21-40').toFSM();
			assert.equal(fsm.accepts(' '), false);
			assert.equal(fsm.accepts('!'), true);
			assert.equal(fsm.accepts('"'), true);
			assert.equal(fsm.accepts('9'), true);
			assert.equal(fsm.accepts('?'), true);
			assert.equal(fsm.accepts('@'), true);
			assert.equal(fsm.accepts('A'), false);
		});
	});

	it('tests', function(){
		// Alright this is a complicated one... For each type of production, write example grammars that use it.
		// Then create positive and negative tests for that grammar, and export them to a file somewhere.
		// Then test every translator against these positive and negative tests.
	});
});
