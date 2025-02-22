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
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8>
}

/// Represents an ABNF rulelist, which is a list of rules.
// rulelist       =  1*( rule / (*c-wsp c-nl) )
struct Rulelist: Production {
	var rules: [Rule]

	init(rules: [Rule] = []) {
		self.rules = rules
	}

	func toString() -> String {
		return rules.map { $0.toString() }.joined()
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		let ws_pattern = ( Terminals.c_wsp.star() ++ Terminals.c_nl );
		var remainder = input[input.startIndex...]
		var rules: Array<Rule> = [];
		repeat {
			// ws_pattern matches a zero-length string so this should never fail... in theory...
			let (ws, remainder) = ws_pattern.match(input)!;
			// Parse the rule, if any
			guard let (rule, remainder) = Rule.match(remainder)
			else { break }
			rules.append(rule);
		} while true;
		return (Rulelist(rules: rules), remainder);
	}
}

// rule           =  rulename defined-as elements c-nl
// defined-as     =  *c-wsp ("=" / "=/") *c-wsp
// elements       =  alternation *c-wsp
// c-nl           =  comment / CRLF ; comment or newline
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

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		if let (match, remainder) = Terminals.ALPHA.match(input) {
			return (Rule(name: "", definedAs: "", alternatives: [""]), remainder);
		} else {
			return nil;
		}
	}
}

// rulename       =  ALPHA *(ALPHA / DIGIT / "-")
struct Rulename : Production {
	let label: String;
	func toString() -> String {
		return ""
	}
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		let pattern = Terminals.ALPHA ++ (Terminals.ALPHA | Terminals.DIGIT | Terminals["-"]).star();
		if let (match, remainder) = pattern.match(input) {
			return (Rulename(label: ""), remainder);
		}else{
			return nil;
		}
	}
}

// alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation)
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
struct Alternation : Production {
	let matches: [Concatenation];

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T : Collection {
		let pattern = Terminals.ALPHA ++ (Terminals.ALPHA | Terminals.DIGIT | Terminals["-"]).star();
		guard let (match, remainder) = Concatenation.match(input) else {
			return nil;
		}
		let matches: Array<Concatenation> = [];

		return (Alternation(matches: matches), remainder);
	}
}

// concatenation  =  repetition *(1*c-wsp repetition)
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
struct Concatenation : Production {
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T : Collection {
		return (Concatenation(), input[input.startIndex...]);
	}
	

}

// repetition     =  [repeat] element
//struct repetition : Production {}

// repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)
//struct repeat : Production {}

// element        =  rulename / group / option / char-val / num-val / prose-val
//struct element : Production {}

// group          =  "(" *c-wsp alternation *c-wsp ")"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
//struct group : Production {}

// option         =  "[" *c-wsp alternation *c-wsp "]"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
//struct option : Production {}

// char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
//struct char_val : Production {}

// num-val        =  "%" (bin-val / dec-val / hex-val)
//struct num_val : Production {}

// bin-val        =  "b" 1*BIT [ 1*("." 1*BIT) / ("-" 1*BIT) ]
//struct bin_val : Production {}

// dec-val        =  "d" 1*DIGIT [ 1*("." 1*DIGIT) / ("-" 1*DIGIT) ]
//struct dec_val : Production {}


// hex-val        =  "x" 1*HEXDIG [ 1*("." 1*HEXDIG) / ("-" 1*HEXDIG) ]
struct Hex_val: Production {
	let lower: Int;
	let upper: Int?;

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		typealias Pat = DFA<String>;
		let ws = DFA<Array<UInt8>>(range: 0x20...0x20);
		// Try to match the pattern at the start of the input string
		guard let (match, remainder) = ws.match(input) else {
			// If no match is found, return nil for Rulename and the entire input string
//			throw ParseError(0)
			return nil;
		}
		// Extract the matched rulename
		let node = Hex_val(lower: HEXDIG_value(match), upper: HEXDIG_value(match))

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, remainder)
	}
}

// prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"
struct prose_val: Production {
	let remark: String;

	init(remark: String) {
		self.remark = remark;
		//self.length = remark.count;
	}

	var description: String {
		"<\(remark)>"
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		let pattern: DFA<Array<UInt8>>
			= Terminals["<"] ++ (DFA(range: 0x20...0x3D) | DFA(range: 0x3F...0x7E)).star() ++ Terminals[">"];

		guard let (match, remainder) = pattern.match(input)
		else {
			return nil
		}

		let node = prose_val(remark: "")

		// Return the Rulename struct with the name and the remaining part of the string
		return (node, remainder)
	}
}

struct Terminals {
	typealias Rule = DFA<Array<UInt8>>;
	static let ALPHA : Rule = Terminals["A"..."Z"] | Terminals["a"..."z"]; // %x41-5A / %x61-7A   ; A-Z / a-z
	static let BIT   : Rule = Terminals["0"] | Terminals["1"]; // "0" / "1"
	static let CHAR  : Rule = Rule(range: 0x1...0x7F); // %x01-7F
	static let CR    : Rule = [[0xD]]; // %x0D
	static let CRLF  : Rule = [[0xD], [0xA]]; // CR LF
	static let CTL   : Rule = Rule(range: 0...0x1F) | Rule([[0x7F]]); // %x00-1F / %x7F
	static let DIGIT : Rule = Rule(range: 0x30...0x39); // %x30-39
	static let DQUOTE: Rule = [[0x22]]; // %x22
	static let HEXDIG: Rule = DIGIT | Terminals["A"..."F"] | Terminals["a"..."f"]
	static let HTAB  : Rule = [[0x9]]; // %x09
	static let LF    : Rule = [[0xA]]; // %x0A
	static let LWSP  : Rule = (WSP | (CRLF ++ WSP)).star(); // *(WSP / CRLF WSP)
	static let OCTET : Rule = Rule(range: 0...0xFF); // %x00-FF
	static let SP    : Rule = [[0x20]]; // %x20
	static let VCHAR : Rule = Rule(range: 0x21...0x7E); // %x21-7E
	static let WSP   : Rule = SP | HTAB; // SP / HTAB

	// c-wsp          =  WSP / (c-nl WSP)
	static let c_wsp : Rule = WSP.union(c_nl.concatenate(WSP))

	// c-nl           =  comment / CRLF ; comment or newline
	static let c_nl  : Rule = comment.union(CRLF);

	// comment        =  ";" *(WSP / VCHAR) CRLF
	static let comment : Rule = Rule([[0x3B]]).concatenate(WSP.union(VCHAR).star()).concatenate(CRLF)

	// And a generic way to get an arbitrary character sequence as a Rule
	static subscript (string: String) -> Rule {
		return Rule([Array(string.utf8)]);
	}
	static subscript (string: ClosedRange<Character>) -> Rule {
		let chars = string.lowerBound.asciiValue!...string.upperBound.asciiValue!;
		return Rule(chars.map{ [$0] });
	}
}

func DIGIT_value(_ input: any Sequence<UInt8>) -> Int {
	var currentValue = 0;
	for c in input {
		currentValue *= 10;
		switch(c){
			case 0x30...0x39: currentValue += Int(c-0x30) // 0-9
			default: fatalError("Invalid input")
		}
	}
	return currentValue;
}

func HEXDIG_value(_ input: any Sequence<UInt8>) -> Int {
	var currentValue = 0;
	for c in input {
		currentValue *= 16;
		switch(c){
			case 0x30...0x39: currentValue += Int(c-0x30) // 0-9
			case 0x41...0x46: currentValue += Int(c-0x41+10) // A-F
			case 0x61...0x46: currentValue += Int(c-0x61+10) // a-f
			default: fatalError("Invalid input")
		}
	}
	return currentValue;
}
