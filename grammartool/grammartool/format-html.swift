import FSM;
import Foundation

func format_html_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("format-html"))");
	print("\tReformat the given HTML page into the website theme");
}

func format_html_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3
	else {
		catalog_list_help(arguments: arguments)
		return 1
	}
	let catalogPath = arguments[2];
	format_html_run(response: &stdout, directoryPath: catalogPath)
	return stdout.exitCode
}

func format_html_run(response res: inout some ResponseProtocol, directoryPath: String) {
	let contents: [String];
	res.contentType = "application/xhtml+xml"

	let html_data: Data?;
	if(arguments.count == 3){
		html_data = getInput(filename: arguments[2]);
	} else {
		html_data = getInput(filename: nil);
	}
	guard let html_data, let html = String(data: html_data, encoding: .utf8) else {
		print("No input");
		return;
	}

	// Extract title content
	let title_dirty = format_html_read_content(from: html, tag: "title")
	guard let title_dirty else {
		print("<title>: Not found")
		return;
	}
	let title = title_dirty
		.replacingOccurrences(of: "&lt;", with: "<")
		.replacingOccurrences(of: "&gt;", with: ">")
		.replacingOccurrences(of: "&amp;", with: "&")
		.replacingOccurrences(of: "&quot;", with: "\"")
		.replacingOccurrences(of: "Grammars.wiki", with: "")
		.replacingOccurrences(of: " - ", with: "")
		.replacingOccurrences(of: " : ", with: "")

	// Extract main content
	let main_html = format_html_read_content(from: html, tag: "main");
	guard let main_html else {
		print("<main>: Not found")
		return;
	}

	res.status = .ok
	respond_themed_html(res: &res, title: title, main_html: main_html)
}

func format_html_read_content(from html: String, tag: String) -> String? {
	// Create regex pattern for the tag, capturing content between opening and closing tags
	let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
	let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
	if let match = regex?.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)) {
		if let range = Range(match.range(at: 1), in: html) {
			 return String(html[range])
		}
	}
	return nil
}

