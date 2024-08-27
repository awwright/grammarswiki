'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.peg>

const fs = require('fs');
const { readFile } = require('fs').promises;
const { makeRoute } = require('./route.js');

const abnf = require('../lib/abnf.js');
const abnfcore = require('../lib/abnf-core.js');

const { tl_peg } = require('../lib/tl-peg.js');

// (async function(){

module.exports = makeRoute({
	name: 'route_catalog_filename_abnf',
	uriTemplate: 'http://localhost/catalog/{filename}.peg',
	async get(req, res, match) {
		const abnf = await readFile(__dirname + '/../catalog/' + match.params.filename + '.abnf', 'UTF-8');
		res.setHeader('Content-Type', 'text/plain');
		res.end(tl_peg.translateABNF(abnf));
	}
});

