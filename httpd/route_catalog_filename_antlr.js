'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.antlr>

const fs = require('fs');
const { readFile } = require('fs').promises;
const { makeRoute } = require('./route.js');

const abnf = require('../lib/abnf.js');
const abnfcore = require('../lib/abnf-core.js');

// const chevrotain = require('chevrotain');

module.exports = makeRoute({
	name: 'route_catalog_filename_abnf',
	uriTemplate: 'http://localhost/catalog/{filename}.antlr',
	async get(req, res, match) {
		const contents = await readFile(__dirname + '/../catalog/' + match.params.filename + '.abnf', 'UTF-8');
		const tree = abnf.parse(contents);

		function map(node){
			if(node instanceof abnf.rulelist){
				return node.rules.map(v => map(v) + '\n').join('\n');
			}else if(node instanceof abnf.rule){
				return node.rulename + '\n\t: ' + map(node.alternation);
			}else if(node instanceof abnf.alternation){
				return node.elements.map(v => map(v)).join('\n\t| ');
			}else if(node instanceof abnf.concatenation){
				return node.elements.map(v => map(v)).join(' ');
			}else if(node instanceof abnf.repetition){
				if(node.lower===1 && node.upper===1){
					return map(node.element);
				}else if(node.upper===1/0){
					return map(node.element) + '|' + node.lower + '..|';
				}else{
					return map(node.element) + '|' + node.lower + '..' + node.upper + '|';
				}
			}else if(node instanceof abnf.rulename){
				return node.rulename;
			}else if(node instanceof abnf.char_val){
				return `"${node.string}"`
			}else if(node instanceof abnf.num_val){
				return node.toString();
			}else if(node instanceof abnf.num_val){
				return node.toString();
			}else if(node instanceof abnf.num_val){
				return node.toString();
			}else if(node instanceof abnf.option){
				return '(' + node.element + ')?';
			}else if(node instanceof abnf.group){
				return '(' + node.element + ')';
			}else{
				console.log(node);
				console.error('Unknown type '+node.constructor.name);
				return node.toString();
			}
		}

		res.setHeader('Content-Type', 'text/plain');
		res.end(map(tree));
	}
});

