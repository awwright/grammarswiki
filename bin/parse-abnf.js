"use strict";

// This is the most basic possible ABNF reader.
// It parses only what's strictly necessary to read the described grammar.
// Really, it's mostly only here to bootstrap a more sophisticated ABNF parser out of a parser generator.
// It is really picky and will bail on trivial problems like
// not using CRLF, misused leading whitespace, or not ending the file with a CRLF.

const abnf = require('../lib/abnf.js');
const args = process.argv.slice(2);

const { readFileSync } = require('fs');
const contents = readFileSync(args[0], 'utf-8');
// console.log(contents);
const tree = abnf.rulelist.parse(contents);
console.dir(tree, {depth:1/0});
