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
				grammar_abnf_html_run(response: &res, filePath: catalog + "/" + components[2].replacingOccurrences(of: ".xhtml", with: ".abnf"))
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
		.replacingOccurrences(of: "&", with: "&amp;")
		.replacingOccurrences(of: "\"", with: "&quot;")
		.replacingOccurrences(of: "<", with: "&lt;")
}

func respond_themed_html(res: inout some ResponseProtocol, title: String, main_html: String) {
	let content =
"""
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
  <title>\(text_html(title)) - Standard Grammar Catalog</title>
  <meta name="description" content=""/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <!-- <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css"> -->
  <!-- https://fonts.google.com/specimen/Open+Sans -->
  <link rel="preconnect" href="https://fonts.googleapis.com"/>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin=""/>
  <link href="\(text_html("https://fonts.googleapis.com/css2?family=Open+Sans:ital,wght@0,300..800;1,300..800&display=swap"))" rel="stylesheet"/>
  <link rel="stylesheet" href="/scripts/css/style.css"/>
</head>
<body>
  <header>
	 <section class="v-align--grid col-2-auto">
	 <a id="logo" href="/">
		<div class="large">Standard Grammar Catalog</div>
		<div class="small">ABNF Toolchain &amp; Generator</div>
	 </a>

	 <nav>
		<input id="toggle--state" type="checkbox"/>
		<label id="toggle" for="toggle--state">
		  <span></span>
		  <span></span>
		  <span></span>
		</label>

		<ul id="menu">
		  <form class="filter-menu filter-menu--quick-search pointer" method="get">
		  <label for="search" hidden="">Search</label>
		  <input type="text" name="search"/>
		  <input class="icon icon__search icon--border--left" type="submit" name="search" value=""/>
		  </form>

		  <li><a href="/index.html">About</a></li>
		  <li class="category">
		  <a href="catalog.html">Catalog</a>
		  <ul class="dropdown">
			 <a href="grammars-and-formats.html"><li>Grammars and Formats</li></a>
			 <a href="handbook.html"><li>Handbook</li></a>
		  </ul>
		  </li>

		  <li><a href="test-cases.html">Test Cases</a></li>
		</ul>
	 </nav>
	 </section>
  </header>

  <main>\(main_html)</main>

  <footer>
	 <section class="col-4">
	 <span></span>
	 <span></span>
	 <span></span>
	 <span></span>
	 </section>
  </footer>
</body>
</html>
""";

	res.contentType = "application/xhtml+xml"
	res.writeLn(content)
	res.end()
}
