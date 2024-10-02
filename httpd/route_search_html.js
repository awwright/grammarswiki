'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.html>

const { makeRoute } = require('./route.js');

const searchIndexPromise = require('../lib/searchindex.js').buildIndex();
const { theme, escapeHTML } = require('./theme.js');

module.exports = makeRoute({
	name: 'route_catalog_filename_html',
	uriTemplate: 'http://localhost/search.html?q={q}',
	async get(req, res, match) {
		const query = decodeURIComponent(match.params.q);
		if (typeof query !== 'string' || query.length === 0) {
			res.setHeader('Content-Type', 'text/plain');
			res.end('Expected a query string');
			return;
		}

		const searchIndex = await searchIndexPromise;
		const results = searchIndex.search(query);
		const results_html = (results.length>0) ? (
			'<ul>'+results.map(function(v){
				return '<li><a href="/catalog/'+escapeHTML(v.ref+'.html')+'">'+escapeHTML(v.ref)+'</a></li>\r\n';
				// return '<li>'+escapeHTML(JSON.stringify(v))+'</li>\r\n';
			}).join('\r\n')+'</ul>')
			: 'No results';

		const title = 'Search Results: ' + query;
		const main = [
			'\t\t<h1>' + escapeHTML(title) + '</h1>',
			'\t\t<form><input type="search" name="q" value="'+escapeHTML(query)+'"/></form>',
			'\t\t' + results_html,
		].join('\r\n') + '\r\n';

		res.setHeader('Content-Type', 'application/xhtml+xml');
		res.end(theme({ title, main }));
	},
});
