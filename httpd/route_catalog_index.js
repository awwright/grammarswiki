'use strict';
// <http://localhost:8080/catalog/>

const fp = require('fs').promises;
const { makeRoute } = require('./route.js');
const { theme, escapeHTML } = require('./theme.js');
const catalog = require('../lib/catalog.js');

module.exports = makeRoute({
	uriTemplate: 'http://localhost/catalog/',
	async get(req, res, match) {
		const rules = await catalog.listGrammars();

		const rules_html = rules.map(function(v){
			return '          <li><a href="' + escapeHTML(`${v.name}.html`) +'">'+escapeHTML(v.name)+'</a></li>';
		}).join('\n');

		const main = [
			'<section class="container">',
			'	<h1>Index of Grammars</h1>',
			'	<ul>',
			rules_html,
			'	</ul>',
			'</section>',
			'',
		];

		res.setHeader('Content-Type', 'application/xhtml+xml');
		res.end(theme({ main }));
	},
});
