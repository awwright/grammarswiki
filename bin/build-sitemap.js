const fs = require('fs').promises;
const path = require('path');

async function generateSitemap(dirPath) {
	async function readDirRecursive(currentPath, level = 1) {
		const entries = await fs.readdir(currentPath, { withFileTypes: true });
		let html = '<ul>';
		for (const entry of entries) {
			const fullPath = path.join(currentPath, entry.name);
			const relativePath = path.relative(process.cwd(), fullPath);
			
			if (entry.isDirectory()) {
				html += '\n' + '\t'.repeat(level + 1) + `<li>${entry.name}/` + await readDirRecursive(fullPath, level + 1) + '</li>';
			} else if (entry.name.endsWith('.html')) {
				html += '\n' + '\t'.repeat(level + 1) + `<li><a href="${relativePath}">${entry.name}</a></li>`;
			}
		}
		html += '</ul>';
		return html;
	}
	try {
		const sitemapContent = `<section>\n\t<h2>Sitemap</h2>\n\t${await readDirRecursive(dirPath)}\n</section>\n`;
		console.log(sitemapContent);
	} catch (err) {
		console.error('Error generating sitemap:', err);
	}
}

// Usage: node sitemap.js <directory_path>
const directoryPath = process.argv[2] || '.';
generateSitemap(directoryPath);
