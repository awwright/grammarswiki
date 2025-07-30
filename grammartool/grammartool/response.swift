enum ResponseStatus {
	/// The response is what the user asked for
	case ok;
	/// The request was well formed but we can't figure out what the user is referring to
	case notFound;
	/// Some other error preventing a proper response
	case error;
}

protocol ResponseProtocol {
	var status: ResponseStatus { get set }
	var contentType: String { get set }
	mutating func write(_: Array<UInt8>)
	mutating func writeLn(_: String)
	mutating func end()
}

struct BufferedResponse: ResponseProtocol {
	var status: ResponseStatus
	var contentType: String
	var content: Array<UInt8>

	mutating func write(_ segment: Array<UInt8>) {
		content += segment
	}

	mutating func writeLn(_ segment: String) {
		content += Array(segment.utf8) + Array("\r\n".utf8)
	}

	func end() {
		// No-op
	}
}
