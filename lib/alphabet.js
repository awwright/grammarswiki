"use strict";

// Provide different ways to manage alphabets;
// to test if a symbol is in the alphabet,
// to find the inverse of the alphabet, etc.

class Alphabet {
	constructor(alphabet) {
	}

	// Test if the alphabet includes the given symbol
	has(symbol) {
		return this.map.has(symbol);
	}

	// Return the alphabet number for the given character/string
	get(symbol) {
		return this.map.get(symbol);
	}

	// Convert the alphabet number to a string for display
	out(i) {
		return this.alphabet[i];
	}

	consume(input) {
		if (typeof input === 'string') {
			return input.split('').map(c => this.map.get(c));
		}
		if (Array.isArray(input)) {
			return input.map(c => this.map.get(c));
		}
		throw new Error('Expected `input` to be a string or array of symbols');
	}
}

class Charset extends Alphabet {
	constructor(min, max) {
		super();
		this.min = min;
		this.max = max;
	}

	// Test if the alphabet includes the given symbol
	has(symbol) {
		return this.map.has(symbol);
	}

	// Return the alphabet number for the given character/string
	get(symbol) {
		return this.map.get(symbol);
	}

	// Convert the alphabet number to a string for display
	out(i) {
		return this.alphabet[i];
	}

	consume(input) {
		if (typeof input === 'string') {
			return input.split('').map(c => this.map.get(c));
		}
		if (Array.isArray(input)) {
			return input.map(c => this.map.get(c));
		}
		throw new Error('Expected `input` to be a string or array of symbols');
	}
}

// class UTF_32 extends Alphabet {
// 	// Maps strings to unicode code points
// }

const UTF_32 = new Charset(0, 0x10FFFF);

// class UTF_16 extends Alphabet {
// 	// Maps strings to UTF-16 codepoints with surrogate pairs
// }
const UTF_16 = new Charset(0, 0xFFFF);

// class UTF_8 extends Alphabet {
// 	// Maps strings to UTF-8 bytes
// }
const UTF_8 = new Charset(0, 0xFF);

// class ASCII extends Alphabet {
// 	// Only recognizes 7-bit ASCII characters, all other characters are out of the alphabet.
// }
const ASCII = new Charset(0, 0x7F);

class SymbolMap extends Alphabet {
	// Only recognizes the specified characters, other characters are out of the alphabet.
	constructor(alphabet){
		this.alphabet = alphabet;
		this.map = new Map(alphabet.map( (c,i)=>[c,i] ));
		this.size = alphabet.length;
		Object.freeze(this);
	}

	static fromString(str) {
		return new SymbolMap(str.split(''));
	}

	has(symbol){
		return this.map.has(symbol);
	}

	get(symbol){
		return this.map.get(symbol);
	}

	out(i){
		return this.alphabet[i];
	}

	consume(input){
		if(typeof input==='string'){
			return input.split('').map(c => this.map.get(c));
		}
		if(Array.isArray(input)){
			return input.map(c => this.map.get(c));
		}
		throw new Error('Expected `input` to be a string or array of symbols');
	}
}
