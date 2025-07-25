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
	let main_html = "<pre><code>\(text_html(importedAbnfString))</code></pre>"
	res.status = .ok
	respond_themed_html(res: &res, title: title, main_html: main_html);
}
