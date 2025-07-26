import Foundation

// This can be used with an httpd.conf as simple as:
//
// LoadModule cgi_module libexec/apache2/mod_cgi.so
// <Directory "/">
// Require all granted
// </Directory>
// ScriptAliasMatch ^/ /usr/local/bin/grammartool

func cgi_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("cgi")) [catalog]");
	print("\tA CGI program for serving a website, reading from <catalog> if provided, or else $CWD/catalog");
}

struct CGIResponse: ResponseProtocol {
	var status: ResponseStatus

	var contentType: String

	var sentHeaders = false;

	mutating func writeHeaders() {
		sentHeaders = true;
		print("Content-Type: \(contentType)\r\n")
		switch status {
			case .ok: print("Status: 200 OK\r\n")
			case .notFound: print("Status: 404 Not Found\r\n")
			default: print("Status: 400 Client Error\r\n")
		}
		print("\r\n")
	}

	mutating func write(_ part: Array<UInt8>) {
		if(sentHeaders == false) {
			writeHeaders();
		}
		print(part, terminator: "")
	}

	mutating func writeLn(_ part: String) {
		if(sentHeaders == false) {
			writeHeaders();
		}
		print(part)
	}

	func end() {
		// No-op
	}
}

func cgi(arguments: Array<String>) -> Int32 {
	let requestURI = ProcessInfo.processInfo.environment["REQUEST_URI"] ?? "/"
	if requestURI == "/" { cgi_index_txt() }
	else if requestURI == "/status" { cgi_status_txt() }
	//else if let filepath = try! #/\/(.+)\.abnf/#.firstMatch(in: requestURI)?.1 { cgi_abnf_txt(filepath: String(filepath)) }
	return 0;
}

func cgi_route(res: inout some ResponseProtocol, method: String, pathinfo: String, querystring: String) {
	let catalog = FileManager.default.currentDirectoryPath + "/catalog";
	print("cgi_route", method, pathinfo, querystring);

	guard method == "GET" else {
		res.status = .error
		res.contentType = "text/plain"
		res.writeLn("Method not allowed: \(method)")
		res.end()
		return;
	}

	print(pathinfo)
	let components = pathinfo.split(separator: "/", omittingEmptySubsequences: false)
	print(components)
	guard components.count >= 1 && components.first == "" else {
		res.status = .error
		res.contentType = "text/plain"
		res.writeLn("Syntax error")
		res.end()
		return;
	}
	switch components[1] {
		case "":
			index_html_run(response: &res, directoryPath: catalog)
		case "index.html":
			index_html_run(response: &res, directoryPath: catalog)
		case "catalog":
			if components.count == 2 {
				respond_not_found(res: &res)
			} else if components.count == 3 {
				grammar_abnf_html_run(response: &res, filePath: catalog + "/" + components[2].replacing(".xhtml", with: ".abnf"))
			} else {
				respond_not_found(res: &res)
			}
		default:
			respond_not_found(res: &res)
	}
}

func respond_not_found(res: inout some ResponseProtocol) {
	res.status = .notFound
	res.contentType = "text/plain"
	res.writeLn("Not found")
	res.end()
}

func cgi_index_txt() {
	print("Content-Type: text/plain")
	print("")
	catalog_list_args(arguments: [arguments[0], "catalog-list", FileManager.default.currentDirectoryPath])
}

func cgi_status_txt() {
	print("Content-Type: text/plain")
	print("")
	print("CWD: \(FileManager.default.currentDirectoryPath)")
	// Iterate through and print every environment variable
	for (key, value) in ProcessInfo.processInfo.environment {
		print("\(key): \(value)")
	}
}

func cgi_not_found_txt() {
	print("Status: 404 Not Found")
	print("Content-Type: text/plain")
	print("")
	print("No match for \(ProcessInfo.processInfo.environment["REQUEST_URI"] ?? "")")
}

func text_html(_ text: String) -> String {
	return text
		.replacing("&", with: "&amp;")
		.replacing("\"", with: "&quot;")
		.replacing("<", with: "&lt;")
}

func respond_themed_html(res: inout some ResponseProtocol, title: String, main_html: String) {
	let content =
		"""
		<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>\(text_html(title))</title></head><body>
			<h1>\(text_html(title))</h1>
			<main>\(main_html)</main>
		</body></html>
		"""
	res.contentType = "application/xhtml+xml"
	res.writeLn(content)
	res.end()
}
