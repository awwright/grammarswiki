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
		let pattern = /^([0-9a-fA-F]+)(?:-([0-9a-fA-F]+))?/.ignoresCase();

		// Try to match the pattern at the start of the input string
		guard let match = try! pattern.firstMatch(in: input) else {
			// If no match is found, return nil for Rulename and the entire input string
			throw ParseError(0)
		}
//		print("0:", match.0);
//		print("1:", match.1);

		// Calculate the remainder of the string after the match
		let remainder = String(input.dropFirst(match.0.count))

		// Extract the matched rulename
		let node = Self.init(lower: Int(String(match.1))!, upper: Int(String(match.2!))!)

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
		let pattern = /^<([ -=\x3f@\x5b-~]*)>/.ignoresCase();

		// Try to match the pattern at the start of the input string
		guard let match = try! pattern.firstMatch(in: input) else {
			// If no match is found, return nil for Rulename and the entire input string
			throw ParseError(0)
		}
//		print("0:", match.0);
//		print("1:", match.1);

		// Calculate the remainder of the string after the match
		let remainder = String(input.dropFirst(match.0.count))

		// Extract the matched rulename
		let node = Self.init(remark: String(match.1))

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, remainder)
	}
}
