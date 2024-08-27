'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.ALPHA.html>

const fs = require('fs');
const fp = require('fs').promises;
const optimize = require('regexp-tree').optimize;
const { makeRoute } = require('./route.js');

const abnf = require('../lib/abnf.js');
const abnfcore = require('../lib/abnf-core.js');

function escapeHTML(v) {
	return v
		.replace(/&/g, '&amp;')
		.replace(/"/g, '&quot;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;');
};

module.exports = makeRoute({
	name: 'route_catalog_filename_rulename_html',
	uriTemplate: 'http://localhost/catalog/{filename}.{rulename}.html',
	async get(req, res, match) {

		const filename = decodeURIComponent(match.params.filename);
		const rulename = decodeURIComponent(match.params.rulename);

		var meta_data = null;
		try {
			const meta_filepath = __dirname + '/../catalog/' + filename + '.json';
			const meta_contents = await fp.readFile(meta_filepath, { encoding: 'UTF-8' });
			meta_data = meta_contents && JSON.parse(meta_contents);
		} catch(e){}

		const abnf_filepath = __dirname + '/../catalog/' + filename + '.abnf';
		const abnf_data = await fp.readFile(abnf_filepath, { encoding: 'UTF-8' });

		res.setHeader('Content-Type', 'application/xhtml+xml');

		const abnf_parsed = abnf.parse(abnf_data);
		abnf_parsed.rules.forEach(function (v) {
			v.source = abnf_filepath;
		});
		const corerules = Object.entries(abnfcore).map(([k, v]) => [k, v.alternation]);
		const rulemap = Object.fromEntries(corerules.concat(abnf_parsed.rules.map(v => [v.rulename, v.alternation])));

		const rulelist = abnf_parsed.rules.filter((f) => f.rulename === rulename);
		function scan_rulenames(node){
			switch (node.constructor.name) {
				case 'rule':
					return merge(node.alternation.elements.map(scan_rulenames));
				case 'alternation':
				case 'concatenation':
					return merge(node.elements.map(scan_rulenames));
				case 'repetition':
				case 'option':
				case 'group':
					return scan_rulenames(node.element);
				case 'rulename':
					return node.rulename;
				case 'char_val':
					return;
				default:
					console.dir(node);
					throw new Error(node.constructor.name);
			}
			function merge(setlist){
				if (setlist.length === 1) {
					return setlist[0];
				} else {
					const set = new Set;
					setlist.forEach(function (s) {
						if(s === undefined) return;
						else if(typeof s === 'string') set.add(s);
						else for (var v of s) set.add(v);
					});
					return set;
				}
			}
		}
		for(let i=0; i<rulelist.length; i++){

		}

		const rules_html = rulelist.map(function (rule) {
			const regexp = (function () {
				try {
					return rule.alternation.toRegExpStr(rulemap);
				} catch (e) {
					console.error(e.stack);
					return '';
					return e.stack;
				}
			})();
			const abnf = rule.toString();
			const js = rule.toInstanceString();
			// const regexpStr = optimize('/' + regexp + '/').toString();
			const regexpStr = ('/' + regexp + '/').toString();
			console.dir(rule.leaves());
			return `<section id="${escapeHTML(rule.rulename)}">`
				+ `<h2>${escapeHTML(rule.rulename)}</h2>`
				+ `<h3>Definition</h3>`
				+ `<cite>Exerpted from ...</cite>`
				+ `<pre>${escapeHTML(abnf)}</pre>`
				+ `<h3>ABNF</h3>`
				+ `<pre>${toHtml(rule)}</pre>`
				+ `<h3>ABNF tokens</h3>`
				+ `<ol>${rule.leaves().map(v => '<li>'+escapeHTML(v.toString())+'</li>').join('\n\t')}</ol>`
				+ `<h3>Regular Expression</h3>`
				+ `<pre>const ${escapeHTML(rule.rulename)} = ${escapeHTML(regexpStr)}</pre>`
				+ `<h3>Script literal</h3>`
				+ `<pre>const ${escapeHTML(rule.rulename)} = ${escapeHTML(js)}</pre>`
				// + `<pre>Referenced rules: ${[...scan_rulenames(rule)]}</pre>`
				+ `<h3>Referenced from</h3>`
				+ `<ul><li>File.Rulename</li></ul>`
				+ `<h3>Data</h3>`
				+ `<pre>${escapeHTML(JSON.stringify(meta_data, null, '\t'))}</pre>`
				+ `</section>`; 
		}).join('\n');

		function toHtml(node) {
			switch (node.constructor.name) {
				case 'rule':
					if (node.alternation.elements.length > 1) {
						return node.alternation.elements.map(element => `<div><b>${escapeHTML(node.rulename)}</b> /= ${toHtml(element)}</div>`).join('');
					}
					return `<b>${escapeHTML(node.rulename)}</b> = ${toHtml(node.alternation)}`
				case 'alternation':
					return node.elements.map(element => `${toHtml(element)}`).join(' / ');
				case 'concatenation':
					return node.elements.map(element => `${toHtml(element)}`).join(' ');
				case 'repetition':
					if (node.lower===1 && node.upper===1) return toHtml(node.element);
					const lowerStr = node.lower===0 ? '' : node.lower + '';
					const upperStr = node.upper===1/0 ? '' : node.upper + '';
					return `${escapeHTML(lowerStr)}*${escapeHTML(upperStr)}${toHtml(node.element)}`;
				case 'group':
					return `( ${toHtml(node.element)} )`;
				case 'option':
					return `[ ${toHtml(node.element)} ]`;
				case 'rulename':
					return `<a href="${escapeHTML(filename + '.' + node.rulename + '.html')}">${escapeHTML(node.rulename)}</a>`;
				// return `<a href="${escapeHTML('#'+node.rulename)}">${escapeHTML(node.rulename)}</a>`;
				case 'num_val':
				case 'char_val':
				case 'prose_val':
					return escapeHTML(node.toString());
				default:
					console.dir(node);
					return '!' + escapeHTML(node.constructor.name) + '!';
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
			'\t</head>',
			'\t<body class="pagewidth">',
			'\t\t<nav><a href="./">Grammars</a> / <a href="' + escapeHTML(filename + '.html') + '">' + escapeHTML(filename) +'</a> / </nav>',
			'\t\t<h1>' + escapeHTML(rulename) + '</h1>',
			'\t\t<main>' + rules_html + '</main>',
			// '\t\t<pre>' + data + '</pre>',
			'\t</body>',
			'</html>',
		].join('\r\n') + '\r\n';
		res.end(html);
	}
});
