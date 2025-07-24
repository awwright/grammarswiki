import FSM;
import Foundation

func index_html_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("index-html"))");
	print("\tGenerate the website front page");
}

func index_html_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3 else {
		catalog_list_help(arguments: arguments)
		return 1
	}
	let catalogPath = arguments[2];
	index_html_run(response: &stdout, directoryPath: catalogPath)
	return stdout.exitCode
}

func index_html_run(response res: inout some ResponseProtocol, directoryPath: String) {
	let contents: [String];
	res.contentType = "application/xhtml+xml"
	do {
		contents = try FileManager.default.contentsOfDirectory(atPath: directoryPath).filter { !$0.hasPrefix(".") && $0.hasSuffix(".abnf") }
	} catch {
		res.writeLn(text_html(String(describing: error)))
		contents = []
		res.status = .error
		return
	}

	let title = "Index"
	let content =
		"""
		<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>\(text_html(title))</title></head><body>
		<h1>\(text_html(title))</h1>
		<main><ul>\(contents.map { "<li>\(text_html($0))</li>\n" }.joined())</ul></main>
		</body></html>\("\r\n")
		"""
	res.writeLn(content)
}
