import Foundation

func httpd_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("httpd")) [--port=<port>]");
	print("\tStart an HTTP server, hosting a website of the grammar catalog");
}

struct HTTPResponse: ResponseProtocol {
	var status: ResponseStatus
	var contentType: String

	var sentHeaders = false;
	var closed = false;
	let clientSocket: Int32;

	mutating func writeHeaders() {
		sentHeaders = true;
		switch status {
			case .ok: writeLn("HTTP/1.1 200 OK")
			case .notFound: writeLn("HTTP/1.1 404 Not Found")
			default: writeLn("HTTP/1.1 400 Client Error")
		}
		writeLn("Content-Type: \(contentType)")
		writeLn("")
	}

	mutating func write(_ responseData: Array<UInt8>) {
		if(sentHeaders == false) {
			writeHeaders();
		}
		responseData.withUnsafeBytes { ptr in
			_ = Foundation.write(clientSocket, ptr.baseAddress, responseData.count)
		}
	}

	mutating func writeLn(_ part: String) {
		if(sentHeaders == false) {
			writeHeaders();
		}
		let responseData = (part+"\r\n").data(using: .utf8)!
		responseData.withUnsafeBytes { ptr in
			_ = Foundation.write(clientSocket, ptr.baseAddress, responseData.count)
		}
	}

	mutating func end() {
		if(sentHeaders == false) {
			writeHeaders();
		}
		close(clientSocket)
		closed = true
	}
}

func httpd_args(arguments: Array<String>) -> Int32 {
	var port = 8080;
	for arg in arguments {
		if arg.count > 7 && arg[arg.startIndex..<arg.index(arg.startIndex, offsetBy: 7)] == "--port=" {
			port = Int(String(arg[arg.index(arg.startIndex, offsetBy: 7)...]))!
		}
	}

	httpd_listen(port: port)
	return 1;
}

func httpd_listen(port: Int = 8080) {
	let sock = socket(AF_INET, SOCK_STREAM, 0)
	guard sock >= 0 else { fatalError("Socket creation failed") }

	// Allow port reuse
	var reuse = 1
	setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size))

	// Set up server address
	var serverAddr = sockaddr_in()
	serverAddr.sin_family = sa_family_t(AF_INET)
	serverAddr.sin_addr.s_addr = INADDR_ANY
	serverAddr.sin_port = in_port_t(port).bigEndian

	// Bind socket
	guard bind(sock, sockaddr_cast(&serverAddr), socklen_t(MemoryLayout<sockaddr_in>.size)) >= 0 else {
		fatalError("Bind failed")
	}

	// Listen for connections
	guard listen(sock, 5) >= 0 else { fatalError("Listen failed") }

	print("Server running at <http://localhost:\(port)/>")

	while true {
		// Accept client connection
		var clientAddr = sockaddr_in()
		var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
		let clientSocket = accept(sock, sockaddr_cast(&clientAddr), &clientAddrLen)
		guard clientSocket >= 0 else { continue }

		var response = HTTPResponse(status: .error, contentType: "application/octet-stream", clientSocket: clientSocket)

		// Read request
		var buffer = Array<UInt8>(repeating: 0, count: 1024)
		let bytesRead = read(clientSocket, &buffer, 1024)
		guard bytesRead > 0 else {
			close(clientSocket)
			continue
		}

		// Parse request (basic GET request handling)
		let request = String(bytes: buffer, encoding: .utf8) ?? ""
		let lines = request.split(separator: "\r\n")
		guard let requestLine = lines.first?.split(separator: " "),
				requestLine.count == 3,
				requestLine[0] == "GET"
		else {
			response.status = .error;
			response.writeLn("Unknown method or request line")
			response.end()
			continue
		}
		let method = String(requestLine[0])
		let requestPath = String(requestLine[1])
		cgi_route(res: &response, method: method, pathinfo: requestPath, querystring: "")
		assert(response.closed, "Handler did not end the response")
	}
}

/// Cast sockaddr_in to sockaddr
private func sockaddr_cast(_ ptr: UnsafeMutablePointer<sockaddr_in>) -> UnsafeMutablePointer<sockaddr> {
	return UnsafeMutablePointer<sockaddr>(OpaquePointer(ptr))
}
