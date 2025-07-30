'use strict';
const fs = require('fs');

// Welcome to my special fun project.
// Paths served here generally map to files found in ../catalog/
// But some website-specific files are found on ./

const dotenv = require('dotenv');
dotenv.config();

const { Router } = require('uri-template-router');
const { makeRoute, methods } = require('./route.js');

const { routeIndexHtml } = require('./route_index_html.js');

const routeHealthcheck = makeRoute({
	name: 'route_healthcheck',
	uriTemplate: 'http://localhost/about:health',
	get() {
		res.setHeader('Content-Type', 'text/plain');
		res.end('200 OK\r\n');
	},
});

function staticfile(name, uri, filepath, ct){
	return makeRoute({
		name: name,
		uriTemplate: uri,
		get(req, res, match) {
			const content = fs.readFileSync(filepath);
			res.setHeader('Content-Type', ct);
			res.end(content);
		},
		async* enumerate(){
			yield {uri};
		},
	});
}

const htdocs = __dirname + '/../htdocs';

const router = new Router;
const routeMap = new Map(
	[
		routeIndexHtml, // <http://localhost/>
		routeHealthcheck, // <http://localhost/about:health>
		staticfile('route_theme_script', 'http://localhost/theme.js', __dirname+'/default.js', 'application/ecmascript'),
		staticfile('route_theme_style', 'http://localhost/theme.css', htdocs + '/scripts/css/style.css', 'text/css'),
		staticfile('route_scripts/css/style.css', 'http://localhost/scripts/css/style.css', htdocs + '/scripts/css/style.css', 'text/css'),
		staticfile('route_scripts/javascript/developer/debug-overflow.js', 'http://localhost/scripts/javascript/developer/debug-overflow.js', __dirname +'/../htdocs/scripts/javascript/developer/debug-overflow.js', 'text/css'),
		staticfile('route_content/images/placeholder.png', 'http://localhost/content/images/placeholder.png', __dirname +'/../htdocs/content/images/placeholder.png', 'image/png'),
		staticfile('route_content/images/icon/magnifying-glass.svg', 'http://localhost/content/images/icon/magnifying-glass.svg', __dirname +'/../htdocs/content/images/icon/magnifying-glass.svg', 'image/svg'),
		require('./route_search_html.js'), // <http://localhost/search.html{?q}>
		require('./route_search_js.js'), // <http://localhost/search.js>
		require('./route_search_json.js'), // <http://localhost/search.json>
		require('./route_catalog_index.js'), // <http://localhost/catalog/>
		require('./route_catalog_filename_abnf.js'), // <http://localhost/catalog/{filename}.abnf>
		require('./route_catalog_filename_peg.js'), // <http://localhost/catalog/{filename}.peg>
		require('./route_catalog_filename_html.js'), // <http://localhost/catalog/{filename}.html>
		require('./route_catalog_filename_antlr.js'),
		require('./route_catalog_filename_parserjs.js'),
		require('./route_catalog_filename_rulename_html.js'),
	].map(v => [router.addTemplate(v.uriTemplate), v])
);

function handleRequest(req, res) {
	// const { html, log } = this;
	console.log(req.method + ' ' + req.url);

	const method = methods[req.method];
	if (method === undefined) {
		req.statusCode = 501;
		res.setHeader('Content-Type', 'text/plain');
		res.setHeader('Allow', 'text/plain');
		res.end('Method not understood.');
		return;
	}

	const match = router.resolveURI('http://localhost'+req.url);
	if (match && routeMap.has(match.route)) {
		const end = routeMap.get(match.route).call(this, req, res, match);
		if (end) end.then(function () {
			// Check that response is finished
		});
		return;
	}

	res.statusCode = 404;
	res.setHeader('Content-Type', 'text/plain');
	res.end('404 Not Found for <' + req.url + '>\r\n');
	console.log(req.method + ' ' + req.url + ' 404 (Not Found)');
}

module.exports.handleRequest = handleRequest;
module.exports.router = router;
module.exports.routeMap = routeMap;
