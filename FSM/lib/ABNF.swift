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

protocol Production: Equatable { //LosslessStringConvertible,  {
	typealias Element = Array<UInt8>;
//	associatedtype Element: Collection;
//	static func match(_: any Collection<Element.Element>) throws -> (Self, Array<Element.Element>.SubSequence);
	static func match(_: any Collection<Element.Element>) -> (Self, Int)?;
}

/// Represents an ABNF rulelist, which is a list of rules.
struct Rulelist: Production {
	var rules: [Rule]

	init(rules: [Rule] = []) {
		self.rules = rules
	}

	func toString() -> String {
		return rules.map { $0.toString() }.joined()
	}

	static func match(_: any Collection<Element.Element>) -> (Rulelist, Int)? {
		return (Rulelist(rules: []), 0);
	}
}

struct Rule: Production {
	let name: String;
	let definedAs: String;
	let alternatives: [String];

	init(name: String, definedAs: String, alternatives: [String]) {
		self.name = name
		self.definedAs = definedAs
		self.alternatives = alternatives
	}

	func toString() -> String {
		return ""
	}

	static func match(_ string: any Collection<UInt8>) -> (Rule, Int)? {
		return (Rule(name: "", definedAs: "", alternatives: [""]), 2);
	}
}

struct Rulename : Production {
	let name: String;

	func toString() -> String {
		return ""
	}
	static func match(_ input: any Collection<UInt8>) -> (Rulename, Int)? {
		return (Rulename(name: ""), 2);
	}
}

struct hex_val: Production {
	let lower: Int;
	let upper: Int?;

	var description: String {
		// return lower as a hex string
		String(lower, radix: 16) + (upper != nil ? "-" + String(upper!, radix: 16) : "");
	}

	static func match(_ input: any Collection<Element.Element>) -> (hex_val, Int)? {
		typealias Pat = DFA<String>;
		let ws = DFA<Array<UInt8>>(range: 0x20...0x20);
		// Try to match the pattern at the start of the input string
		guard let match = ws.match(input) else {
			// If no match is found, return nil for Rulename and the entire input string
//			throw ParseError(0)
			return nil;
		}
		// Extract the matched rulename
		let node = Self.init(lower: Int(String(match))!, upper: Int(String(match))!)

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, 0)
	}
}

struct prose_val: Production {
	let remark: String;

	init(remark: String) {
		self.remark = remark;
		//self.length = remark.count;
	}

	var description: String {
		"<\(remark)>"
	}

	static func match(_ input: any Collection<Element.Element>) -> (prose_val, Int)? {
		let pattern = DFA<Array<UInt8>>.concatenate([
			DFA([[0x3C]]),
			DFA(range: 0x20...0x7E).subtracting(DFA([[0x3E]])).star(),
			DFA([[0x3E]]),
		]);
		print(pattern.toViz());
		guard let match = pattern.match(input) else {
//			throw ParseError(0);
			return nil
		}

		let node = prose_val(remark: String(match))

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, match)
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
