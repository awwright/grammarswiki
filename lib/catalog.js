'use strict';
// Utilities to enumerate all of the listings in the catalog.

const fsp = require('fs').promises;

const catalogPath = __dirname + '/../catalog';
module.exports.catalogPath = catalogPath;

module.exports.listGrammars = listGrammars;
async function listGrammars(){
	return (await fsp.readdir(catalogPath)).flatMap(function(filename){
		const m = filename.match(/^([a-z0-9-]+)\.(abnf)$/);
		if(!m) return [];
		const path = catalogPath + '/' + filename;
		const name = m[1];
		const type = m[2];
		return [{ path, filename, name, type }];
	});
}
