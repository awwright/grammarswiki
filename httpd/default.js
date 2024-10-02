"use strict";

document.addEventListener("DOMContentLoaded", function (event) {
	// var appRoot = document.getElementById('script').getAttribute('src') + "";
	var input = document.getElementById('input');
	var results = document.getElementById('input-results');
	input.onchange = onInput;
	input.onkeypress = onInput;
	input.onkeyup = onInput;
	function onInput(e) {
		console.log(e);
		try {
			const result = parser.parse(input.value.replace(/\r?\n/g, '\r\n')+'\r\n');
			results.textContent = JSON.stringify(result, null, "\t");
		}catch(e){
			console.error(e);
			results.textContent = 'Error:\r\n'+(e.stack || e.toString());
		}
	}
});

