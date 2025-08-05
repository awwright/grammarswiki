'use strict';
// e.g. <http://localhost:8080/catalog/abnf-core.html>

const { makeRoute } = require('./route.js');
const { theme, escapeHTML } = require('./theme.js');

const routeIndexHtml = makeRoute({
	name: 'route_index_html',
	uriTemplate: 'http://localhost/',
	async get(req, res, match) {
		const query = decodeURIComponent(match.params.q);
		if (typeof query !== 'string' || query.length === 0) {
			res.setHeader('Content-Type', 'text/plain');
			res.end('Expected a query string');
			return;
		}

		const title = 'Welcome to Grammars.wiki';
		const main = [
            '<p>A Comprehensive Resource on File Formats, Protocols, and Internet Specifications</p>',
            '<p>Grammars.wiki is your ultimate guide to understanding, implementing, and working with the complex specifications that',
            'drive modern web development and internet standards. Our mission is to provide in-depth analysis and tools for',
            'implementors, specification authors, and developers, while also being a friendly entry point for those new to formal',
            'grammars and technical standards.</p>',
            '<h2>Why Grammars Matter</h2>',
            '<p>Formal grammars and technical specifications are the foundation of how computers communicate and interpret data.',
            'Understanding these rules enables you to:</p>',
            '<ul>',
            '    <li>Create reliable applications that interact seamlessly with other systems.</li>',
            '    <li>Ensure compliance with the latest web and network protocols.</li>',
            '    <li>Troubleshoot parsing errors or compatibility issues in real-world implementations.</li>',
            '    <li>Contribute to the evolution of the standards themselves by identifying edge cases, ambiguities, or implementation',
            'difficulties.</li>',
            '</ul>',
            '<h2>For Web Developers</h2>',
            '<p>Grammars.wiki is built to be the most detailed and accurate source of technical information on formal grammars, file formats, and protocols. We break down dense, technical specifications and provide tools that make implementing and understanding these standards easier for everyone—from novice developers to expert engineers.</p>',
            '<p>Grammars.wiki makes complex standards accessible, providing step-by-step guidance and context for those unfamiliar with the inner workings of file formats and Internet protocols. We also help you build the foundational knowledge needed to understand and read official specifications, bridging the gap between raw technical details and practical implementation..</p>',
            '<h2>For Implementors and Specification Authors</h2>',
            '<p>Implementing a specification or writing a new one can be a complex task. Grammars.wiki serves as both',
            'a reference and a tool for creating new parsers and implementations of existing standards. Authors can use these detailed',
            'analysis and tooling to ensure that their specifications are not only precise but also easily implementable.</p>',
            '<p>At the same time, if you\'re responsible for an existing implementation, this website offers testing resources to help you',
            'validate conformance to the latest standards, ensuring that your software behaves reliably and consistently across',
            'different environments.</p>',
            '<h2>What you\'ll find</h2>',
            '<ul>',
            '    <li>Documentation: Learn about the formal grammars that define everything from programming languages to',
            '        markup languages. We provide real-world examples so you can apply these rules to your own work, whether you\'re',
            '        writing code that parses a document or sending a network request.</li>',
            '    <li>Parsers: If you\'re writing an implementation of one of the grammars, Grammars.wiki provides tools to translate the official definition into languages native to your programming environment.</li>',
            '    <li>Testing: Grammars.wiki provides comprehensive positive and negative tests</li>',
            '    <li>Interactive Examples: Try out interactive examples and explore live code snippets to see these formats and',
            '        protocols in action. You\'ll get hands-on experience without having to piece together scattered information from',
            '        multiple sources.</li>',
            '</ul>',

			'<ul>',
			// '<li></li>',
			'</ul>',
		];

		res.setHeader('Content-Type', 'application/xhtml+xml');
		res.end(theme({ title, main }));
	},
});

module.exports.routeIndexHtml = routeIndexHtml;
