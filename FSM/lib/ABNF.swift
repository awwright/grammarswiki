/// Some minimal rules for parsing an ABNF document

protocol ABNFProduction: Equatable {
	func toString() -> String
//	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8>
}

/// Represents an ABNF rulelist, which is a list of rules.
// rulelist       =  1*( rule / (*c-wsp c-nl) )
public struct ABNFRulelist: ABNFProduction {
	let rules: [ABNFRule]

	init(rules: [ABNFRule] = []) {
		self.rules = rules
	}

	public var dictionary: Dictionary<String, ABNFRule> {
		var dict: Dictionary<String, ABNFRule> = [:];
		rules.forEach {
			rule in
			let rulename = rule.rulename.label;
			if let previousRule = dict[rulename] {
				// If we've already seen this rule, and it's of the correct type, merge it with the previous definition
				if(rule.definedAs == "/="){
					dict[rulename] = previousRule.union(rule)
				}
			}else{
				// TODO: Verify definedAs is "="
				dict[rulename] = rule
			}
		}
		return dict;
	}

	public func toString() -> String {
		return rules.map { $0.toString() }.joined()
	}

	var referencedRules: Set<String> {
		return Set(rules.flatMap(\.referencedRules))
	}

	public func toFSM(rules ruleMap: Dictionary<String, DFA<Array<UInt>>>) -> Dictionary<String, DFA<Array<UInt>>> {
		// Get a Dictionary of each rule by its name to its referencedRules
		let requiredRules = Dictionary<String, Set<String>>(uniqueKeysWithValues: rules.map {
			($0.rulename.label, $0.referencedRules)
		}).filter { $0.1.contains($0.0) == false }

		let rulesByName = self.dictionary;

		var resolvedRules = ruleMap;
		main: repeat {
			for (rulename, referenced) in requiredRules {
				if resolvedRules[rulename] == nil && referenced.isSubset(of: resolvedRules.keys) {
					guard let rule = rulesByName[rulename] else {
						fatalError("Could not resolve \(rulename)")
					}
					resolvedRules[rulename] = rule.toFSM(rules: resolvedRules);
					continue main;
				}
			}
			break main;
		} while true;
		return resolvedRules;
	}

	// Errata 3076 provides an updated ABNF for this production
	// See <https://www.rfc-editor.org/errata/eid3076>
	static let ws_pattern = Terminals.WSP.star() ++ Terminals.c_nl;
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		// Initialize a SubSequence starting at the beginning of input
		var remainder = input[input.startIndex...]
		var rules: Array<ABNFRule> = [];
		repeat {
			// First try to parse as a rule
			if let (rule, remainder1) = ABNFRule.match(remainder) {
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
			return (ABNFRulelist(rules: rules), remainder);
		} while true;
	}

	public static func parse<T>(_ input: T) -> Self? where T: Collection<UInt8> {
		let match = Self.match(input)
		guard let (rulelist, remainder) = match else {
			assertionFailure("Could not parse input")
			return nil;
		}
		guard remainder.isEmpty else {
			assertionFailure("Could not parse input past \(remainder.count)")
			return nil;
		}
		return rulelist;
	}
}

// Errata 2968 provides an updates ABNF for this production
// See <https://www.rfc-editor.org/errata/eid2968>
// rule           =  rulename defined-as elements c-nl
// defined-as     =  *c-wsp ("=" / "=/") *c-wsp
// elements       =  alternation *WSP
// alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation)
// c-nl           =  comment / CRLF ; comment or newline
public struct ABNFRule: ABNFProduction {
	public let rulename: ABNFRulename;
	public let definedAs: String;
	public let alternation: ABNFAlternation;

	public init(rulename: ABNFRulename, definedAs: String, alternation: ABNFAlternation) {
		self.rulename = rulename
		self.definedAs = definedAs
		self.alternation = alternation
	}

	public func toString() -> String {
		return rulename.toString() + " " + definedAs + " " + alternation.toString() + "\r\n"
	}

	var referencedRules: Set<String> {
		return alternation.referencedRules;
	}

	public func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		alternation.toFSM(rules: rules)
	}

	public func union(_ other: ABNFRule) -> ABNFRule{
		return self.union(other.alternation);
	}

	public func union(_ other: ABNFAlternation) -> ABNFRule {
		return ABNFRule(rulename: rulename, definedAs: definedAs, alternation: self.alternation.union(other))
	}

	static let defined_pattern = Terminals.c_wsp.star() ++ Terminals["="] ++ Terminals.c_wsp.star();
	static let ws_pattern = Terminals.c_wsp.star() ++ Terminals.c_nl;

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		// Parse rulename
		guard let (rulename, remainder1) = ABNFRulename.match(input) else { return nil }

		// Parse defined-as
		guard let (_, remainder2) = defined_pattern.match(remainder1) else { return nil }

		// Parse alternation
		guard let (alternation, remainder3) = ABNFAlternation.match(remainder2) else { return nil }

		// Parse *WSP c-nl
		guard let (_, remainder) = ws_pattern.match(remainder3) else { return nil }

		let rule = ABNFRule(
			rulename: rulename,
			definedAs: "=",
			alternation: alternation
		);
		return (rule, remainder);
	}
}

// rulename       =  ALPHA *(ALPHA / DIGIT / "-")
public struct ABNFRulename : ABNFProduction {
	let label: String;
	func toString() -> String {
		return label;
	}

	var referencedRules: Set<String> {
		return Set([label])
	}

	/// - rules: A dictionary defining a FSM to use when the given rule is encountered.
	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		return rules[label]!;
	}

	static let pattern = Terminals.ALPHA ++ (Terminals.ALPHA | Terminals.DIGIT | Terminals["-"]).star();
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		if let (match, remainder) = pattern.match(input) {
			return (ABNFRulename(label: CHAR_string(match)), remainder);
		}else{
			return nil;
		}
	}
}

// alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation)
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
public struct ABNFAlternation: ABNFProduction {
	let matches: [ABNFConcatenation]

	public init(matches: [ABNFConcatenation]) {
		self.matches = matches
	}

	public func toString() -> String {
		return matches.map { $0.toString() }.joined(separator: " / ")
	}

	var referencedRules: Set<String> {
		return matches.reduce(Set(), { $0.union($1.referencedRules) })
	}

	public func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		DFA.union(matches.map{ $0.toFSM(rules: rules) })
	}

	public func union(_ other: ABNFAlternation) -> ABNFAlternation {
		return ABNFAlternation(matches: matches + other.matches)
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		var remainder = input[input.startIndex...]
		var concatenations: [ABNFConcatenation] = []

		// Match first concatenation
		guard let (firstConcat, remainder1) = ABNFConcatenation.match(remainder) else { return nil }
		concatenations.append(firstConcat)
		remainder = remainder1

		// Match zero or more *c_wsp "/" *c_wsp concatenation
		let pattern = Terminals.c_wsp.star() ++ Terminals["/"] ++ Terminals.c_wsp.star();
		while true {
			// Consume *c_wsp "/" *c_wsp
			guard let (_, remainder2) = pattern.match(remainder) else { break }
			remainder = remainder2

			// Parse concatenation
			guard let (concat, remainder3) = ABNFConcatenation.match(remainder) else { break }
			remainder = remainder3
			concatenations.append(concat)
		}

		return (ABNFAlternation(matches: concatenations), remainder)
	}
}

// concatenation  =  repetition *(1*c-wsp repetition)
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
public struct ABNFConcatenation: ABNFProduction {
	let repetitions: [ABNFRepetition]

	init(repetitions: [ABNFRepetition]) {
		self.repetitions = repetitions
	}

	func toString() -> String {
		return repetitions.map { $0.toString() }.joined(separator: " ")
	}

	var referencedRules: Set<String> {
		return repetitions.reduce(Set(), { $0.union($1.referencedRules) })
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		DFA.concatenate(repetitions.map { $0.toFSM(rules: rules) })
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		var reps: [ABNFRepetition] = []

		// Match first repetition
		guard let (firstRep, remainder1) = ABNFRepetition.match(input) else { return nil }
		reps.append(firstRep)

		// Match zero or more (1*c-wsp repetition)
		var remainder = remainder1
		while true {
			// Consume whitespace
			guard let (_, remainder2) = Terminals.c_wsp.plus().match(remainder) else { break }
			guard let (rep, remainder3) = ABNFRepetition.match(remainder2) else { break }
			remainder = remainder3
			reps.append(rep)
		}

		return (ABNFConcatenation(repetitions: reps), remainder)
	}
}

// repetition     =  [repeat] element
// repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)
public struct ABNFRepetition: ABNFProduction {
	let min: UInt
	let max: UInt?
	let element: ABNFElement

	init(min: UInt, max: UInt?, element: ABNFElement) {
		self.min = min
		self.max = max
		if let max {
			precondition(min <= max)
		}
		self.element = element
	}

	func toString() -> String {
		let repeatStr =
		if let max {
			if min == 1 && max == 1 { "" }
			else if(min == max){ "\(min)" }
			else{ "\(min)*\(max)" }
		} else {
			if min == 0 { "*" }
			else{ "\(min)*" }
		}
		return repeatStr + element.toString()
	}

	var referencedRules: Set<String> {
		return element.referencedRules
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		let fsm = element.toFSM(rules: rules);
		if(min == 0 && max == 1){
			return fsm.optional();
		}else if(min == 0 && max == nil){
			return fsm.star();
		}else if(min == 1 && max == nil){
			return fsm.plus();
		}else{
			if let max {
				return fsm.repeating(Int(min)...Int(max));
			}else{
				return fsm.repeating(Int(min)...);
			}
		}
	}

	static let rangePattern = Terminals.DIGIT.star() ++ Terminals["*"];
	static let minPattern = Terminals.DIGIT.plus();
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		if let (match, remainder1) = rangePattern.match(input) {
			// (*DIGIT "*" *DIGIT) element
			// match = *DIGIT "*"
			let (minStr, _) = Terminals.DIGIT.star().match(match)!
			let (maxStr, remainder2) = Terminals.DIGIT.star().match(remainder1)!
			guard let (element, remainder) = ABNFElement.match(remainder2) else { return nil }
			return (ABNFRepetition(min: DIGIT_value(minStr), max: maxStr.isEmpty ? nil : DIGIT_value(maxStr), element: element), remainder)
		} else if let (exactStr, remainder1) = minPattern.match(input) {
			// 1*DIGIT element
			let count = DIGIT_value(exactStr);
			guard let (element, remainder) = ABNFElement.match(remainder1) else { return nil }
			return (ABNFRepetition(min: count, max: count, element: element), remainder)
		} else {
			// element
			guard let (element, remainder) = ABNFElement.match(input) else { return nil }
			return (ABNFRepetition(min: 1, max: 1, element: element), remainder)
		}
	}
}

// element        =  rulename / group / option / char-val / num-val / prose-val
public enum ABNFElement: ABNFProduction {
	case rulename(ABNFRulename)
	case group(ABNFGroup)
	case option(ABNFOption)
	case charVal(ABNFCharVal)
	case numVal(ABNFNumVal)
	case proseVal(ABNFProseVal)

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

	var referencedRules: Set<String> {
		switch self {
			case .rulename(let r): return r.referencedRules
			case .group(let g): return g.referencedRules
			case .option(let o): return o.referencedRules
			case .charVal(let c): return c.referencedRules
			case .numVal(let n): return n.referencedRules
			case .proseVal(let p): return p.referencedRules
		}
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		switch self {
			case .rulename(let r): return r.toFSM(rules: rules)
			case .group(let g): return g.toFSM(rules: rules)
			case .option(let o): return o.toFSM(rules: rules)
			case .charVal(let c): return c.toFSM(rules: rules)
			case .numVal(let n): return n.toFSM(rules: rules)
			case .proseVal(let p): return p.toFSM(rules: rules)
		}
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		if let (r, remainder) = ABNFRulename.match(input) { return (.rulename(r), remainder) }
		if let (g, remainder) = ABNFGroup.match(input) { return (.group(g), remainder) }
		if let (o, remainder) = ABNFOption.match(input) { return (.option(o), remainder) }
		if let (c, remainder) = ABNFCharVal.match(input) { return (.charVal(c), remainder) }
		if let (n, remainder) = ABNFNumVal.match(input) { return (.numVal(n), remainder) }
		if let (p, remainder) = ABNFProseVal.match(input) { return (.proseVal(p), remainder) }
		return nil
	}
}

// group          =  "(" *c-wsp alternation *c-wsp ")"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
public struct ABNFGroup: ABNFProduction {
	let alternation: ABNFAlternation

	func toString() -> String {
		return "(\(alternation.toString()))"
	}

	var referencedRules: Set<String> {
		return alternation.referencedRules
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		alternation.toFSM(rules: rules)
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		let prefix = Terminals["("] ++ Terminals.c_wsp.star();
		guard let (_, remainder1) = prefix.match(input) else { return nil }
		guard let (alternation, remainder2) = ABNFAlternation.match(remainder1) else { return nil }
		let suffix = Terminals.c_wsp.star() ++ Terminals[")"];
		guard let (_, remainder) = suffix.match(remainder2) else { return nil }
		return (ABNFGroup(alternation: alternation), remainder)
	}
}

// option         =  "[" *c-wsp alternation *c-wsp "]"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
public struct ABNFOption: ABNFProduction {
	let alternation: ABNFAlternation

	func toString() -> String {
		return "[\(alternation.toString())]"
	}

	var referencedRules: Set<String> {
		return alternation.referencedRules
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		alternation.toFSM(rules: rules).optional()
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		let prefix_pattern = Terminals["["] ++ Terminals.c_wsp.star();
		guard let (_, remainder1) = prefix_pattern.match(input) else { return nil }
		guard let (alternation, remainder2) = ABNFAlternation.match(remainder1) else { return nil }
		let suffix_pattern = Terminals.c_wsp.star() ++ Terminals["]"];
		guard let (_, remainder) = suffix_pattern.match(remainder2) else { return nil }
		return (ABNFOption(alternation: alternation), remainder)
	}
}

// char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
public struct ABNFCharVal: ABNFProduction {
	let sequence: Array<UInt>

	func toString() -> String {
		sequence.forEach { assert($0 < 128); }
		let seq = sequence.map{ UInt8($0) }
		return "\"\(CHAR_string(seq))\""
	}

	var referencedRules: Set<String> {
		return []
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		return DFA(verbatim: sequence)
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		guard let (_, remainder1) = Terminals.DQUOTE.match(input) else { return nil }
		let charPattern = DFA<Array<UInt8>>(range: 0x20...0x21) | DFA<Array<UInt8>>(range: 0x23...0x7E)
		guard let (chars, remainder2) = charPattern.star().match(remainder1) else { return nil }
		guard let (_, remainder3) = Terminals.DQUOTE.match(remainder2) else { return nil }
		return (ABNFCharVal(sequence: chars.map { UInt($0) }), remainder3)
	}
}

// num-val        =  "%" (bin-val / dec-val / hex-val)
public struct ABNFNumVal: ABNFProduction {
	public static func == (lhs: ABNFNumVal, rhs: ABNFNumVal) -> Bool {
		return lhs.base == rhs.base && lhs.value == rhs.value
	}
	
	enum Base: Int {
		case bin = 2;
		case dec = 10;
		case hex = 16;

		func parseNum<T> (_ input: T) -> UInt? where T: Collection, T.Element == UInt8 {
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
		case sequence(Array<UInt>);
		case range(UInt, UInt);

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

	var referencedRules: Set<String> {
		return []
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		switch self.value {
			case .sequence(let seq): return DFA(verbatim: seq)
			case .range(let low, let high): return DFA(range: low...high)
		}
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
		var values: [UInt] = [firstStr]
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
			return (ABNFNumVal(base: base, value: Value.range(values.first!, endStr)), remainder6)
		}

		return (ABNFNumVal(base: base, value: Value.sequence(values)), remainder)
	}
}

// prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"
public struct ABNFProseVal: ABNFProduction {
	let remark: String;

	init(remark: String) {
		self.remark = remark;
		//self.length = remark.count;
	}

	var referencedRules: Set<String> {
		return []
	}

	func toString() -> String {
		"<\(remark)>"
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		fatalError("Cannot convert prose to FSM")
	}

	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		// 0x20...0x7E - 0x3E
		let pattern: DFA<Array<UInt8>> = (DFA(range: 0x20...0x3D) | DFA(range: 0x3F...0x7E)).star();

		guard let (_, input_) = Terminals["<"].match(input) else { return nil; }
		guard let (match, input__) = pattern.match(input_) else { return nil }
		guard let (_, remainder) = Terminals[">"].match(input__) else { return nil; }

		let node = ABNFProseVal(remark: CHAR_string(match))
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

func BIT_value(_ input: any Sequence<UInt8>) -> UInt {
	var currentValue: UInt = 0;
	for c in input {
		currentValue *= 2;
		switch(c){
			case 0x30...0x31: currentValue += UInt(c-0x30) // 0-1
			default: fatalError("Invalid input")
		}
	}
	return currentValue;
}

func DIGIT_value(_ input: any Sequence<UInt8>) -> UInt {
	var currentValue: UInt = 0;
	for c in input {
		currentValue *= 10;
		switch(c){
			case 0x30...0x39: currentValue += UInt(c-0x30) // 0-9
			default: fatalError("Invalid input")
		}
	}
	return currentValue;
}

func HEXDIG_value(_ input: any Sequence<UInt8>) -> UInt {
	var currentValue: UInt = 0;
	for c in input {
		currentValue *= 16;
		switch(c){
			case 0x30...0x39: currentValue += UInt(c-0x30) // 0-9
			case 0x41...0x46: currentValue += UInt(c-0x41+10) // A-F
			case 0x61...0x66: currentValue += UInt(c-0x61+10) // a-f
			default: fatalError("Invalid input")
		}
	}
	return currentValue;
}

func CHAR_string(_ bytes: any Collection<UInt8>) -> String {
	return String(decoding: bytes, as: UTF8.self)
}
