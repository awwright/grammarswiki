'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.abnf>

const fs = require('fs');
const fp = require('fs').promises;
const { makeRoute } = require('./route.js');

const abnf = require('../lib/abnf.js');
const abnfcore = require('../lib/abnf-core.js');

module.exports = makeRoute({
	name: 'route_catalog_filename_abnf',
	uriTemplate: 'http://localhost/catalog/{filename}.abnf',
	async get(req, res, match) {
		const contents = fs.createReadStream(__dirname + '/../catalog/' + match.params.filename + '.abnf');
		res.setHeader('Content-Type', 'text/plain');
		contents.pipe(res);
	}
});

