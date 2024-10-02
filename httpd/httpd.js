'use strict';

const port = process.env.PORT || 8080;
const addr = '0.0.0.0';
const http = require('http');
const fs = require('fs');
const fp = require('fs').promises;
const { dirname } = require('path');

// Welcome to my special fun project.
// Paths served here generally map to files found in ../catalog/
// But some website-specific files are found on ./

const dotenv = require('dotenv');
dotenv.config();

const querystring = require('querystring');
const { Router } = require('uri-template-router');
const { makeRoute, methods } = require('./route.js');

const docroot = __dirname + '/';
const catalogRoot = dirname(__dirname) + '/catalog/';
const cssPath = __dirname + '/default.css';
const htmlPath = __dirname + '/index.xhtml';

fs.readFileSync(cssPath);
fs.readFileSync(htmlPath);

function log(entry) {
	// fs.appendFileSync('/tmp/sample-app.log', new Date().toISOString() + ' - ' + entry + '\n');
	console.log(entry);
}

async function getEnvironment() {
	// Resolve an object that will be used as `this` in handleRequest
	const env = Object.create(process.env);
	return {
		docroot,
		catalogRoot,
		css: cssPath,
		html: htmlPath,
		log,
		env,
	};
}

const routeHealthcheck = makeRoute({
	name: 'route_healthcheck',
	uriTemplate: 'http://localhost/about:health',
	get(){
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
		staticfile('route_index.html', 'http://localhost/', htdocs + '/index.html', 'text/html'),  // <http://localhost/>
		routeHealthcheck,
		staticfile('route_theme_script', 'http://localhost/theme.js', __dirname+'/default.js', 'application/ecmascript'),
		staticfile('route_theme_style', 'http://localhost/theme.css', htdocs + '/scripts/css/style.css', 'text/css'),
		require('./route_search_html.js'), // <http://localhost/search.html{?q}>
		require('./route_search_js.js'), // <http://localhost/search.js>
		require('./route_search_json.js'), // <http://localhost/search.json>
		require('./route_catalog_index.js'), // <http://localhost/catalog/>
		require('./route_catalog_filename_abnf.js'), // <http://localhost/catalog/{filename}.abnf>
		require('./route_catalog_filename_html.js'), // <http://localhost/catalog/{filename}.html>
		require('./route_catalog_filename_antlr.js'),
		require('./route_catalog_filename_parserjs.js'),
		require('./route_catalog_filename_rulename_html.js'),
	].map(v => [router.addTemplate(v.uriTemplate), v])
);

getEnvironment().then(function (env) {
	const server = http.createServer(handleRequest.bind(env));

	// Listen on port 3000, IP defaults to 127.0.0.1
	server.listen(port, addr);

	// Put a friendly message on the terminal
	const addrstr = addr.toString().replace('0.0.0.0', 'localhost');
	console.log(`Server running at http://${addrstr}:${port}/`);
});

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
