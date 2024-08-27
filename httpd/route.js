"use strict";

class Method {
	constructor(name, opts){
		this.name = name;
		this.exists = opts.exists;
	}
}

const methods = {
	GET: new Method('GET', {exists: true}),
};

module.exports.methods = methods;
module.exports.makeRoute = makeRoute;

function makeRoute(options) {
	const route = async function (req, res, match) {
		const method = methods[req.method];
		if (options.exists && method.exists) {
			const exists = await options.exists.call(this, req);
			if (exists === undefined) {
				req.statusCode = 404;
				res.setHeader('Content-Type', 'text/plain');
				res.end('Not found: ' + req.path + '\r\n');
				return;
			}
		}
		if (options.get && (req.method === 'GET' || req.method === 'HEAD')) {
			try {
				await options.get.call(this, req, res, match);
			} catch (e) {
				console.dir(e);
			}
		} else if (options.post && (req.method === 'POST')) {
			try {
				await options.post.call(this, req, res, match);
			} catch (e) {
				console.dir(e);
			}
		} else {
			if (options.methodNotFound) {
				return options.methodNotFound.call(this, req, res, match);
			}
			const allow = [];
			if (options.get) allow.push('GET');
			if (options.get) allow.push('HEAD');
			if (options.post) allow.push('POST');
			req.statusCode = 405;
			res.setHeader('Content-Type', 'text/plain');
			res.setHeader('Allow', allow.join(', '));
			res.end('Methods allowed: ' + allow.join(', ') + '\r\n');
		}
	}
	route.uriTemplate = options.uriTemplate;
	return route;
}
