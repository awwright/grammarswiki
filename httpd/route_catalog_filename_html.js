'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.html>

const fs = require('fs');
const fp = require('fs').promises;

const abnf = require('../lib/abnf.js');
const abnfcore = require('../lib/abnf-core.js');
const { makeRoute } = require('./route.js');
const { theme, escapeHTML } = require('./theme.js');

module.exports = makeRoute({
	name: 'route_catalog_filename_html',
	uriTemplate: 'http://localhost/catalog/{filename}.html',
	async get(req, res, match) {
		const filename = decodeURIComponent(match.params.filename);
		const filepath = __dirname + '/../catalog/' + filename + '.abnf';
		try {
			var abnf_data = await fp.readFile(filepath, {encoding: 'UTF-8'});
			var md_data = await fp.readFile(__dirname + '/../catalog/' + filename + '.abnf', {encoding: 'UTF-8'});
		} catch(e) {
			if (e.code === 'ENOENT'){
				res.statusCode = 404;
				res.setHeader('Content-Type', 'text/plain');
				res.end('Not Found\r\n');
				return;
			}
		}

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
					return escapeHTML('Unknown node ' + node.constructor.name + ' = ' + node.toString() + ']');
			}
		}

		const head = [
			'\t\t<script src="' + escapeHTML(filename) +'.parser.js" />\r\n',
		];

		const main = [
			'<section class="container">',
			'\t\t<h1>Rule ' + escapeHTML(filename) + '</h1>',
			'\t\t<pre>' + escapeHTML(md_data) + '</pre>' + rules_html,
			// '\t\t<pre>' + data + '</pre>',
			'\t\t<select id="input-lines"><option>CRLF terminated</option><option>LF terminated</option><option>LF separated</option></select>',
			'\t\t<textarea id="input"></textarea>',
			'\t\t<pre id="input-results"></pre>',
			'</section>',
		];

		res.setHeader('Content-Type', 'application/xhtml+xml');
		res.end(theme({head, main}));
	},
});
