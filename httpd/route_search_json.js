'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.html>

const { makeRoute } = require('./route.js');
const searchIndexPromise = require('../lib/searchindex.js').buildIndex();

module.exports = makeRoute({
	name: 'route_catalog_filename_html',
	uriTemplate: 'http://localhost/search.json',
	async get(req, res, match) {
		const searchindex = await searchIndexPromise;
		const obj = searchindex.toJSON();
		obj.labels = {};
		res.setHeader('Content-Type', 'application/json');
		res.end(JSON.stringify(obj) + "\n");
	},
});
