import FSM;
import Foundation

func index_html_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("index-html"))");
	print("\tGenerate the website front page");
}

func index_html_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3
	else {
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
		contents = []
		res.status = .error
		res.contentType = "text/plain"
		res.writeLn("Internal Server Error:")
		res.writeLn(text_html(String(describing: error)))
		res.end()
		return
	}

	let title = "Index"
	let main_html = "<ul>\(contents.map { "<li><a href=\"catalog/\(text_html($0.replacingOccurrences(of: ".abnf", with: ".html")))\">\(text_html($0))</a></li>\n" }.joined())</ul>"
	res.status = .ok
	respond_themed_html(res: &res, title: title, main_html: main_html)
}
