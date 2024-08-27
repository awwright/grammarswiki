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
		log
	};
}

const routeIndex = makeRoute({
	name: 'route_index',
	uriTemplate: 'http://localhost/',
	get(req, res, match){
		const html = fs.readFileSync(this.html);
		res.setHeader('Content-Type', 'application/xhtml+xml');
		res.end(html);
	},
});

const routeHealthcheck = makeRoute({
	name: 'route_healthcheck',
	uriTemplate: 'http://localhost/about:health',
	get(){
		res.setHeader('Content-Type', 'text/plain');
		res.end('200 OK\r\n');
	},
});

const routeStyle = makeRoute({
	name: 'route_style',
	uriTemplate: 'http://localhost/default.css',
	get(req, res, match){
		const css = fs.readFileSync(this.css);
		res.setHeader('Content-Type', 'text/css');
		res.end(css);
	},
});

function file(name, uri, file, ct){
	return makeRoute({
		name: name,
		uriTemplate: uri,
		get(req, res, match) {
			const content = fs.readFileSync(file);
			res.setHeader('Content-Type', ct);
			res.end(content);
		},
	});
}

const router = new Router;
const routeMap = new Map(
	[
		routeIndex,
		routeHealthcheck,
		routeStyle,
		file('route_default_script', 'http://localhost/default.js', __dirname+'/default.js', 'application/ecmascript'),
		require('./route_catalog_index.js'),
		require('./route_catalog_filename_abnf.js'),
		require('./route_catalog_filename_html.js'),
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
	console.log('Server running at http://' + addr + ':' + port + '/');
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



