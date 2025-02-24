/// Some minimal rules for parsing an ABNF document

protocol Production: Equatable {
	func toString() -> String
//	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8>
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

	// Errata 3076 provides an updated ABNF for this production
	// See <https://www.rfc-editor.org/errata/eid3076>
	static let ws_pattern = Terminals.WSP.star() ++ Terminals.c_nl;
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		// Initialize a SubSequence starting at the beginning of input
		var remainder = input[input.startIndex...]
		var rules: Array<Rule> = [];
		repeat {
			// First try to parse as a rule
			if let (rule, remainder1) = Rule.match(remainder) {
				remainder = remainder1
				rules.append(rule);
				continue;
			}

			// ws_pattern matches a zero-length string so this should never fail... in theory...
			if let (_, remainder1) = ws_pattern.match(remainder) {
				// Parse the rule, if any
				remainder = remainder1;
				continue;
			}

			// Couldn't be parsed either as a rule or whitespace, end of parsing.
			return (Rulelist(rules: rules), remainder);
		} while true;
	}
}

// Errata 2968 provides an updates ABNF for this production
// See <https://www.rfc-editor.org/errata/eid2968>
// rule           =  rulename defined-as elements c-nl
// defined-as     =  *c-wsp ("=" / "=/") *c-wsp
// elements       =  alternation *WSP
// alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation)
// c-nl           =  comment / CRLF ; comment or newline
struct Rule: Production {
	let rulename: Rulename;
	let definedAs: String;
	let alternation: Alternation;

	init(rulename: Rulename, definedAs: String, alternation: Alternation) {
		self.rulename = rulename
		self.definedAs = definedAs
		self.alternation = alternation
	}

	func toString() -> String {
		return rulename.toString() + definedAs + alternation.toString() + "\r\n"
	}

	static let defined_pattern = Terminals.c_wsp.star() ++ Terminals["="] ++ Terminals.c_wsp.star();
	static let ws_pattern = Terminals.c_wsp.star() ++ Terminals.c_nl;

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		// Parse rulename
		guard let (rulename, remainder1) = Rulename.match(input) else { return nil }

		// Parse defined-as
		guard let (_, remainder2) = defined_pattern.match(remainder1) else { return nil }

		// Parse alternation
		guard let (alternation, remainder3) = Alternation.match(remainder2) else { return nil }

		// Parse *WSP c-nl
		guard let (_, remainder) = ws_pattern.match(remainder3) else { return nil }

		let rule = Rule(
			rulename: rulename,
			definedAs: "=",
			alternation: alternation
		);
		return (rule, remainder);
	}
}

// rulename       =  ALPHA *(ALPHA / DIGIT / "-")
struct Rulename : Production {
	let label: String;
	func toString() -> String {
		return ""
	}

	static let pattern = Terminals.ALPHA ++ (Terminals.ALPHA | Terminals.DIGIT | Terminals["-"]).star();
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		if let (match, remainder) = pattern.match(input) {
			return (Rulename(label: CHAR_string(match)), remainder);
		}else{
			return nil;
		}
	}
}

// alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation)
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
struct Alternation: Production {
	let matches: [Concatenation]

	init(matches: [Concatenation]) {
		self.matches = matches
	}

	func toString() -> String {
		return matches.map { $0.toString() }.joined(separator: " / ")
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		var remainder = input[input.startIndex...]
		var concatenations: [Concatenation] = []

		// Match first concatenation
		guard let (firstConcat, remainder1) = Concatenation.match(remainder) else { return nil }
		concatenations.append(firstConcat)
		remainder = remainder1

		// Match zero or more *c_wsp "/" *c_wsp concatenation
		let pattern = Terminals.c_wsp.star() ++ Terminals["/"] ++ Terminals.c_wsp.star();
		while true {
			// Consume *c_wsp "/" *c_wsp
			guard let (_, remainder2) = pattern.match(remainder) else { break }
			remainder = remainder2

			// Parse concatenation
			guard let (concat, remainder3) = Concatenation.match(remainder) else { break }
			remainder = remainder3
			concatenations.append(concat)
		}

		return (Alternation(matches: concatenations), remainder)
	}
}

// concatenation  =  repetition *(1*c-wsp repetition)
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
struct Concatenation: Production {
	let repetitions: [Repetition]

	init(repetitions: [Repetition]) {
		self.repetitions = repetitions
	}

	func toString() -> String {
		return repetitions.map { $0.toString() }.joined(separator: " ")
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		var reps: [Repetition] = []

		// Match first repetition
		guard let (firstRep, remainder1) = Repetition.match(input) else { return nil }
		reps.append(firstRep)

		// Match zero or more (1*c-wsp repetition)
		var remainder = remainder1
		while true {
			// Consume whitespace
			guard let (_, remainder2) = Terminals.c_wsp.plus().match(remainder) else { break }
			guard let (rep, remainder3) = Repetition.match(remainder2) else { break }
			remainder = remainder3
			reps.append(rep)
		}

		return (Concatenation(repetitions: reps), remainder)
	}
}

// repetition     =  [repeat] element
struct Repetition: Production {
	let min: Int?
	let max: Int?
	let element: Element

	init(min: Int?, max: Int?, element: Element) {
		self.min = min
		self.max = max
		self.element = element
	}

	func toString() -> String {
		var repeatStr = ""
		if let min = min, let max = max {
			repeatStr = min == max ? "\(min)" : "\(min)*\(max)"
		} else if let min = min {
			repeatStr = min == 0 ? "*" : "\(min)*"
		} else if let max = max {
			repeatStr = "*\(max)"
		}
		return repeatStr + element.toString()
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		// Match optional "repeat" rule
		if let (repeatSpecifier, remainder1) = Repeat.match(input) {
			// Match element
			guard let (element, remainder) = Element.match(remainder1) else { return nil }
			return (Repetition(min: repeatSpecifier.min, max: repeatSpecifier.max, element: element), remainder)
		}else{
			// Match element
			guard let (element, remainder) = Element.match(input) else { return nil }
			// If there's no repetition given, then it's exactly one
			return (Repetition(min: 1, max: 1, element: element), remainder)
		}
	}
}

// repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)
struct Repeat: Production {
	let min: Int?
	let max: Int?

	init(min: Int?, max: Int?) {
		self.min = min
		self.max = max
	}

	func toString() -> String {
		if let min, let max {
			return min == max ? "\(min)" : "\(min)*\(max)"
		} else if let min {
			return min == 0 ? "*" : "\(min)*"
		} else if let max {
			return "*\(max)"
		}
		return ""
	}

	static let rangePattern = Terminals.DIGIT.star() ++ Terminals["*"];
	static let minPattern = Terminals.DIGIT.plus();
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		if let (match, remainder1) = rangePattern.match(input) {
			let (minStr, _) = Terminals.DIGIT.star().match(match)!
			let (maxStr, remainder) = Terminals.DIGIT.star().match(remainder1)!
			return (Repeat(min: DIGIT_value(minStr), max: maxStr.isEmpty ? nil : DIGIT_value(maxStr)), remainder)
		} else if let (exactStr, remainder1) = minPattern.match(input) {
			// No star, the number is an exact count
			let count = DIGIT_value(exactStr);
			return (Repeat(min: count, max: count), remainder1)
		} else {
			return nil;
		}
	}
}

// element        =  rulename / group / option / char-val / num-val / prose-val
enum Element: Production {
	case rulename(Rulename)
	case group(Group)
	case option(Option)
	case charVal(Char_val)
	case numVal(Num_val)
	case proseVal(Prose_val)

	func toString() -> String {
		switch self {
			case .rulename(let r): return r.toString()
			case .group(let g): return g.toString()
			case .option(let o): return o.toString()
			case .charVal(let c): return c.toString()
			case .numVal(let n): return n.toString()
			case .proseVal(let p): return p.toString()
		}
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		if let (r, remainder) = Rulename.match(input) { return (.rulename(r), remainder) }
		if let (g, remainder) = Group.match(input) { return (.group(g), remainder) }
		if let (o, remainder) = Option.match(input) { return (.option(o), remainder) }
		if let (c, remainder) = Char_val.match(input) { return (.charVal(c), remainder) }
		if let (n, remainder) = Num_val.match(input) { return (.numVal(n), remainder) }
		if let (p, remainder) = Prose_val.match(input) { return (.proseVal(p), remainder) }
		return nil
	}
}

// group          =  "(" *c-wsp alternation *c-wsp ")"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
struct Group: Production {
	let alternation: Alternation

	init(alternation: Alternation) {
		self.alternation = alternation
	}

	func toString() -> String {
		return "(\(alternation.toString()))"
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		let prefix = Terminals["("] ++ Terminals.c_wsp.star();
		guard let (_, remainder1) = prefix.match(input) else { return nil }
		guard let (alternation, remainder2) = Alternation.match(remainder1) else { return nil }
		let suffix = Terminals.c_wsp.star() ++ Terminals[")"];
		guard let (_, remainder) = suffix.match(remainder2) else { return nil }
		return (Group(alternation: alternation), remainder)
	}
}

// option         =  "[" *c-wsp alternation *c-wsp "]"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
struct Option: Production {
	let alternation: Alternation

	init(alternation: Alternation) {
		self.alternation = alternation
	}

	func toString() -> String {
		return "[\(alternation.toString())]"
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		let prefix_pattern = Terminals["["] ++ Terminals.c_wsp.star();
		guard let (_, remainder1) = prefix_pattern.match(input) else { return nil }
		guard let (alternation, remainder2) = Alternation.match(remainder1) else { return nil }
		let suffix_pattern = Terminals.c_wsp.star() ++ Terminals["]"];
		guard let (_, remainder) = suffix_pattern.match(remainder2) else { return nil }
		return (Option(alternation: alternation), remainder)
	}
}

// char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
struct Char_val: Production {
	let value: String

	init(value: String) {
		self.value = value
	}

	func toString() -> String {
		return "\"\(value)\""
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		guard let (_, remainder1) = Terminals.DQUOTE.match(input) else { return nil }
		let charPattern = DFA<Array<UInt8>>(range: 0x20...0x21) | DFA<Array<UInt8>>(range: 0x23...0x7E)
		guard let (chars, remainder2) = charPattern.star().match(remainder1) else { return nil }
		guard let (_, remainder3) = Terminals.DQUOTE.match(remainder2) else { return nil }
		let value = String(decoding: chars, as: UTF8.self)
		return (Char_val(value: value), remainder3)
	}
}

// num-val        =  "%" (bin-val / dec-val / hex-val)
struct Num_val: Production {
	static func == (lhs: Num_val, rhs: Num_val) -> Bool {
		return lhs.base == rhs.base && lhs.value == rhs.value
	}
	
	enum Base: Int {
		case bin = 2;
		case dec = 10;
		case hex = 16;

		func parseNum<T> (_ input: T) -> Int? where T: Collection, T.Element == UInt8 {
			return switch self {
				case Base.bin: BIT_value(input);
				case Base.dec: DIGIT_value(input);
				case Base.hex: HEXDIG_value(input);
			}
		}
		var numPattern: DFA<Array<UInt8>> {
			return switch self {
				case Base.bin: Terminals.BIT.plus()
				case Base.dec: Terminals.DIGIT.plus()
				case Base.hex: Terminals.HEXDIG.plus()
			}
		}
	}
	let base: Base;

	enum Value: Equatable {
		case sequence(Array<Int>);
		case range(Int, Int);

		func toString(base: Int) -> String {
			switch self {
				case .sequence(let seq): seq.map{ String($0, radix: base) }.joined(separator: ".");
				case .range(let low, let high): String(low, radix: base) + "-" + String(high, radix: base);
			}
		}
	}
	let value: Value;

	func toString() -> String {
		let prefix = switch base {
			case Base.bin: "%b";
			case Base.dec: "%d";
			case Base.hex: "%x";
		}
		return prefix + value.toString(base: base.rawValue);
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		guard let (_, remainder0) = Terminals["%"].match(input) else { return nil }
		guard let (basePrefix, remainder1) = Terminals.CHAR.match(remainder0) else { return nil }
		let base: Base? = switch(basePrefix[basePrefix.startIndex]){
			case 0x42, 0x62: Base.bin // Bb
			case 0x44, 0x64: Base.dec // Dd
			case 0x58, 0x78: Base.hex // Xx
			default: nil
		}
		guard let base else { return nil }

		guard let (firstDigits, remainder2) = base.numPattern.match(remainder1) else { return nil }
		let firstStr = base.parseNum(firstDigits)!
		var values: [Int] = [firstStr]
		var remainder = remainder2
		while true {
			if let (_, remainder3) = Terminals["."].match(remainder) {
				guard let (moreDigits, remainder4) = base.numPattern.match(remainder3) else { break }
				values.append(base.parseNum(moreDigits)!)
				remainder = remainder4
			} else {
				break
			}
		}

		if values.count == 1, let (_, remainder5) = Terminals["-"].match(remainder) {
			guard let (endDigits, remainder6) = base.numPattern.match(remainder5) else { return nil }
			let endStr = base.parseNum(endDigits)
			guard let endStr else { return nil }
			return (Num_val(base: base, value: Value.range(values.first!, endStr)), remainder6)
		}

		return (Num_val(base: base, value: Value.sequence(values)), remainder)
	}
}

// prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"
struct Prose_val: Production {
	let remark: String;

	init(remark: String) {
		self.remark = remark;
		//self.length = remark.count;
	}

	func toString() -> String {
		"<\(remark)>"
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		// 0x20...0x7E - 0x3E
		let pattern: DFA<Array<UInt8>> = (DFA(range: 0x20...0x3D) | DFA(range: 0x3F...0x7E)).star();

		guard let (_, input_) = Terminals["<"].match(input) else { return nil; }
		guard let (match, input__) = pattern.match(input_) else { return nil }
		guard let (_, remainder) = Terminals[">"].match(input__) else { return nil; }

		let node = Prose_val(remark: CHAR_string(match))
		return (node, remainder)
	}
}

struct Terminals {
	typealias Rule = DFA<Array<UInt8>>;
	static let ALPHA : Rule = Terminals["A"..."Z"] | Terminals["a"..."z"]; // %x41-5A / %x61-7A   ; A-Z / a-z
	static let BIT   : Rule = Terminals["0"] | Terminals["1"]; // "0" / "1"
	static let CHAR  : Rule = Rule(range: 0x1...0x7F); // %x01-7F
	static let CR    : Rule = [[0xD]]; // %x0D
	static let CRLF  : Rule = [[0xD, 0xA]]; // CR LF
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
	static let c_wsp : Rule = WSP | (c_nl ++ WSP)

	// c-nl           =  comment / CRLF ; comment or newline
	static let c_nl  : Rule = comment | CRLF;

	// comment        =  ";" *(WSP / VCHAR) CRLF
	static let comment : Rule = Rule([[0x3B]]) ++ (WSP | VCHAR).star() ++ CRLF

	// And a generic way to get an arbitrary character sequence as a Rule
	static subscript (string: String) -> Rule {
		return Rule([Array(string.utf8)]);
	}
	static subscript (string: ClosedRange<Character>) -> Rule {
		let chars = string.lowerBound.asciiValue!...string.upperBound.asciiValue!;
		return Rule(chars.map{ [$0] });
	}
}

func BIT_value(_ input: any Sequence<UInt8>) -> Int {
	var currentValue = 0;
	for c in input {
		currentValue *= 2;
		switch(c){
			case 0x30...0x31: currentValue += Int(c-0x30) // 0-1
			default: fatalError("Invalid input")
		}
	}
	return currentValue;
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

func CHAR_string(_ bytes: any Collection<UInt8>) -> String {
	return String(decoding: bytes, as: UTF8.self)
}
