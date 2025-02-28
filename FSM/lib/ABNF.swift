/// Some minimal rules for parsing an ABNF document

public protocol ABNFProduction: Equatable, Comparable, Hashable, CustomStringConvertible {
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8>
}

extension ABNFProduction {
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

/// Represents an ABNF rulelist, which is a list of rules.
// rulelist       =  1*( rule / (*c-wsp c-nl) )
public struct ABNFRulelist: ABNFProduction {
	let rules: [ABNFRule]

	init(rules: [ABNFRule] = []) {
		self.rules = rules
	}

	public static func < (lhs: ABNFRulelist, rhs: ABNFRulelist) -> Bool {
		return lhs.rules < rhs.rules;
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

	public var description: String {
		return rules.map { $0.description }.joined()
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
	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		// Initialize a SubSequence starting at the beginning of input
		var remainder = input[...]
		var rules: [ABNFRule] = []
		while !remainder.isEmpty {
			if let (rule, remainder1) = ABNFRule.match(remainder) {
				// First try to parse as a rule
				rules.append(rule)
				remainder = remainder1
			} else if let (_, remainder1) = ws_pattern.match(remainder) {
				// ws_pattern matches a zero-length string so this should never fail... in theory...
				remainder = remainder1
			} else {
				// Couldn't be parsed either as a rule or whitespace, end of parsing.
				break;
			}
		}
		return (ABNFRulelist(rules: rules), remainder);
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

	public static func < (lhs: ABNFRule, rhs: ABNFRule) -> Bool {
		if lhs.rulename < rhs.rulename { return true }
		if lhs.rulename > rhs.rulename { return false }
		return lhs.alternation < rhs.alternation;
	}

	public var description: String {
		return "\(rulename.description) \(definedAs) \(alternation.description)\r\n"
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

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
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

	public static func < (lhs: ABNFRulename, rhs: ABNFRulename) -> Bool {
		return lhs.label < rhs.label;
	}

	var element: ABNFElement {
		ABNFElement.rulename(self)
	}

	public var description: String {
		return label;
	}

	var referencedRules: Set<String> {
		return Set([label])
	}

	/// - rules: A dictionary defining a FSM to use when the given rule is encountered.
	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		return rules[label]!;
	}

	public func hasUnion(_ other: ABNFRulename) -> ABNFRulename? {
		if self == other {
			return self;
		}
		return nil;
	}

	static let pattern = Terminals.ALPHA ++ (Terminals.ALPHA | Terminals.DIGIT | Terminals["-"]).star();
	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
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
public struct ABNFAlternation: ABNFProduction, CustomDebugStringConvertible {

	// An implementation for CustomDebugStringConvertible
	public var debugDescription: String {
		return self.description;
	}

	public let matches: [ABNFConcatenation]

	public init(matches: [ABNFConcatenation]) {
		self.matches = matches
	}

	//
	public init(_ concatenation: ABNFConcatenation) {
		self.matches = [concatenation];
	}

	public init(_ repetition: ABNFRepetition) {
		self.matches = [ABNFConcatenation(repetitions: [repetition])];
	}

	public init(_ element: ABNFElement) {
		self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: element)])];
	}

	public init(_ option: ABNFOption) {
		self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: option.element)])];
	}

	public init(_ group: ABNFGroup) {
		self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: group.element)])];
	}

	public init(_ charVal: ABNFCharVal) {
		self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: charVal.element)])];
	}

	public init(_ numVal: ABNFNumVal) {
		self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: numVal.element)])];
	}

	public init(_ prose: ABNFProseVal) {
		self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: prose.element)])];
	}

	/// Create an expression that matches exactly a single codepoint
	public init(symbol: any UnsignedInteger) {
//		if(Int(symbol) >= 0x21 && Int(symbol) <= 0x7E){
//			self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: ABNFElement.charVal(ABNFCharVal(sequence: [UInt(symbol)])))])];
//		}
		self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: ABNFElement.numVal(ABNFNumVal(base: .hex, value: .sequence([UInt(symbol)]))))])];
	}

	public static func < (lhs: ABNFAlternation, rhs: ABNFAlternation) -> Bool {
		return lhs.matches < rhs.matches;
	}

	public var description: String {
		return matches.map { $0.description }.joined(separator: " / ")
	}

	var referencedRules: Set<String> {
		return matches.reduce(Set(), { $0.union($1.referencedRules) })
	}

	public func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		DFA.union(matches.map{ $0.toFSM(rules: rules) })
	}

	public func union(_ other: ABNFAlternation) -> ABNFAlternation {
		// Iterate over other and try to merge it with an existing element if possible, otherwise append to the end.
		var newMatches = self.matches;
		// For every element in `other`, append it to the end.
		// Then see if the last element can be merged in with an existing element before it.
		// If so, check that element and so on.
		// Try to preserve the order as much as possible because sometimes that is significant.
		other: for otherConcat in other.matches {
			var i = newMatches.count;
			newMatches.append(otherConcat);
			var search = newMatches.last!;
			while i > 0 {
				i -= 1;
				if let replacementConcat = newMatches[i].hasUnion(search) {
					newMatches[i] = replacementConcat;
					// remove elements matching `search`
					newMatches.removeAll(where: {$0 == search});
					search = replacementConcat;
				}
			}
		}
		return ABNFAlternation(matches: newMatches)
	}

	public func sorted() -> ABNFAlternation {
		return ABNFAlternation(matches: matches.sorted())
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	public init(repetitions: [ABNFRepetition]) {
		self.repetitions = repetitions
	}

	public init(_ repetition: ABNFRepetition) {
		self.repetitions = [repetition];
	}

	public init(_ element: ABNFElement) {
		self.repetitions = [ABNFRepetition(min: 1, max: 1, element: element)];
	}

	public init(_ option: ABNFOption) {
		self.repetitions = [ABNFRepetition(min: 1, max: 1, element: option.element)];
	}

	public init(_ group: ABNFGroup) {
		self.repetitions = [ABNFRepetition(min: 1, max: 1, element: group.element)];
	}

	public init(_ charVal: ABNFCharVal) {
		self.repetitions = [ABNFRepetition(min: 1, max: 1, element: charVal.element)];
	}

	public init(_ numVal: ABNFNumVal) {
		self.repetitions = [ABNFRepetition(min: 1, max: 1, element: numVal.element)];
	}

	public init(_ prose: ABNFProseVal) {
		self.repetitions = [ABNFRepetition(min: 1, max: 1, element: prose.element)];
	}

	public var alternation: ABNFAlternation {
		ABNFAlternation(matches: [self])
	}

	public static func < (lhs: ABNFConcatenation, rhs: ABNFConcatenation) -> Bool {
		return lhs.repetitions < rhs.repetitions;
	}

	public var description: String {
		return repetitions.map { $0.description }.joined(separator: " ")
	}

	var referencedRules: Set<String> {
		return repetitions.reduce(Set(), { $0.union($1.referencedRules) })
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		DFA.concatenate(repetitions.map { $0.toFSM(rules: rules) })
	}

	public func concatenate(_ other: ABNFConcatenation) -> ABNFConcatenation {
		return ABNFConcatenation(repetitions: repetitions + other.repetitions)
	}

	public func concatenate(_ other: ABNFRepetition) -> ABNFConcatenation {
		return ABNFConcatenation(repetitions: repetitions + [other])
	}

	public func hasUnion(_ other: ABNFConcatenation) -> ABNFConcatenation? {
		if self == other {
			return self;
		}
		if(repetitions.count == 1 && other.repetitions.count == 1){
			if let replacement = repetitions[0].hasUnion(other.repetitions[0]) {
				return ABNFConcatenation(repetitions: [replacement]);
			}
		}
		return nil;
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	public init(min: UInt, max: UInt?, element: ABNFElement) {
		self.min = min
		self.max = max
		if let max {
			precondition(min <= max)
		}
		self.element = element
	}

	public init(_ element: ABNFElement) {
		self.init(min: 1, max: 1, element: element);
	}

	public init(_ option: ABNFOption) {
		self.init(min: 1, max: 1, element: option.element);
	}

	public init(_ group: ABNFGroup) {
		self.init(min: 1, max: 1, element: group.element);
	}

	public init(_ charVal: ABNFCharVal) {
		self.init(min: 1, max: 1, element: charVal.element);
	}

	public init(_ numVal: ABNFNumVal) {
		self.init(min: 1, max: 1, element: numVal.element);
	}

	public init(_ prose: ABNFProseVal) {
		self.init(min: 1, max: 1, element: prose.element);
	}

	public static func < (lhs: ABNFRepetition, rhs: ABNFRepetition) -> Bool {
		// FIXME: This may not be entirely accurate, may need to loop element and compare that
		return lhs.element < rhs.element;
//		return lhs.hashValue < rhs.hashValue;
	}

	public var concatenation: ABNFConcatenation {
		ABNFConcatenation(repetitions: [self])
	}

	public func hasUnion(_ other: ABNFRepetition) -> ABNFRepetition? {
		if self.element == other.element {
			let newMin = Swift.min(self.min, other.min);
			let newMax = self.max==nil || other.max==nil ? nil : Swift.max(self.max!, other.max!);
			return ABNFRepetition(min: newMin, max: newMax, element: self.element)
		}
		if(self.min == other.min && self.max == other.max && self.element != other.element){
			if let replacement = self.element.hasUnion(other.element) {
				return ABNFRepetition(min: self.min, max: self.max, element: replacement)
			}
		}
		return nil;
	}

	public var description: String {
		let repeatStr =
		if let max {
			if min == 1 && max == 1 { "" }
			else if(min == max){ "\(min)" }
			else{ "\(min)*\(max)" }
		} else {
			if min == 0 { "*" }
			else{ "\(min)*" }
		}
		return repeatStr + element.description
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
	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	public var repetition: ABNFRepetition {
		return ABNFRepetition(min: 1, max: 1, element: self)
	}

	public func repeating(_ count: UInt) -> ABNFRepetition {
		precondition(count >= 0)
		return ABNFRepetition(min: count, max: count, element: self)
	}

	public func repeating(_ range: ClosedRange<UInt>) -> ABNFRepetition {
		precondition(range.lowerBound >= 0)
		return ABNFRepetition(min: range.lowerBound, max: range.upperBound, element: self);
	}

	public func repeating(_ range: PartialRangeFrom<UInt>) -> ABNFRepetition {
		precondition(range.lowerBound >= 0)
		return ABNFRepetition(min: range.lowerBound, max: nil, element: self)
	}

	public var description: String {
		switch self {
			case .rulename(let r): return r.description
			case .group(let g): return g.description
			case .option(let o): return o.description
			case .charVal(let c): return c.description
			case .numVal(let n): return n.description
			case .proseVal(let p): return p.description
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

	public func hasUnion(_ other: ABNFElement) -> ABNFElement? {
		switch self {
			case .rulename(let r):
				switch other {
					case .rulename(let ro): if let replacement = r.hasUnion(ro) { return ABNFElement.rulename(replacement) }
					default: return nil;
				}
			case .group(let g):
				switch other {
					case .group(let go): if let replacement = g.hasUnion(go) { return ABNFElement.group(replacement) }
					default: return nil;
				}
			case .option(let o):
				switch other {
					case .option(let oo): if let replacement = o.hasUnion(oo) { return ABNFElement.option(replacement) }
					default: return nil;
				}
			case .charVal(let c):
				switch other {
					case .charVal(let co): if let replacement = c.hasUnion(co) { return ABNFElement.charVal(replacement) }
					default: return nil;
				}
			case .numVal(let n):
				switch other {
					case .numVal(let no): if let replacement = n.hasUnion(no) { return ABNFElement.numVal(replacement) }
					default: return nil;
				}
			case .proseVal(let p):
				switch other {
					case .proseVal(let po): if let replacement = p.hasUnion(po) { return ABNFElement.proseVal(replacement) }
					default: return nil;
				}
		}
		return nil;
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	public static func < (lhs: ABNFGroup, rhs: ABNFGroup) -> Bool {
		return lhs.alternation < rhs.alternation;
	}

	var element: ABNFElement {
		ABNFElement.group(self)
	}

	public var description: String {
		return "(\(alternation.description))"
	}

	var referencedRules: Set<String> {
		return alternation.referencedRules
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		alternation.toFSM(rules: rules)
	}

	public func hasUnion(_ other: ABNFGroup) -> ABNFGroup? {
		return nil
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	public static func < (lhs: ABNFOption, rhs: ABNFOption) -> Bool {
		return lhs.alternation < rhs.alternation;
	}

	var element: ABNFElement {
		ABNFElement.option(self)
	}

	public var description: String {
		return "[\(alternation.description)]"
	}

	var referencedRules: Set<String> {
		return alternation.referencedRules
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		alternation.toFSM(rules: rules).optional()
	}

	public func hasUnion(_ other: ABNFOption) -> ABNFOption? {
		return nil
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	public static func < (lhs: ABNFCharVal, rhs: ABNFCharVal) -> Bool {
		return lhs.sequence < rhs.sequence;
	}

	var element: ABNFElement {
		ABNFElement.charVal(self)
	}

	public var description: String {
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

	public func hasUnion(_ other: ABNFCharVal) -> ABNFCharVal? {
		return nil
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	public static func < (lhs: ABNFNumVal, rhs: ABNFNumVal) -> Bool {
		return lhs.value < rhs.value;
	}

	var element: ABNFElement {
		ABNFElement.numVal(self)
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

	enum Value: Equatable, Comparable, Hashable {
		case sequence(Array<UInt>);
		case range(UInt, UInt);

		public static func < (lhs: Value, rhs: Value) -> Bool {
			// If lhs and rhs are both a sequence, compare their values
			let lhsVal = switch lhs {
				case .sequence(let seq): seq[0];
				case .range(let min, let max): min;
			}
			let rhsVal = switch rhs {
				case .sequence(let seq): seq[0];
				case .range(let min, let max): min;
			}
			return lhsVal < rhsVal;
		}

		func toString(base: Int) -> String {
			switch self {
				case .sequence(let seq): seq.map{ String($0, radix: base) }.joined(separator: ".");
				case .range(let low, let high): String(low, radix: base) + "-" + String(high, radix: base);
			}
		}
	}
	let value: Value;

	public var description: String {
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

	public func hasUnion(_ other: ABNFNumVal) -> ABNFNumVal? {
		// Extract range bounds from self
		let (selfLow, selfHigh): (UInt, UInt)
		switch self.value {
			case .sequence(let seq):
				// Only single-element sequences can be merged
				guard seq.count == 1, let value = seq.first else {
					return nil
				}
				selfLow = value
				selfHigh = value
			case .range(let low, let high):
				selfLow = low
				selfHigh = high
		}

		// Extract range bounds from other
		let (otherLow, otherHigh): (UInt, UInt)
		switch other.value {
			case .sequence(let seq):
				guard seq.count == 1, let value = seq.first else {
					return nil
				}
				otherLow = value
				otherHigh = value
			case .range(let low, let high):
				otherLow = low
				otherHigh = high
		}

		// Check if ranges overlap or are adjacent
		// Overlap: one range’s low is <= other’s high AND one’s high >= other’s low
		// Adjacent: one range’s high + 1 = other’s low OR vice versa
		let overlaps = selfLow <= otherHigh && selfHigh >= otherLow
		let adjacent = selfHigh + 1 == otherLow || otherHigh + 1 == selfLow

		if overlaps || adjacent {
			// Combine into a new range with the min low and max high
			let newLow = min(selfLow, otherLow)
			let newHigh = max(selfHigh, otherHigh)
			return ABNFNumVal(base: self.base, value: .range(newLow, newHigh))
		}

		return nil
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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

	var element: ABNFElement {
		ABNFElement.proseVal(self)
	}

	public static func < (lhs: ABNFProseVal, rhs: ABNFProseVal) -> Bool {
		return lhs.remark < rhs.remark;
	}

	var referencedRules: Set<String> {
		return []
	}

	public var description: String {
		"<\(remark)>"
	}

	func toFSM(rules: Dictionary<String, DFA<Array<UInt>>>) -> DFA<Array<UInt>> {
		fatalError("Cannot convert prose to FSM")
	}

	public func hasUnion(_ other: ABNFProseVal) -> ABNFProseVal? {
		// This never has a union, even with an identical prose-val (probably)
		return nil
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
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
