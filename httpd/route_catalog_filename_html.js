'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.html>

const fs = require('fs');
const fp = require('fs').promises;

const abnf = require('../lib/abnf.js');
const abnfcore = require('../lib/abnf-core.js');
const { makeRoute } = require('./route.js');

function escapeHTML(v) {
	return v
		.replace(/&/g, '&amp;')
		.replace(/"/g, '&quot;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;');
};

module.exports = makeRoute({
	name: 'route_catalog_filename_html',
	uriTemplate: 'http://localhost/catalog/{filename}.html',
	async get(req, res, match) {
		const filename = decodeURIComponent(match.params.filename);
		const filepath = __dirname + '/../catalog/' + filename + '.abnf';
		const abnf_data = await fp.readFile(filepath, {encoding: 'UTF-8'});
		const md_data = await fp.readFile(__dirname + '/../catalog/' + filename + '.abnf', {encoding: 'UTF-8'});

		res.setHeader('Content-Type', 'application/xhtml+xml');

		const rulelist = abnf.parse(abnf_data);
		rulelist.rules.forEach(function(v){
			v.source = filepath;
		});
		const corerules = Object.entries(abnfcore).map(([k, v]) => [k, v.alternation]);
		const rulemap = Object.fromEntries(corerules.concat(rulelist.rules.map(v => [v.rulename, v.alternation])));
		const rules_html = rulelist.rules.map(function (rule) {
			const regexp = (function () {
				try {
					return rule.alternation.toRegExpStr(rulemap);
				} catch (e) {
					return '';
					return e.stack;
				}
			})();
			const abnf = rule.toString();
			const js = rule.toInstanceString();
			return `<section id="${escapeHTML(rule.rulename)}">`
				// + `<h2><a href="${escapeHTML(filename + '.' + rule.rulename + '.html')}">${escapeHTML(rule.rulename)}</a></h2>`
				+ ``
				// + `<pre>${escapeHTML(abnf)}</pre>`
				// + `<pre>const ${escapeHTML(rule.rulename)} = /${escapeHTML(regexp)}/</pre>`
				// + `<pre>const ${escapeHTML(rule.rulename)} = ${escapeHTML(js)}</pre>`
				+ `<pre>${toHtml(rule)}</pre>`
				+ `</section>`;
		}).join('\n');

		function toHtml(node){
			switch(node.constructor.name){
				case 'rule':
					if(node.alternation.elements.length > 1){
						return node.alternation.elements.map(function(element, i){
							if (i === 0) return `<div><b><a href="${escapeHTML(filename + '.' + node.rulename + '.html')}">${escapeHTML(node.rulename)}</a></b> /= ${toHtml(element)}</div>`;
							else return `<div><b>${escapeHTML(node.rulename)}</b> /= ${toHtml(element)}</div>`;
						}).join(''); 
					}
					// return `<b>${escapeHTML(node.rulename)}</b> = ${toHtml(node.alternation)}`
					return `<b class="abnf-rulename"><a href="${escapeHTML(filename + '.' + node.rulename + '.html')}">${escapeHTML(node.rulename)}</a></b><span class="abnf-definedas"> = </span>${toHtml(node.alternation)}`
				case 'alternation':
					return '<span class="alternation">' + node.elements.map(element => `${toHtml(element)}`).join(' / ') + '</span>';
				case 'concatenation':
					return '<span class="concatenation">' + node.elements.map(element => `${toHtml(element)}`).join(' ') + '</span>';
				case 'repetition':
					if (node.lower === 1 && node.upper === 1) {
						return `<span class="abnf-repetition">${toHtml(node.element)}</span>`;
					}
					const lower = (node.lower === 0 ? '' : node.lower);
					const upper = (node.upper === 1/0 ? '' : node.upper);
					return `<span class="abnf-repetition">${lower}*${upper}${toHtml(node.element)}</span>`;

				case 'group':
					return `<span class="abnf-group">( ${toHtml(node.element)} )</span>`;
				case 'option':
					return `<span class="abnf-option">[ ${toHtml(node.element)} ]</span>`;
				case 'rulename':
					return `<a href="${escapeHTML(filename+'.'+node.rulename+'.html')}">${escapeHTML(node.rulename)}</a>`;
					// return `<a href="${escapeHTML('#'+node.rulename)}">${escapeHTML(node.rulename)}</a>`;
				case 'num_val':
				case 'char_val':
				case 'prose_val':
					return '<span class="abnf-val">' + escapeHTML(node.toString()) + '</span>';
				default:
					console.dir(node);
					return '<Unknown node ' + escapeHTML(node.constructor.name) + ' = ' + escapeHTML(node.toString()) + '>';
			}
		}

		const html = [
			'<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" version="XHTML+RDFa 1.0" dir="ltr">',
			'\t<head profile="http://www.w3.org/1999/xhtml/vocab">',
			'\t\t<meta http-equiv="Content-Type" content="application/xhtml+xml;charset=utf-8" />',
			'\t\t<meta name="viewport" content="width=device-width, initial-scale=1" />',
			'\t\t<meta property="http://purl.org/dc/terms/title" content="Welcome to Grammars.wiki" xmlns="http://www.w3.org/1999/xhtml" />',
			'\t\t<meta name="description" content="Grammars.wiki homepage" xmlns="http://www.w3.org/1999/xhtml" />',
			'\t\t<title>' + escapeHTML(filename) + '</title>',
			'\t\t<link rel="stylesheet" href="/default.css" />',
			'\t\t<script src="/default.js" id="script" />',
			'\t\t<script src="' + escapeHTML(filename) +'.parser.js" />',
			'\t</head>',
			'\t<body class="pagewidth">',
			'\t\t<nav><a href="./">Grammars</a> /</nav>',
			'\t\t\t<h1>' + escapeHTML(filename) + '</h1>',
			'\t\t<main><pre>' + escapeHTML(md_data) + '</pre>' + rules_html + '</main>',
			// '\t\t<pre>' + data + '</pre>',
			'\t\t<textarea id="input"></textarea>',
			'\t\t<pre id="input-results"></pre>',
			'\t</body>',
			'</html>',
		].join('\r\n') + '\r\n';
		res.end(html);
	},
});
