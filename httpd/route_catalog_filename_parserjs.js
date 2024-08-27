'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.parser.js>

const { readFile } = require('fs').promises;
const { makeRoute } = require('./route.js');
const { tl_peg } = require('../lib/tl-peg.js');

module.exports = makeRoute({
	name: 'route_catalog_filename_abnf',
	uriTemplate: 'http://localhost/catalog/{filename}.parser.js',
	async get(req, res, match) {
		const abnf = await readFile(__dirname + '/../catalog/' + match.params.filename + '.abnf', 'UTF-8');
		res.setHeader('Content-Type', 'text/plain');
		res.end(tl_peg.compile(abnf).toTarget());
	}
});
