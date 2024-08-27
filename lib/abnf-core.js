"use strict";

const { rule, rulename, alternation, concatenation, repetition, group, num_val, hex_val, char_val } = require('./abnf.js');

const ALPHA = new rule("ALPHA", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(65, 90)]), 1, 1)]), new concatenation([new repetition(new num_val("x", [new hex_val(97, 122)]), 1, 1)])]))
const BIT = new rule("BIT", "=", new alternation([new concatenation([new repetition(new char_val("0"), 1, 1)]), new concatenation([new repetition(new char_val("1"), 1, 1)])]))
const CHAR = new rule("CHAR", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(1, 127)]), 1, 1)])]))
const CR = new rule("CR", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(13, undefined)]), 1, 1)])]))
const CRLF = new rule("CRLF", "=", new alternation([new concatenation([new repetition(new rulename("CR"), 1, 1), new repetition(new rulename("LF"), 1, 1)])]))
const CTL = new rule("CTL", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(0, 31)]), 1, 1)]), new concatenation([new repetition(new num_val("x", [new hex_val(127, undefined)]), 1, 1)])]))
const DIGIT = new rule("DIGIT", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(48, 57)]), 1, 1)])]))
const DQUOTE = new rule("DQUOTE", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(34, undefined)]), 1, 1)])]))
const HEXDIG = new rule("HEXDIG", "=", new alternation([new concatenation([new repetition(new rulename("DIGIT"), 1, 1)]), new concatenation([new repetition(new char_val("A"), 1, 1)]), new concatenation([new repetition(new char_val("B"), 1, 1)]), new concatenation([new repetition(new char_val("C"), 1, 1)]), new concatenation([new repetition(new char_val("D"), 1, 1)]), new concatenation([new repetition(new char_val("E"), 1, 1)]), new concatenation([new repetition(new char_val("F"), 1, 1)])]))
const HTAB = new rule("HTAB", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(9, undefined)]), 1, 1)])]))
const LF = new rule("LF", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(10, undefined)]), 1, 1)])]))
const LWSP = new rule("LWSP", "=", new alternation([new concatenation([new repetition(new group(new alternation([new concatenation([new repetition(new rulename("WSP"), 1, 1)]), new concatenation([new repetition(new rulename("CRLF"), 1, 1), new repetition(new rulename("WSP"), 1, 1)])])), 0, null)])]))
const OCTET = new rule("OCTET", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(0, 255)]), 1, 1)])]))
const SP = new rule("SP", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(32, undefined)]), 1, 1)])]))
const VCHAR = new rule("VCHAR", "=", new alternation([new concatenation([new repetition(new num_val("x", [new hex_val(33, 126)]), 1, 1)])]))
const WSP = new rule("WSP", "=", new alternation([new concatenation([new repetition(new rulename("SP"), 1, 1)]), new concatenation([new repetition(new rulename("HTAB"), 1, 1)])]))

ALPHA.source = '<core>';
BIT.source = '<core>';
CHAR.source = '<core>';
CR.source = '<core>';
CRLF.source = '<core>';
CTL.source = '<core>';
DIGIT.source = '<core>';
DQUOTE.source = '<core>';
HEXDIG.source = '<core>';
HTAB.source = '<core>';
LF.source = '<core>';
LWSP.source = '<core>';
OCTET.source = '<core>';
SP.source = '<core>';
VCHAR.source = '<core>';
WSP.source = '<core>';

module.exports = { ALPHA, BIT, CHAR, CR, CRLF, CTL, DIGIT, DQUOTE, HEXDIG, HTAB, LF, LWSP, OCTET, SP, VCHAR, WSP };
