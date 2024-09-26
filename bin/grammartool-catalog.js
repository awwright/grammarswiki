"use strict";

const catalog = require('../lib/catalog.js');

main();

async function main(){
	const list = await catalog.listGrammars();
	list.forEach(function(grammar){
		// console.log(grammar);
		console.log(grammar.name.padEnd(30), grammar.type.padEnd(4), grammar.path);
	});
}

