#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const lunr = require('lunr');

function buildIndex(filePaths) {
	return lunr(function () {
		this.ref('filename');
		this.field('body');

		filePaths.forEach(filePath => {
			const content = fs.readFileSync(filePath, 'utf8');
			const text = (content.match(/<h1[^>]*>(.*?)<\/h1>/) || [])[1]
			if (!text) return;
			const filename = '/' + filePath;
			console.error(filename);
			//console.error(text);
			this.add({ filename, body: text });
		});
	});
}

const filePaths = process.argv.slice(2);

if (filePaths.length === 0) {
	console.error('Please provide file paths as arguments.');
	process.exit(1);
}

const index = buildIndex(filePaths);
const serializedIndex = JSON.stringify(index.toJSON(), null, 2);

console.log('const serializedIndex = ');
console.log(serializedIndex);
