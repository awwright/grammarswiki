"use strict";

const port = process.env.PORT || 8080;
const addr = '0.0.0.0';
const http = require('http');
const fs = require('fs');
const fp = require('fs').promises;
const { dirname } = require('path');

const { handleRequest } = require('./app.js');

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

getEnvironment().then(function (env) {
	const server = http.createServer(handleRequest.bind(env));

	// Listen on port 3000, IP defaults to 127.0.0.1
	server.listen(port, addr);

	// Put a friendly message on the terminal
	const addrstr = addr.toString().replace('0.0.0.0', 'localhost');
	console.log(`Server running at http://${addrstr}:${port}/`);
});
