"use strict";

module.exports.escapeHTML = escapeHTML;
function escapeHTML(v) {
	return v
		.replace(/&/g, '&amp;')
		.replace(/"/g, '&quot;')
		.replace(/>/g, '&gt;')
		.replace(/</g, '&lt;')
};

function toString(v){
	if(Array.isArray(v)) return v.map(w => w+'\r\n').join('');
	if(v===undefined) return '';
	return v.toString();
}

module.exports.theme = theme;
function theme(vars){
	const { title, head, main, body } = vars;
	return toString([
		'<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" version="XHTML+RDFa 1.0" dir="ltr">',
		'\t<head profile="http://www.w3.org/1999/xhtml/vocab">',
		'\t\t<meta http-equiv="Content-Type" content="application/xhtml+xml;charset=utf-8" />',
		'\t\t<meta name="viewport" content="width=device-width, initial-scale=1" />',
		'\t\t<meta property="http://purl.org/dc/terms/title" content="Welcome to Grammars.wiki" xmlns="http://www.w3.org/1999/xhtml" />',
		'\t\t<meta name="description" content="Grammars.wiki homepage" xmlns="http://www.w3.org/1999/xhtml" />',
		'\t\t<title>' + escapeHTML(toString(title)) + '</title>',
		'\t\t<link rel="stylesheet" href="/theme.css" />',
		'\t\t<script src="/theme.js" id="script" />',
		toString(head) + '\t</head>',
		'\t<body class="pagewidth">',
		'<header>',
		'	<div class="container v-align--grid col-2-auto">',
		'		<a id="logo" href="/">',
		'			<div class="large">Grammars.<span style="font-variant:small-caps">wiki</span></div> ',
		'			<div class="small">ABNF Toolchain &amp; Generator</div> ',
		'		</a>',
		'		<nav>',
		'			<ul id="menu">',
		'				<li><form action="/search.html" method="GET"><input type="search" name="q" /></form></li>',
		'				<li><a href="">About</a></li>',
		'				<li class="">',
		'					<a href="/catalog/">Catalog</a>',
		'				</li>',
		'				<li class="category">',
		'					<a href="generator.html">Toolchain</a>',
		'					<ul class="dropdown">',
		'						<li><a href="test-cases.html"><li>Test Cases</li></a></li>',
		'					</ul>',
		'				</li>',
		'			</ul>',
		'		</nav>',
		'	</div>',
		'</header>',
		'\t\t<main>',
		toString(main) + '\t\t</main>',
		toString(body) + '\t</body>',
		'</html>',
	]);
}
