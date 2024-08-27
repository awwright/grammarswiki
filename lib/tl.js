"use strict";

const abnf = require('./abnf.js');
const abnfcore = require('./abnf-core.js');

/* Represents a grammar as written for a particular parser generator or grammar description */
class tl {

	/* Translate the given ABNF tree to the target format represented by this class */
	static translateABNFTree(tree) {
		throw new Error('Unimplemented');
	}

	/* Translate the given ABNF tree to the target format represented by this class */
	static translateABNF(tree) {
		throw new Error('Unimplemented');
	}
    
    /* Have the parser generator test the given input */
    static test(input){
        throw new Error('Unimplemented');
    }
}

module.exports.tl = tl;

