
class Grammar {
	constructor(variables, terminals, productions, start) {
		const self = this;
		self.variables = variables;
		self.terminals = terminals;
		self.productions = [];
		self.productionsMap = new Map;
		self.start = start===undefined ? variables[0] : start;

		if (productions === undefined) productions = [];
		if (!Array.isArray(productions)) throw new Error('Expected productions to be an array');
		productions.forEach(function (v, i) {
			if(v && v.length === 2){
				const p = new Production(v[0], v[1]);
				if(!self.productionsMap.has(v[0])) self.productionsMap.set(v[0], []);
				self.productionsMap.get(v[0]).push(p);
				self.productions.push(p);
			}else{
				if (!(v instanceof Production)) throw new Error('Expected productions[' + i + '] to be instanceof Production');
				self.productionsMap.get(v.head).push(v);
				self.productions.push(v);
			}
		});
	}

	toString() {
		return this.productions.map(v => v.toString()).join('');
	}

	toAlternatesString() {
		return Array.from(this.productionsMap).map(function(e){
			const [k, v] = e;
			return k + ' → ' + v.map(w => w.body).join(' | ');
		}).join('\n');
	}

	toInstanceString() {
		return this.productions.map(v => v.toInstanceString()).join('');
	}

	toPDA(PDA){
		
	}
}

class Production {
	constructor(head, body) {
		this.head = head;
		this.body = body;
	}

	toString() {
		return this.head.toString() + ' → ' + this.body.toString() + '\r\n';
	}

	toInstanceString() {
		return `new rule(${JSON.stringify(this.rulename)}, ${JSON.stringify(this.defined_as)}, ${this.alternation.toInstanceString()})`
		return `new rule(${this.rulename.toInstanceString()}, ${JSON.stringify(this.defined_as)}, ${this.alternation.toInstanceString()})`
	}

}

class Variable {

}

class Terminal {

}

module.exports = { Grammar, Production, Variable, Terminal };
