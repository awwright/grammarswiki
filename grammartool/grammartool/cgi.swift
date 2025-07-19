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

func cgi(arguments: Array<String>) -> Int32 {
	let requestURI = ProcessInfo.processInfo.environment["REQUEST_URI"] ?? "/"
	if requestURI == "/" { cgi_index_txt() }
	else if requestURI == "/status" { cgi_status_txt() }
	return 0;
}

func cgi_index_txt() {
	print("Content-Type: text/plain")
	print("")
	catalog_list(arguments: [arguments[0], "catalog-list", FileManager.default.currentDirectoryPath])
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
		.replacing("<", with: "&gt;")
}

func cgi_html(title: String, main_html: String) {
	let content =
		"""
		<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>\(text_html(title))</title></head><body>
			<h1>\(text_html(title))</h1>
			<main>\(main_html)</main>
		</body></html>\("\r\n")
		""".utf8
	print("Content-Type: application/xhtml+xml")
	print("Content-Length: \(content.count)")
	print("")
	print(content)
}
