import RegexBuilder;

final class ParseError : Error {
	let message: String;
	init(_ offset: Int) {
		self.message = "Could not parse string beyond index \(offset)";
	}
}

//func parse(_ string: String.SubSequence) -> Rulelist {
//	let (instance, remainder) = try! Rulelist.match(string);
//	if(remainder.count){
//		throw ParseError(string, offset);
//	}
//	return instance;
//}

protocol Production: LosslessStringConvertible, Equatable {
	static func match(_ string: String) throws -> (Self, String);
}

//struct Rulelist: Production {
//	var rules: [Rule]
//
//	init(rules: [Rule] = []) {
//		self.rules = rules
//	}
//
//	func toString() -> String {
//		return rules.map { $0.toString() }.joined()
//	}
//
//	static func match(_ string: String.SubSequence) throws -> (Rulelist, String.SubSequence) {
//	}
//}
//
//class Rule : Production {
//	let name: Rulename;
//	let definedAs: String;
//	let alternatives: [Alternative];
//
//	init(name: Rulename, definedAs: String, alternatives: [Alternative]) {
//		self.name = name
//		self.definedAs = definedAs
//		self.alternatives = alternatives
//	}
//
//	func toString() -> String {
//
//	}
//
//	static func match(_ string: String, _ offset: Int) throws -> (Self, Int) {
//		<#code#>
//	}
//}
//
//class Rulename : Production {
//	let name: String;
//
//	func toString() -> String {
//
//	}
//	static func match(_ string: String, _ offset: Int) throws -> (Self, Int) {
//		<#code#>
//	}
//}

struct hex_val: Production {
	let lower: Int;
	let upper: Int?;

	init(lower: Int, upper: Int) {
		self.lower = lower;
		self.upper = upper;
	}

	init(_ description: String) {
		self = try! Self.match(description).0;
	}

	var description: String {
		// return lower as a hex string
		String(lower, radix: 16) + (upper != nil ? "-" + String(upper!, radix: 16) : "");
	}

	static func match(_ input: String) throws -> (Self, String) {
		typealias Pat = DFA<String>;
		let ws = DFA<String>(range: "a"..."b");
		// Try to match the pattern at the start of the input string
		guard let match = ws.match(input) else {
			// If no match is found, return nil for Rulename and the entire input string
			throw ParseError(0)
		}

		// Calculate the remainder of the string after the match
		let remainder = String(input.dropFirst(match))

		// Extract the matched rulename
		let node = Self.init(lower: Int(String(match))!, upper: Int(String(match))!)

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, remainder)
	}
}

struct prose_val: Production {
	let remark: String;
	let length: Int;

	init(remark: String) {
		self.remark = remark;
		self.length = remark.count;
	}

	init(_ description: String) {
		let match = try! Self.match(description);
		self.remark = String(match.0.remark);
		self.length = description.count;
	}

	var description: String {
		"<\(remark)>"
	}

	static func match(_ input: String) throws -> (Self, String) {
		let pattern = DFA<String>.concatenate([

		]);

		let node = prose_val(remark: String(input))
		let remainder = ""

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, remainder)
	}
}

struct Terminals {
	static let ALPHA  = DFA<String>(range: "A"..."Z").union(DFA<String>(range: "a"..."z")); // %x41-5A / %x61-7A   ; A-Z / a-z
	static let BIT    = DFA<String>(["0", "1"]); // "0" / "1"
	static let CHAR   = DFA<String>(range: "\u{1}"..."\u{7F}"); // %x01-7F
	static let CR     = DFA<String>(["\u{D}"]); // %x0D
	static let CRLF   = DFA<String>(["\r\n"]); // CR LF
	static let CTL    = DFA<String>(range: "\u{0}"..."\u{1F}").union(["\u{7F}"]); // %x00-1F / %x7F
	static let DIGIT  = DFA<String>(range: "0"..."9"); // %x30-39
	static let DQUOTE = DFA<String>([""]); // %x22
	static let HEXDIG = DFA<String>([""]); // DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
	static let HTAB   = DFA<String>(["\u{9}"]); // %x09
	static let LF     = DFA<String>(["\u{A}"]); // %x0A
//	static let LWSP   = DFA<String>([""]); // *(WSP / CRLF WSP)
	static let OCTET  = DFA<String>(range: "\u{0}"..."\u{FF}"); // %x00-FF
	static let SP     = DFA<String>(["\u{20}"]); // %x20
	static let VCHAR  = DFA<String>(range: "\u{21}"..."\u{7E}"); // %x21-7E
	static let WSP    = DFA<String>([" ", "\t"]); // SP / HTAB
}
