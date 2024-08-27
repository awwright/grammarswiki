"use strict";

const assert = require('assert');
const { FSM } = require('./fsm.js');
const { PDA } = require('./pda.js');

function parse(string){
	return rulelist.parse(string);
}

class production {
	constructor(options){
		// this.startAddr = options.startAddr || 0;
		// this.startLine = options.startLine || 0;
		// this.startCol = options.startCol || 0;
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
			Render the production as an ABNF fragment
		*/
		throw new Error("Not implemented in "+this.constructor.name);
	}

	toRegExpStr(){
		/*
			Render the production as a regular expression, if possible
		*/
		throw new Error("Not implemented in "+this.constructor.name);
	}

	toInstanceString() {
		throw new Error("[toInstanceString] Not implemented in " + this.constructor.name);
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.leaves());
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	leaves() {
		throw new Error("[flatten] Not implemented in " + this.constructor.name);
	}

	// Get all of the rule references that this rule contains
	listReferences() {
		throw new Error("[listReferences] Not implemented in " + this.constructor.name);
	}

	listDefinitions() {
		throw new Error("[listDefinitions] Not implemented in " + this.constructor.name);
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

class rulelist extends production {
	constructor(rules){
		if(rules===undefined) rules = [];
		if(!Array.isArray(rules)) throw new Error('Expected rules to be an array');
		rules.forEach(function(v, i){
			if(!(v instanceof rule)) throw new Error('Expected rules['+i+'] to be instanceof conc');
		});
		super();
		this.rules = rules;
	}

	toString(){
		return this.rules.map(rule => rule.toString()).join('');
	}

	toInstanceString() {
		return this.rules.map(rule => rule.toInstanceString()).join('');
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.rules.flatMap(v => v.flatten()));
	}

	// Get the tokens that make up the ABNF
	leaves() {
		return this.rules.flatMap(v => v.leaves());
	}

	listReferences() {
		const rulenameToRule = Object.fromEntries(this.rules.map(v => [v.rulename, v]));
		return this.leaves().filter(function(v){
			return v instanceof rulename;
		});
	}

	listBrokenReferences() {
		const rulenameToRule = Object.fromEntries(this.rules.map(v => [v.rulename, v]));
		return this.leaves().filter(function(v){
			return v instanceof rulename && rulenameToRule[v.rulename] === undefined;
		});
	}

	static match(string, offset){
		if(offset === undefined) offset = 0;
		// *c-wsp c-nl
		const fws = /^(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*(?:;[\t -@\x5b-~]*\r\n|\r\n)/i;
		const list = [];
		while(true){
			// Try to match a rule (including terminating crlf) or fws+crlf
			// Try to match the whitespace first
			const match_ws = string.substring(offset).match(fws);
			if(match_ws){
				offset += match_ws[0].length;
				continue;
			}
			// pat.lastIndex = offset || 0;
			// console.dir(pat.lastIndex);
			// console.dir(string.match(pat));
			const [match_rulename, match_offset] = rule.match(string, offset);
			if(match_rulename){
				list.push(match_rulename);
				offset = match_offset;
				continue;
			}
			return [new rulelist(list), offset];
		}
	}
}

class rule extends production {
	constructor(rulename, defined_as, alternation){
		// if(typeof rulename !== 'string') throw new Error('Expected rulename to be a string');
		super();
		this.rulename = rulename;
		this.defined_as = defined_as;
		this.alternation = alternation;
	}

	toString(){
		return this.rulename.toString() + ' ' + this.defined_as + ' ' + this.alternation.toString() + '\r\n';
	}

	toInstanceString() {
		return `new rule(${JSON.stringify(this.rulename)}, ${JSON.stringify(this.defined_as)}, ${this.alternation.toInstanceString()})`
		// return `new rule(${this.rulename.toInstanceString()}, ${JSON.stringify(this.defined_as)}, ${this.alternation.toInstanceString()})`
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this, this.rulename, this.defined_as].concat(this.alternation.flatten());
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return [this.rulename, this.defined_as].concat(this.alternation.leaves());
	}
	
	listReferences() {
		return this.alternation.listReferences();
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

		return [new rule(match_rulename.toString(), match_defined_as[1], match_alternation), offset_alternation + match_wsp[0].length];
	}

	/* Generate instances of the grammar */
	strings(){

	}

	/* Generate negative examples of the grammar */
	negativeStrings(){

	}

}

class rulename extends production {
	constructor(rulename){
		assert(typeof rulename === 'string');
		assert.match(rulename, /^[a-z][\x2d0-9a-z]*$/i);
		super();
		this.rulename = rulename;
		Object.freeze(this);
	}

	toString(){
		return this.rulename;
	}

	toInstanceString() {
		return `new rulename(${JSON.stringify(this.rulename)})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this];
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return [this];
	}

	toRegExpStr(rulemap) {
		if (rulemap[this.rulename]===null) return '[:'+this.rulename+':]';
		// if (rulemap[this.rulename]===null) throw new Error('Recursive use of '+this.rulename);
		if (rulemap[this.rulename]===undefined) throw new Error('Unknown rule '+this.rulename);
		const rulemap_ = Object.fromEntries(Object.entries(rulemap));
		// Prevent a rule from being embedded more than once, which means it will be embedded infinitely
		rulemap_[this.rulename] = null;
		return '(' + rulemap[this.rulename].toRegExpStr(rulemap_) + ')';
	}

	static match(string, offset){
		if(offset === undefined) offset = 0;
		const rulename_pat = /^[a-z][\x2d0-9a-z]*/i;
		const match_rulename = string.substring(offset).match(rulename_pat);
		if(match_rulename){
			return [new rulename(match_rulename[0]), offset+match_rulename[0].length];
		}
		return [];
	}

	inspect(){
		return "rulename(" + this.rulename + ")";
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
		return this.elements.join(' / ');
	}

	toInstanceString() {
		return `new alternation([${this.elements.map(v => v.toInstanceString()).join(', ')}])`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.elements.flatMap(v => v.flatten()));
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
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
		return this.elements.join(' ');
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

	// Get the tokens that make up the ABNF, omit own node if it has children
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

	// Get the tokens that make up the ABNF, omit own node if it has children
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
	// element = rulename / group / option / char-val / num-val / prose-val
	static match(string, offset){
		if(offset===undefined) offset = 0;
		if(string[offset] === '('){
			return group.match(string, offset);
		}
		if(string[offset] === '['){
			return option.match(string, offset);
		}
		if(string[offset] === '"'){
			return char_val.match(string, offset);
		}
		if(string[offset] === '%'){
			return num_val.match(string, offset);
		}
		if(string[offset] === '<'){
			return prose_val.match(string, offset);
		}
		return rulename.match(string, offset);
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

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return this.element.leaves();
	}

	listReferences() {
		return this.element.listReferences();
	}

	toRegExpStr(rulemap) {
		return '(' + this.element.toRegExpStr(rulemap) + ')';
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

class option extends production {
	constructor(element){
		assert(element instanceof alternation);
		super();
		this.element = element;
	}

	inspect(){
		return "option(" + this.element.map(c => c.inspect()).join(", ") +  ")";
	}

	toString(){
		return '['+this.element.toString()+']';
	}

	toInstanceString() {
		return `new option(${this.element.toInstanceString()})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this].concat(this.element.flatten());
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return this.element.leaves();
	}

	listReferences() {
		return this.element.listReferences();
	}

	toRegExpStr(rulemap) {
		return '' + this.element.toRegExpStr(rulemap) + '?';
	}

	static match(string, offset){
		if(offset===undefined) offset = 0;

		//first one
		const open_pattern = /\[(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*/i;
		const open_match = string.substring(offset).match(open_pattern);
		if(!open_match) return [];

		const [alternation_match, offset_alternation] = alternation.match(string, offset + open_match[0].length);
		if(!alternation_match) return [];

		const close_pattern = /(?:[\t ]|(?:;[\t -@\x5b-~]*\r\n|\r\n)[\t ])*\]/i;
		const close_match = string.substring(offset).match(close_pattern);
		if(!close_match) return [];

		return [new option(alternation_match), offset_alternation + close_match[0].length];
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
		return "alternation(" + this.concs.map(c => c.inspect()).join(", ") +  ")";
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

	// Get the tokens that make up the ABNF, omit own node if it has children
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

class num_val extends production {
	constructor(base, sequence){
		if(sequence===undefined) concs = [];
		assert.match(base, /^[bdx]$/i);
		assert(Array.isArray(sequence));
		sequence.forEach(function(v){
			assert(v instanceof bin_val || v instanceof dec_val || v instanceof hex_val);
		});
		super();
		this.base = base;
		this.nums = sequence;
	}

	inspect(){
		return "num_val(" + this.nums.map(c => c.inspect()).join(", ") +  ")";
	}

	toString(){
		if(this.nums.length===0){
			throw new Error("Can't serialise " + inspect(this));
		}

		//take the alternation of the input collection of regular expressions.
		//i.e. jam "|" between each element

		//1+ elements.
		return '%' + this.base + this.nums.join('.');
	}

	toInstanceString() {
		return `new num_val(${JSON.stringify(this.base)}, [${this.nums.map(v => v.toInstanceString()).join(',')}])`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this];
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return [this];
	}

	listReferences() {
		return [];
	}

	toRegExpStr(rulemap) {
		// return this.nums.map(v => `\\${this.base}${v}`).join('');
		return this.nums.map(v => v.toRegExpStr()).join('');
	}

	static match(string, offset){
		if(offset===undefined) offset = 0;
		const m = string.substring(offset).match(/^%[bdx]([0-9a-f]+([.-][0-9a-f]+)*)/i);
		if(!m) return [];
		const base = m[0][1];
		const base_class = ({
			'b': bin_val, 'B': bin_val,
			'd': dec_val, 'D': dec_val,
			'x': hex_val, 'X': hex_val,
		})[base];
		const concs = m[1].split(/\./g).map( s => base_class.match(s)[0] );
		return [new num_val(base, concs), offset+m[0].length];
	}

	toFSM(){
		return this.nums.map(v => v.toFSM()).reduce((a,b) => a.union(b));
	}

}

class bin_val extends production {
	constructor(lower, upper){
		super();
		this.lower = lower;
		this.upper = upper;
		Object.freeze(this);
	}

	inspect(){
		return "bin_val(" + this.concs.map(c => c.inspect()).join(", ") +  ")";
	}

	toString(){
		return this.lower.toString(2) + (this.upper ? ('-'+this.upper.toString(2)) : '');
	}

	toInstanceString() {
		return `new bin_val(${JSON.stringify(this.lower)}, ${JSON.stringify(this.upper)})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this];
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return [this];
	}

	listReferences() {
		return [];
	}

	toRegExpStr(rulemap) {
		if(this.upper === this.lower || this.upper===undefined){
			return '\\x' + this.lower.toString(16);
		}else{
			return '[\\x' + this.lower.toString(16) + '-\\x' + this.upper.toString(16) + ']';
		}
	}

	static match(string, offset){
		if(offset===undefined) offset=0;
		if(offset >= string.length) return [];

		const hex_digits = /([01]+)(?:-([01]+))?/;
		const m = string.match(hex_digits);
		if(!m) return [];
		const char = parseInt(m[1], 2);
		const upper = m[2] ? parseInt(m[2], 2) : undefined;
		return [new bin_val(char, upper), offset + m[0].length];
	}

	toFSM(){
		return this.concs.map(v => v.toFSM()).reduce((a,b) => a.union(b));
	}
}

class dec_val extends production {
	constructor(lower, upper){
		super();
		this.lower = lower;
		this.upper = upper;
		Object.freeze(this);
	}

	toString(){
		return this.lower.toString(10) + (this.upper ? ('-'+this.upper.toString(10)) : '');
	}

	toInstanceString() {
		return `new dec_val(${JSON.stringify(this.lower)}, ${JSON.stringify(this.upper)})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this];
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return [this];
	}

	listReferences() {
		return [];
	}

	toRegExpStr(rulemap) {
		if(this.upper === this.lower || this.upper===undefined){
			return '\\x' + this.lower.toString(16);
		}else{
			return '[\\x' + this.lower.toString(16) + '-\\x' + this.upper.toString(16) + ']';
		}
	}

	static match(string, offset){
		if(offset===undefined) offset=0;
		if(offset >= string.length) return [];

		const hex_digits = /([0-9]+)(?:-([0-9]+))?/;
		const m = string.match(hex_digits);
		if(!m) return [];
		const char = parseInt(m[1], 10);
		const upper = m[2] ? parseInt(m[2], 10) : undefined;
		return [new dec_val(char, upper), offset + m[0].length];
	}

	toFSM(){
		return this.concs.map(v => v.toFSM()).reduce((a,b) => a.union(b));
	}

	reversed(){
		return new alternation(this.concs.map(c => c.reversed()));
	}

	copy(){
		return new alternation(this.concs.map(c => c.copy()));
	}
}

class hex_val extends production {
	/*
		A hex_val might identify a charclass or it might identify a concatenated string of characters. Or a single character, which should appear as a charclass.
	*/

	constructor(lower, upper){
		super();
		this.lower = lower;
		this.upper = upper;
		Object.freeze(this);
	}

	toString(){
		return this.lower.toString(16) + (this.upper ? ('-'+this.upper.toString(16)) : '');
	}

	toInstanceString() {
		if (this.upper === undefined)
			return `new hex_val(${JSON.stringify(this.lower)})`;
		else
			return `new hex_val(${JSON.stringify(this.lower)}, ${JSON.stringify(this.upper)})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this];
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return [this];
	}

	listReferences() {
		return [];
	}

	toRegExpStr(rulemap) {
		if(this.upper === this.lower || this.upper===undefined){
			return '\\x' + this.lower.toString(16);
		}else{
			return '[\\x' + this.lower.toString(16) + '-\\x' + this.upper.toString(16) + ']';
		}
	}

	toFSM(){
		//If negated, make a singular FSM accepting any other characters
		//If normal, make a singular FSM accepting only these characters
		var map = this.chars.toArray().map(symbol => [symbol, 1]);
		
		return new FSM(
			[
				map,
				{},
			], // map
			0, // initial
			[1], // finals
		);
	}

	inspect(){
		var string = this.negated ? '~' : '';
		string += "charclass(";
		if(this.chars.size){
			string += JSON.stringify(this.chars.toArray().join(''));
		}
		string += ")";
		return string;
	}

	static parse(string){
		/*
			Parse the entire supplied string as an instance of the present class.
			Mainly for internal use in unit tests because it drops through to match()
			in a convenient way.
		*/
		var [obj, i] = hex_val.match(string, 0);
		if(i != string.length){
			throw new Error("Could not parse '" + string + "' beyond index " + i);
		}
		return obj;
	}

	static match(string, offset){
		if(offset===undefined) offset=0;
		if(offset >= string.length) return [];

		const hex_digits = /([0-9a-fA-F]+)(?:-([0-9a-fA-F]+))?/;
		const m = string.match(hex_digits);
		if(!m) return [];
		const char = parseInt(m[1], 16);
		const upper = m[2] ? parseInt(m[2], 16) : undefined;
		return [new hex_val(char, upper), offset + m[0].length];
	}

	toFSM() {
		const map = [
			{},
			{},
		];
		const char_map = map[0];
		for(let i=this.lower; i<=this.upper; i++){
			char_map[String.fromCharCode(i)] = 1;
		}
		return new FSM(map, 0, [1]);
	}
}

class prose_val extends production {
	/*
		a prose_val is a non-machine-readable rule that's described in prose instead of a specific notation.
	*/
	constructor(remark){
		super();
		this.remark = remark;
	}

	inspect(){
		return "prose_val(" + this.remark +  ")";
	}

	toString(){
		return '<'+this.remark+'>';
	}

	toInstanceString() {
		return `new prose_val(${JSON.stringify(this.remark)})`;
	}

	// Get this node and all of the nodes below it in a single array, to be filtered
	flatten() {
		return [this];
	}

	// Get the tokens that make up the ABNF, omit own node if it has children
	leaves() {
		return [this];
	}

	listReferences() {
		// TODO maybe include prose_val in here
		return [];
	}

	static match(string, offset){
		if(offset===undefined) offset = 0;
		const pattern_prose_val = /<([ -=\x3f@\x5b-~]*)>/i;
		const match_prose_val = string.substring(offset).match(pattern_prose_val);
		if(!match_prose_val) return [];
		return [new prose_val(match_prose_val[1]), offset+match_prose_val[0].length];
	}

	toFSM(){
		throw new Error('Not possible to convert prose_val to FSM');
	}
}

module.exports = {
	parse, production,
	rulelist, rule, rulename,
	alternation, concatenation, repetition, group, option, element,
	char_val, num_val, bin_val, dec_val, hex_val, prose_val,
};

