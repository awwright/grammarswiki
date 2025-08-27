document.addEventListener('DOMContentLoaded', function () {
	const idx = lunr.Index.load(serializedIndex);
	const urlParams = new URLSearchParams(window.location.search);
	const q = urlParams.get('q');
	const eResults = document.getElementById('results')
	document.getElementById('search').value = q;
	if (q) {
		const results = idx.search(q);
		eResults.innerHTML = '';
		const list = document.createElement('ul');
		results.forEach(result => {
			const item = document.createElement('li');
			const link = document.createElement('a');
			link.textContent = result.ref;
			link.href = result.ref;
			item.appendChild(link);
			list.appendChild(item);
		});
		if (results.length) {
			eResults.appendChild(list);
		} else {
			eResults.textContent = 'No results.';
		}
	} else {
		eResults.textContent = 'No search query provided. (looking for ?q={query})';
	}
});
