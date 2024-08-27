"use strict";

const assert = require('assert');
const { FSM } = require('./fsm.js');

function parse(string){
	return re.parse(string);
}

class dialect {
	constructor(options){
		// e.g. b => 0x8
		this.escapes = {};
		// ASCII, UTF-8, UTF-16, UTF-32
		this.alphabet = '';
		// Support for the various x? x+ x* x{n,m} quantifiers
		this.optionalQuantifier = true;
		this.plusQuantifier = true;
		this.starQuantifier = true;
		this.arbritraryQuantifier = true;
		// 
		
	}
}

class production {
	constructor(options){
	}

	inspect(){
		/*
			Return a string representing the behavior of this production
			Used by util.inspect
		*/
		throw new Error("["+this.constructor.name+"] Not implemented");
	}

	toString(){
		/*
			Render the production as an RE fragment
		*/
		throw new Error("Not implemented in "+this.constructor.name);
	}

	toRegExpStr(dialect){
		/*
			Render the production as a regular expression, if possible
		*/
		throw new Error("Not implemented in "+this.constructor.name);
	}

	toInstanceString() {
		throw new Error("[toInstanceString] Not implemented in " + this.constructor.name);
	}

	static match(string, offset){
		/*
			Consume a string at the given offset as an instance.
		*/
		throw new Error("Not implemented");
	}

	static parse(string){
		/*
			Parse the entire string and return a new instance.
			This should always be the inverse of toString.
		*/
		var [instance, offset] = this.match(string, 0);
		if(offset !== string.length){
			throw new Error("Could not parse '" + string + "' beyond index " + offset);
		}
		return instance;
	}
}

// "re" is "regular expression"
// It is a FSM with additional formatting information, and some additional features like capturing groups.
// Capturing groups can only be calculated as a FSM.
class re extends production {
	constructor(rulename, defined_as, alternation){
		// if(typeof rulename !== 'string') throw new Error('Expected rulename to be a string');
		super();
		this.rulename = rulename;
		this.defined_as = defined_as;
		this.alternation = alternation;
	}

	toString(){
		return this.alternation.toString() + '\r\n';
	}

	toInstanceString() {
		return `new re(${JSON.stringify(this.rulename)}, ${JSON.stringify(this.defined_as)}, ${this.alternation.toInstanceString()})`
		// return `new re(${this.rulename.toInstanceString()}, ${JSON.stringify(this.defined_as)}, ${this.alternation.toInstanceString()})`
	}

	// rule = rulename defined-as elements c-nl
	//      = rulename defined-as alternation *c-wsp c-nl
	static match(string, offset){
		assert(typeof string === 'string');
		if(offset === undefined) offset = 0;
		// match rulename
		const [match_rulename, offset_rulename] = rulename.match(string, offset);
		if(!match_rulename) return [];
		
		// match defined-as
		const defined_as_pat = /^(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*(=|=\/)(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*/i;
		const match_defined_as = string.substring(offset_rulename).match(defined_as_pat);
		if(!match_defined_as) return [];
		
		// match alternation
		const [match_alternation, offset_alternation] = alternation.match(string, offset_rulename + match_defined_as[0].length);
		if(!match_alternation) return [];
		
		// match *c-wsp c-nl
		const wsp = /^(((;[\t -@\[-~]*)?\r\n)?[\t ])*(;[\t -@\[-~]*)?\r\n/i;
		const match_wsp = string.substring(offset_alternation).match(wsp);
		if(!match_wsp) return [];

		return [new re(match_rulename.toString(), match_defined_as[1], match_alternation), offset_alternation + match_wsp[0].length];
	}

	static fromFSM(){
		//...
	}

}

class alternation extends production {
	constructor(concs){
		if(concs===undefined) concs = [];
		if(!Array.isArray(concs)) throw new Error('Expected concs to be an array');
		concs.forEach(function(v, i){
			// if(!(v instanceof concatenation)) throw new Error('Expected concs['+i+'] to be instanceof concatenation');
		});
		super();
		this.elements = concs.slice();
	}

	equals(other){
		if(!(other instanceof alternation)) return false;
		// return this.concs.equals(other.concs);
		return this.elements.length === other.elements.length && this.elements.every( (v,i) => v.equals(other.elements[i]) );
	}

	inspect(){
		return "alternation(" + this.elements.map(c => c.inspect()).join(", ") +  ")";
	}

	toString(){
		if(this.elements.length===0){
			throw new Error("Can't serialise " + inspect(this));
		}
		return this.elements.join('|');
	}

	toInstanceString() {
		return `new alternation([${this.elements.map(v => v.toInstanceString()).join(', ')}])`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.elements.flatMap(v => v.flatten()));
	}

	// Get the tokens that make up the RE, omit own node if it has children
	leaves() {
		return this.elements.flatMap(v => v.leaves());
	}

	listReferences() {
		const refs = this.elements.flatMap(e => e.listReferences());
		const seen = new Set;
		return refs.filter(function(v){
			if(seen.has(v)) return false;
			seen.add(v);
			return true;
		});
	}

	toRegExpStr(rulemap) {
		return this.elements.map(e => e.toRegExpStr(rulemap)).join('|');
	}

	static match(string, offset){
		if(offset===undefined) offset = 0;
		const concs = [];
		
		//first one
		{
			const [concat_match, concat_offset] = concatenation.match(string, offset);
			if(!concat_match) return [];
			concs.push(concat_match);
			offset = concat_offset;
		}
		
		// matches *c-wsp "/" *c-wsp
		const pattern_sep = /^(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*\/(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*/i;
		while(true){
			const match_sep = string.substring(offset).match(pattern_sep);
			if(!match_sep) break;
			offset += match_sep[0].length;

			const [match_concatenation, concat_offset] = concatenation.match(string, offset);
			if(!match_concatenation) break;
			concs.push(match_concatenation);
			offset = concat_offset;
		}
		return [new alternation(concs), offset];
	}

	toFSM(){
		return this.elements.map(v => v.toFSM()).reduce((a,b) => a.union(b));
	}

	toPDA(){
		return this.elements.map(v => v.toPDA()).reduce((a,b) => a.union(b));
	}
}

class concatenation extends production {
	/*
		A concatenation is a list of repetitions.

		concatenation  =  repetition *(1*c-wsp repetition)
	*/

	constructor(repetitions){
		if(!Array.isArray(repetitions)) throw new Error('Expected repetitions to be an array');
		if(repetitions.length < 1) throw new Error('Needs minimum one item');
		repetitions.forEach(function(mult, i){
			if(!(mult instanceof repetition)) throw new Error('repetitions['+i+'] not instanceof repetition');
		});
		super();
		this.elements = repetitions;
	}

	inspect(){
		return "concatenation(" + this.elements.map(v => v.inspect()).join(", ") + ")";
	}

	toFSM(){
		//start with a component accepting only the empty string
		return this.elements.map(v => v.toFSM()).reduce((a, b)=>(a.concatenate(b)));
	}

	toString(){
		return this.elements.join('');
	}

	listReferences() {
		const refs = this.elements.flatMap(e => e.listReferences());
		const seen = new Set;
		return refs.filter(function (v) {
			if (seen.has(v)) return false;
			seen.add(v);
			return true;
		});
	}

	toInstanceString() {
		return `new concatenation([${this.elements.map(v => v.toInstanceString()).join(', ')}])`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.elements.flatMap(v => v.flatten()));
	}

	// Get the tokens that make up the RE, omit own node if it has children
	leaves() {
		return this.elements.flatMap(v => v.leaves());
	}

	toRegExpStr(rulemap) {
		return this.elements.map(e => e.toRegExpStr(rulemap)).join('');
	}

	static match(string, offset){
		if(offset===undefined) offset = 0;
		const repetition_elements = [];
		
		//first one
		{
			const [match_repetition, j] = repetition.match(string, offset);
			if(!match_repetition) return [];
			repetition_elements.push(match_repetition);
			offset = j;
		}
	
		// matches 1*c-wsp
		const pattern_sep = /^(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])+/i;
		while(true){
			const match_sep = string.substring(offset).match(pattern_sep);
			if(!match_sep) break;

			const [match_repetition, j] = repetition.match(string, offset + match_sep[0].length);
			if(!match_repetition) break;
			repetition_elements.push(match_repetition);
			offset = j;
		}
		return [new concatenation(repetition_elements), offset];
	}

}

class repetition extends production {
	constructor(e, lower, upper){
		// if(!(e instanceof element)) throw new Error('Expected e to be a element');
		super();
		this.element   = e;
		this.lower = lower;
		this.upper = upper;
	}

	inspect(){
		return "repetition(" + this.element.inspect() + ")";
	}

	toString(){
		if(this.lower === 1 && this.upper === 1){
			return this.element.toString();
		}
		return (this.lower===0 ? '' : this.lower) + '*' + (this.upper===1/0 ? '' : this.upper) + this.element.toString();
	}

	toInstanceString() {
		return `new repetition(${this.element.toInstanceString()}, ${JSON.stringify(this.lower)}, ${JSON.stringify(this.upper)})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.element.flatten());
	}

	// Get the tokens that make up the RE, omit own node if it has children
	leaves() {
		return this.element.leaves();
	}

	listReferences() {
		return this.element.listReferences();
	}

	toRegExpStr(rulemap) {
		if (this.lower === 1 && this.upper === 1) {
			return this.element.toRegExpStr(rulemap);
		}
		if (this.lower === 0 && this.upper === 1) {
			return this.element.toRegExpStr(rulemap) + '?';
		}
		if (this.lower === 1 && this.upper === 1/0) {
			return this.element.toRegExpStr(rulemap) + '+';
		}
		if (this.lower === 0 && this.upper === 1/0) {
			return this.element.toRegExpStr(rulemap) + '*';
		}
		return this.element.toRegExpStr(rulemap) + '{' + (this.lower === 0 ? '' : this.lower) + ',' + (this.upper === 1 / 0 ? '' : this.upper) + '}';
	}

	toFSM(){
		//worked example: (min, max) = (5, 7) or (5, inf)
		//(mandatory, optional) = (5, 2) or (5, inf)
		return this.element.toFSM().repeat(this.lower, this.upper);
	}

	static match(string, offset){
		// repetition     =  [repeat] element
		// repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)

		if(offset===undefined) offset = 0;
		
		// optional "repeat" specifier
		const specifier_pattern = /(\d*)(?:\x2a(\d*))?/i;
		const specifier_match = string.substring(offset).match(specifier_pattern);

		// required "element"
		const [element_match, element_offset] = element.match(string, offset+specifier_match[0].length);
		if(!element_match) return [];

		if(typeof specifier_match[2] === 'string'){
			const lower = specifier_match[1] ? parseInt(specifier_match[1], 10) : 0;
			const upper = specifier_match[2] ? parseInt(specifier_match[2], 10) : Number.POSITIVE_INFINITY;
			return [new repetition(element_match, lower, upper), element_offset];
		}else{
			return [new repetition(element_match, 1, 1), element_offset];
		}
	}
}

class element extends production {
	// element = group / char-val / num-val / prose-val
	static match(string, offset){
		if(offset===undefined) offset = 0;
		if(string[offset] === '('){
			return group.match(string, offset);
		}
		if(string[offset] === '\\'){
			return char_val.match(string, offset);
		}
		return new char_val();
	}
}

class group extends production {
	constructor(element){
		assert(element instanceof alternation);
		super();
		this.element = element;
	}

	inspect(){
		return "group(" + this.element.map(c => c.inspect()).join(", ") +  ")";
	}

	toString(){
		return '('+this.element.toString()+')';
	}

	toInstanceString() {
		return `new group(${this.element.toInstanceString()})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.element.flatten());
	}

	// Get the tokens that make up the RE, omit own node if it has children
	leaves() {
		return this.element.leaves();
	}

	listReferences() {
		return this.element.listReferences();
	}

	toRegExpStr(dialect, rulemap) {
		return '(' + this.element.toRegExpStr(dialect, rulemap) + ')';
	}

	static match(string, offset){
		if(offset===undefined) offset = 0;

		const open_pattern = /\((?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*/i;
		const open_match = string.substring(offset).match(open_pattern);
		if(!open_match) return [];

		const [alternation_match, offset_alternation] = alternation.match(string, offset + open_match[0].length);
		if(!alternation_match) return [];

		const close_pattern = /(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*\)/i;
		const close_match = string.substring(offset_alternation).match(close_pattern);
		if(!close_match) return [];

		return [new group(alternation_match), offset_alternation + close_match[0].length];
	}

	toFSM(){
		return this.element.map(v => v.toFSM()).reduce((a,b) => a.union(b));
	}
}

class char_val extends production {
	constructor(string){
		super();
		this.string = string;
	}

	equals(other){
		if(!(other instanceof alternation)) return false;
		// return this.concs.equals(other.concs);
		return this.concs.length === other.elements.length && this.concs.every( (v,i) => v.equals(other.elements[i]) );
	}

	inspect(){
		return "char_val(" + this.string +  ")";
	}

	toString(){
		return '"' + this.string + '"';
	}

	toInstanceString() {
		return `new char_val(${JSON.stringify(this.string)})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this];
	}

	// Get the tokens that make up the RE, omit own node if it has children
	leaves() {
		return [this];
	}

	listReferences() {
		return [];
	}

	toRegExpStr(rulemap) {
		const regex_sc = /[.*+?^${}()|[\]\\/]/g;
		return this.string.replace(regex_sc, '\\$&');
	}

	toPDA(){

	}

	static match(string, offset){
		if(!offset) offset = 0;
		const char_val_pat = /"([ !\x23-@\x5b-~]*)"/i;
		const m = string.substring(offset).match(char_val_pat);
		if(!m) return [];
		return [new char_val(m[1]), offset+m[0].length];
	}

	toFSM(){
		const string = this.string;
		const states = Array.from({ length: string.length }).map(function (_, i) {
			const ccode = string.charCodeAt(i);
			// Quoted strings are case-insensitive
			if (ccode >= 0x41 && ccode <= 0x5A || ccode >= 0x61 && ccode <= 0x7A) {
				return { [string[i].toUpperCase()]: i + 1, [string[i].toLowerCase()]: i + 1 };
			}else{
				return { [string[i]]: i + 1 };
			}
		}).concat([{}]);
		return new FSM(states, 0, [string.length]);
	}
}

module.exports = {
	parse, production,
	re,
	alternation, concatenation, repetition, group, element,
	char_val,
};

