import FSM;
import Foundation

func grammar_abnf_html_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("grammar-abnf-html")) <file.abnf>");
	print("\tGernerate HTML page about the given grammar file");
}

func grammar_abnf_html_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3 else {
		catalog_list_help(arguments: arguments)
		return 1
	}
	let catalogPath = arguments[2];
	grammar_abnf_html_run(response: &stdout, filePath: catalogPath)
	return stdout.exitCode
}

func grammar_abnf_html_run(response res: inout some ResponseProtocol, filePath: String) {
	let contents: [String];
	res.contentType = "application/xhtml+xml"

	let importedAbnf: Data? = getInput(filename: filePath);

	guard let importedAbnf else {
		res.status = .notFound
		res.end()
		return
	}
	guard let importedAbnfString = String(data: importedAbnf, encoding: .utf8) else {
		res.status = .notFound
		res.end()
		return
	}

	let title = "Contents of \(filePath)"
	let content =
		"""
		<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>\(text_html(title))</title></head><body>
		<h1>\(text_html(title))</h1>
		<main><pre><code>\(text_html(importedAbnfString))</code></pre></main>
		</body></html>
		"""
	res.writeLn(content)
}
