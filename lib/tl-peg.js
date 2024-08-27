"use strict";

const { tl } = require('./tl.js');
const abnflib = require('./abnf.js');
const abnfcore = require('./abnf-core.js');

const peggy = require('peggy');

/* A standard interface to hook into the features of many other kinds of parser generators */
class tl_peg extends tl {
	constructor(peg, peggyParser){
		super();
		this.peg = peg;
		this.parser = peggyParser;
	}
	
	/*  */
	static translateABNF(abnf){
		const tree = abnflib.parse(abnf);
		const supplied = map(tree);

		// Recursively pull in ABNF core rules as necessary...
		// TODO ensure that the user grammar doesn't use any of these rule names.
		const unrecognized = tree.listBrokenReferences().map(v => v.rulename);
		if(unrecognized.indexOf('CRLF') >= 0){
			if(unrecognized.indexOf('CR') === -1) unrecognized.push('CR');
			if(unrecognized.indexOf('LF') === -1) unrecognized.push('LF');
		}
		if(unrecognized.indexOf('HEXDIG') >= 0){
			if(unrecognized.indexOf('DIGIT') === -1) unrecognized.push('DIGIT');
		}
		if(unrecognized.indexOf('LWSP') >= 0){
			if(unrecognized.indexOf('WSP') === -1) unrecognized.push('WSP');
			if(unrecognized.indexOf('CRLF') === -1) unrecognized.push('CRLF');
			if(unrecognized.indexOf('CR') === -1) unrecognized.push('CR');
			if(unrecognized.indexOf('LF') === -1) unrecognized.push('LF');
			if(unrecognized.indexOf('SP') === -1) unrecognized.push('SP');
			if(unrecognized.indexOf('HTAB') === -1) unrecognized.push('HTAB');
		}
		if(unrecognized.indexOf('WSP') >= 0){
			if(unrecognized.indexOf('SP') === -1) unrecognized.push('SP');
			if(unrecognized.indexOf('HTAB') === -1) unrecognized.push('HTAB');
		}
		return supplied + unrecognized.map(v => map(abnfcore[v])).join('\n');

		// Peg prefers underscore over dash
		function mapRuleName(name){
			return name.replace(/-/g, '_');
		}

		function map(node){
			if(node instanceof abnflib.rulelist){
				return node.rules.map(v => map(v) + '\n').join('\n');
			}else if(node instanceof abnflib.rule){
				return mapRuleName(node.rulename) + '\n\t= ' + map(node.alternation);
			} else if (node instanceof abnflib.rulename) {
				return mapRuleName(node.rulename);
			} else if(node instanceof abnflib.alternation){
				return node.elements.map(v => map(v)).join('\n\t/ ');
			}else if(node instanceof abnflib.concatenation){
				return node.elements.map(v => map(v)).join(' ');
			}else if(node instanceof abnflib.repetition){
				if(node.lower===1 && node.upper===1){
					return map(node.element);
				}else if(node.lower===0 && node.upper===1){
					return map(node.element) + '?';
				}else if(node.lower===0 && node.upper===1/0){
					return map(node.element) + '*';
				}else if(node.lower===1 && node.upper===1/0){
					return map(node.element) + '+';
				}else if(node.upper===1/0){
					return map(node.element) + '|' + node.lower + '..|';
				}else{
					return map(node.element) + '|' + node.lower + '..' + node.upper + '|';
				}
			} else if (node instanceof abnflib.group) {
				return '(' + map(node.element) + ')';
			} else if (node instanceof abnflib.option) {
				return '(' + map(node.element) + ')?';
			} else if (node instanceof abnflib.char_val) {
				//
				return `"${node.string}"`
			} else if (node instanceof abnflib.prose_val) {
				return `"${node.string}"`
			} else if(node instanceof abnflib.num_val){
				return '[' + node.nums.map(function(v){
					if(typeof v.upper === 'number')
						return `\\x${v.lower.toString(16).padStart(2,'0')}-\\x${v.upper.toString(16).padStart(2,'0')}`;
					return `\\x${v.lower.toString(16).padStart(2,'0')}`;
				}).join('') + ']';
			}else{
				console.error(node);
				console.error('Unknown type');
				if (node) return node.toString();
			}
		}
	}
	
	/* Return a function that tests the given input. */
	static compile(abnf){
		const peg = tl_peg.translateABNF(abnf);
		const parser = peggy.generate(peg);
		return new tl_peg(peg, parser);
	}

	toTarget() {
		return peggy.generate(this.peg, { output: 'source', format: 'globals', exportVar: 'parser' });
	}

	test(input){
		try {
			this.parser.parse(input);
			return true;
		}catch(e){
			if(e instanceof peggy.parser.SyntaxError) return false;
			throw e;
		}
	}

	match(input){
		return this.parser.parse(input);
	}
}

module.exports.tl_peg = tl_peg;
