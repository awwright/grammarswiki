'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.html>

const fs = require('fs');
const fsp = require('fs').promises;
const lunr = require('lunr');

const abnf = require('./abnf.js');
const abnfcore = require('./abnf-core.js');
const catalog = require('./catalog.js');


module.exports.buildIndex = buildIndex;
async function buildIndex(){
	const rules = await catalog.listGrammars();
	const index = new lunr.Builder();
	index.field('title');

	for(const rule of rules){
		const name = rule.name;

		// Index the grammar document
		index.add({
			id: name,
			title: name,
		});

		const inData = (await fsp.readFile(rule.path)).toString();
		// Index the rule names in the document
		// console.log(id, inData);
		const rulelist = abnf.parse(inData);
		rulelist.rules.forEach(function (rule) {
			// Index the grammar document
			index.add({
				id: name + '.' + rule.rulename,
				title: rule.rulename,
				grammar: name,
			});
		});
	}

	return index.build();
}
