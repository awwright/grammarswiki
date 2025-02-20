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
			DFA(["<"]),
			DFA(range: "\u{20}"..."\u{7E}").subtracting(DFA([">"])),
			DFA([">"]),
		]);
		guard let match = pattern.match(input) else {
			throw ParseError(0);
		}

		let node = prose_val(remark: String(match))

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, String(input.dropFirst(match)))
	}
}

struct Terminals {
	typealias Rule = DFA<Array<UInt8>>;
	static let ALPHA : Rule = Rule(range: 0x41...0x5A).union(Rule(range: 0x61...0x7A)); // %x41-5A / %x61-7A   ; A-Z / a-z
	static let BIT   : Rule = [[0x30], [0x31]]; // "0" / "1"
	static let CHAR  : Rule = Rule(range: 0x1...0x7F); // %x01-7F
	static let CR    : Rule = [[0xD]]; // %x0D
	static let CRLF  : Rule = [[0xD], [0xA]]; // CR LF
	static let CTL   : Rule = Rule(range: 0...0x1F).union([[0x7F]]); // %x00-1F / %x7F
	static let DIGIT : Rule = Rule(range: 0x30...0x39); // %x30-39
	static let DQUOTE: Rule = [[0x22]]; // %x22
	static let HEXDIG: Rule = [[0x30], [0x31], [0x32], [0x33], [0x34], [0x35], [0x36], [0x37], [0x38], [0x39], [0x41], [0x42], [0x43], [0x44], [0x45], [0x46]]; // DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
	static let HTAB  : Rule = [[0x9]]; // %x09
	static let LF    : Rule = [[0xA]]; // %x0A
	static let LWSP  : Rule = WSP.union(CRLF.concatenate(WSP)).star(); // *(WSP / CRLF WSP)
	static let OCTET : Rule = Rule(range: 0...0xFF); // %x00-FF
	static let SP    : Rule = [[0x20]]; // %x20
	static let VCHAR : Rule = Rule(range: 0x21...0x7E); // %x21-7E
	static let WSP   : Rule = [[0x20, 0x9]]; // SP / HTAB
}
