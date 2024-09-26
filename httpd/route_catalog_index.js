'use strict';
// <http://localhost:8080/catalog/>

const fp = require('fs').promises;
const { makeRoute } = require('./route.js');

function escapeHTML(v) {
	return v
		.replace(/&/g, '&amp;')
		.replace(/"/g, '&quot;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;');
};

module.exports = makeRoute({
	uriTemplate: 'http://localhost/catalog/',
	async get(req, res, match) {
		const rules = await catalog.listGrammars();
		const rules_html = rules.map(function(v){
			return '          <li><a href="' + escapeHTML(`${v.name}.html`) +'">'+escapeHTML(v.name)+'</a></li>';
		}).join('\n');

		const html = [
			'<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" version="XHTML+RDFa 1.0" dir="ltr">',
			'       <head profile="http://www.w3.org/1999/xhtml/vocab">',
			'               <meta http-equiv="Content-Type" content="application/xhtml+xml;charset=utf-8" />',
			'               <meta name="viewport" content="width=device-width, initial-scale=1" />',
			'               <meta property="http://purl.org/dc/terms/title" content="Welcome to Grammars.wiki" xmlns="http://www.w3.org/1999/xhtml" />',
			'               <meta name="description" content="Grammars.wiki homepage" xmlns="http://www.w3.org/1999/xhtml" />',
			'               <title>Grammar Catalog</title>',
			'               <link rel="stylesheet" href="/default.css" />',
			'       </head>',
			'       <body class="pagewidth">',
			'       <h1>Index of Grammars</h1>',
			'       <ul>' + rules_html,
			'       </ul>',
			'       </body>',
			'</html>',
			'',
		].join('\r\n');

		res.setHeader('Content-Type', 'application/xhtml+xml');
		res.end(html);
	}
});
