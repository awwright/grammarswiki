
/// A protocol representing a production in an ABNF (Augmented Backus-Naur Form) grammar.
///
/// Conforming types represent syntactic units defined in RFC 5234 that vary with respect to their parent production,
/// such as rules, alternations, or groups. This protocol provides the foundation for parsing ABNF structures by
/// requiring a static `match` method to parse input and extract the corresponding production.
///
/// Conformance to `Equatable`, `Comparable`, `Hashable`, and `CustomStringConvertible` ensures
/// that productions can be compared, sorted, hashed into collections, and converted to human-readable
/// strings, facilitating their use in parsing and grammar manipulation.
///
/// - Note: Implementors should ensure that the `match` method correctly handles the ABNF syntax
///   for their specific production type, returning `nil` if the input cannot be parsed.
public protocol ABNFProduction: Equatable, Comparable, Hashable, CustomStringConvertible {
	// `Element.Element.Stride: SignedInteger` is for iterating over a range of symbols, e.g. (0x20...0x7F)
	/// The type of value that this ABNF is describing
	/// This will typically be ``Array<UInt8>`` or ``Array<Uint32>``
	associatedtype Element: SymbolSequenceProtocol where Element.Element: BinaryInteger & Comparable, Element.Element.Stride: SignedInteger;

	/// A single character of a document that will be matched by the ABNF.
	/// In ABNF itself, this is UInt8 for ASCII characters. For Unicode documents, this will be UInt16 or UInt32.
	typealias Symbol = Element.Element;

	/// Attempts to parse the given input to produce an instance of this production.
	///
	/// - Parameter input: A collection of `UInt8` values representing the input to parse,
	///   typically an ASCII-encoded string.
	/// - Returns: A tuple containing the parsed production and the remaining unparsed input,
	///   or `nil` if parsing fails.
	static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8>

	/// The `description` property required by `CustomStringConvertible` is expected to produce valid ABNF.
	var description: String {get}
}


/// Extension providing a convenience methods for ABNFProduction
extension ABNFProduction {
	/// Parses the entire input into an instance of this production, ensuring no input remains.
	///
	/// - Parameter input: A collection of `UInt8` values representing the full input to parse.
	/// - Returns: The parsed production if successful and the entire input is consumed.
	/// - Throws: `ABNFError.parseFailure` if parsing fails or unparsed input remains.
	/// - Note: This method is stricter than `match`, requiring complete consumption of the input.
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

/// A protocol representing an expression within an ABNF grammar, extending `ABNFProduction`.
///
/// Expressions are the building blocks of ABNF rules, such as alternations, concatenations,
/// repetitions, elements, or groups. This protocol provides properties to access the smallest
/// equivalent representation of the expression in various forms and to check its properties,
/// such as whether it is empty or optional.
///
/// - Note: Conforming types must implement these properties to reflect their structure as
///   defined in RFC 5234, ensuring accurate conversion between equivalent forms.
public protocol ABNFExpression: ABNFProduction {
	/// Get the smallest equivalent ``ABNFAlternation``
	var alternation: ABNFAlternation<Symbol> {get}

	/// Get the smallest equivalent ``ABNFConcatenation``
	var concatenation: ABNFConcatenation<Symbol> {get}

	/// Get the smallest equivalent ``ABNFRepetition``
	var repetition: ABNFRepetition<Symbol> {get}

	/// Get the smallest equivalent ``ABNFElement``
	var element: ABNFElement<Symbol> {get}

	/// Get the smallest equivalent ``ABNFGroup``
	var group: ABNFGroup<Symbol> {get}

	/// If this will accept only the empty string
	var isEmpty: Bool {get}

	/// If this will accept the empty string (maybe among other values)
	var isOptional: Bool {get}

	/// Gets a list of the rules referenced by leaf ``ABNFRulename`` productions.
	/// All of the rules given must be provided to ``toPattern``.
	var referencedRules: Set<String> {get}

	/// Converts the rule to a regular expression capable pattern such as ``DFA`` or ``SimpleRegex``.
	///
	/// For example, `alternation.toPattern(DFA<UInt8>.self, [:])`
	///
	/// - Note: If the rule contains a rulename, the definition must be provided in the parameters, otherwise the function will fail.
	/// 	This list can be acquired from ``referencedRules``
	///
	/// - Parameter rules: A dictionary of resolved rulenames to their DFAs.
	/// - Returns: The DFA equivalent to the definition of this rule.
	func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type?, rules: Dictionary<String, PatternType>) -> PatternType where PatternType.Symbol == Symbol
}

/// Represents a list of rules in an ABNF grammar, as defined in RFC 5234 with Errata 3076.
///
/// A rulelist is the top-level structure in an ABNF document, consisting of one or more rules
/// separated by whitespace and comments.
/// This struct provides methods to convert the rulelist into a dictionary mapping rulenames to
/// rules and to generate finite state machines (FSMs) for parsing.
///
/// Rules within the list may reference each other, and incremental definitions (`=/`)
/// are supported by merging rules with the same name.
///
/// Implements `rulelist` as updated by [errata 3076](<https://www.rfc-editor.org/errata/eid3076>):
///
/// ```abnf
/// rulelist       =  1*( rule / (*WSP c-nl) )
/// ```
public struct ABNFRulelist<S>: ABNFProduction where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	/// The array of rules comprising this rulelist.
	public let rules: [ABNFRule<Symbol>]

	/// Initializes a rulelist with an array of rules.
	///
	/// - Parameter rules: The rules to include in the rulelist.
	public init(rules: [ABNFRule<Symbol>] = []) {
		self.rules = rules
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.rules < rhs.rules;
	}

	/// Converts the rulelist into a dictionary mapping rulenames to their corresponding rules.
	///
	/// Incremental definitions (`=/`) are handled by merging rules with the same rulename using
	/// their union operation, respecting ABNF's case-insensitive rulenames.
	///
	/// - Returns: A dictionary where keys are lowercase rulenames and values are the merged rules.
	public var dictionary: Dictionary<String, ABNFRule<Symbol>> {
		var dict: Dictionary<String, ABNFRule<Symbol>> = [:];
		rules.forEach {
			rule in
			let rulename = rule.rulename.label;
			// FIXME: Test with case-insensitive comparison
			if let previousRule = dict[rulename] {
				// If we've already seen this rule, and it's of the correct type, merge it with the previous definition
				if(rule.definedAs == .incremental){
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

	/// The rules referenced by all the rules in this rule list.
	/// See ``ABNFExpression``.
	///
	/// - Example: To determine the externally defined rules, try
	/// `rulelist.referencedRules.subtracting(rulelist.dictionary.keys)`
	public var referencedRules: Set<String> {
		return Set(rules.flatMap(\.referencedRules))
	}

	public func mapElements<Target>(_ transform: (ABNFElement<Symbol>) -> ABNFElement<Target>) -> ABNFRulelist<Target> {
		let newRules = rules.map { $0.mapElements(transform) };
		return ABNFRulelist<Target>(rules: newRules)
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFRulelist<Target> {
		let newRules = rules.map { $0.mapSymbols(transform) };
		assert(newRules.count == rules.count)
		return ABNFRulelist<Target>(rules: newRules)
	}

	public func mapRulenames(_ transform: (ABNFRulename<Symbol>) -> ABNFRulename<Symbol>) -> ABNFRulelist<Symbol> {
		return ABNFRulelist<Symbol>(rules: rules.map{ $0.mapRulenames(transform) })
	}

	/// Generates a dictionary of deterministic finite automata (DFAs) for each rule in the list.
	///
	/// - Parameter ruleMap: An optional map of pre-resolved rules to their DFAs, used for external references.
	/// - Returns: A dictionary mapping lowercase rulenames to their corresponding DFAs.
	///
	/// - Note: Rules with circular dependencies that cannot be converted to a DFA will be excluded from the return value without any other warning.
	///
	/// - Note: This is a variation of `toPattern` that returns a dictionary, cooresponding with how a rulelist encodes multiple rules.
	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil, rules ruleMap: Dictionary<String, PatternType> = [:]) -> Dictionary<String, PatternType> where PatternType.Symbol == Symbol {
		// Get a Dictionary of each rule by its name to its referencedRules
		let requiredRules = Dictionary<String, Set<String>>(uniqueKeysWithValues: rules.map {
			($0.rulename.label, $0.referencedRules)
		}).filter { $0.1.contains($0.0) == false }

		let rulesByName = self.dictionary;

		var resolvedRules = ruleMap;
		// TODO: Detect head/tail recursion, that can be converted
		main: repeat {
			for (rulename, referenced) in requiredRules {
				if resolvedRules[rulename] == nil && referenced.isSubset(of: resolvedRules.keys) {
					guard let rule = rulesByName[rulename] else {
						fatalError("Could not resolve \(rulename)")
					}
					resolvedRules[rulename] = rule.toPattern(as: PatternType.self, rules: resolvedRules);
					continue main;
				}
			}
			break main;
		} while true;
		return resolvedRules;
	}

	/// Parses an input string into a rulelist.
	///
	/// - Parameter input: A collection of `UInt8` values representing the ABNF grammar text.
	/// - Returns: A tuple containing the parsed rulelist and remaining input, or `nil` if parsing fails.
	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		// Initialize a SubSequence starting at the beginning of input
		var remainder = input[...]
		var rules: [ABNFRule<Symbol>] = []
		while !remainder.isEmpty {
			if let (rule, remainder1) = ABNFRule<Symbol>.match(remainder) {
				// First try to parse as a rule
				rules.append(rule)
				remainder = remainder1
			} else if let (_, remainder1) = Terminals.WSP_star_c_nl.match(remainder) {
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

/// Specifies if the rule was defined using `=` or as an additional alternation `=/`
public enum ABNFDefinedAs: String {
	case equal = "="
	case incremental = "/="

	var description: String {
		switch self {
			case .equal: return "="
			case .incremental: return "/="
		}
	}
}

/// Represents a single rule in an ABNF grammar, as defined in RFC 5234 with Errata 2968.
///
/// A rule consists of a rulename, a definition operator (`=` or `=/`), and an alternation defining
/// its structure. Rules can be converted to finite state machines for parsing and combined with
/// other rules via union operations.
///
/// - Example: `digit = "0" / "1" / "2"` defines a rule named "digit" with an alternation.
///
/// Errata 2968 provides an updates ABNF for this production
/// See <https://www.rfc-editor.org/errata/eid2968>
///
/// ```abnf
/// rule           =  rulename defined-as elements c-nl
/// defined-as     =  *c-wsp ("=" / "=/") *c-wsp
/// elements       =  alternation *WSP
/// alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation)
/// c-nl           =  comment / CRLF ; comment or newline
/// ```
public struct ABNFRule<S>: ABNFProduction where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public let rulename: ABNFRulename<Symbol>;
	public let definedAs: ABNFDefinedAs;
	public let alternation: ABNFAlternation<Symbol>;

	public init(rulename: ABNFRulename<Symbol>, definedAs: ABNFDefinedAs, alternation: ABNFAlternation<Symbol>) {
		self.rulename = rulename
		self.definedAs = definedAs
		self.alternation = alternation
	}

	public init<T>(rulename: ABNFRulename<Symbol>, definedAs: ABNFDefinedAs, expression: T) where T: ABNFExpression, T.Symbol == Symbol {
		self.rulename = rulename
		self.definedAs = definedAs
		self.alternation = expression.alternation
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		if lhs.rulename < rhs.rulename { return true }
		if lhs.rulename > rhs.rulename { return false }
		return lhs.alternation < rhs.alternation;
	}

	public var description: String {
		return "\(rulename.description) \(definedAs.description) \(alternation.description)\r\n"
	}

	public var referencedRules: Set<String> {
		return alternation.referencedRules;
	}

	public func mapRulenames(_ transform: (ABNFRulename<Symbol>) -> ABNFRulename<Symbol>) -> ABNFRule<Symbol> {
		func transformElement(_ element: ABNFElement<Symbol>) -> ABNFElement<Symbol> {
			switch element {
				case .rulename(let rulename): ABNFElement.rulename(transform(rulename))
				default: element
			}
		}
		return ABNFRule<Symbol>(rulename: transform(rulename), definedAs: definedAs, alternation: alternation.mapElements(transformElement))
	}

	public func mapElements<Target>(_ transform: (ABNFElement<Symbol>) -> ABNFElement<Target>) -> ABNFRule<Target> {
		ABNFRule<Target>(rulename: ABNFRulename(label: rulename.label), definedAs: definedAs, alternation: alternation.mapElements(transform))
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFRule<Target> {
		ABNFRule<Target>(rulename: ABNFRulename(label: rulename.label), definedAs: definedAs, alternation: alternation.mapSymbols(transform))
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		alternation.toPattern(as: PatternType.self, rules: rules)
	}

	public func union(_ other: ABNFRule<Symbol>) -> ABNFRule<Symbol> {
		return self.union(other.alternation);
	}

	public func union(_ other: ABNFAlternation<Symbol>) -> ABNFRule<Symbol> {
		return ABNFRule<Symbol>(rulename: rulename, definedAs: definedAs, alternation: self.alternation.union(other))
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		// Parse rulename
		guard let (rulename, remainder1) = ABNFRulename<Symbol>.match(input) else { return nil }

		// Parse defined-as
		guard let (_, remainder2) = Terminals.c_wsp_star.match(remainder1) else { return nil }
		guard let (definedAs, remainder3) = Terminals.defined_as_inner.match(remainder2) else { return nil }
		guard let (_, remainder4) = Terminals.c_wsp_star.match(remainder3) else { return nil }

		var op: ABNFDefinedAs;
		switch(definedAs.count){
			case 1: op = .equal;
			case 2: op = .incremental;
			default: fatalError();
		}

		// Parse alternation
		guard let (alternation, remainder5) = ABNFAlternation<Symbol>.match(remainder4) else { return nil }

		// Parse *WSP c-nl
		guard let (_, remainder) = Terminals.c_wsp_star_c_nl.match(remainder5) else { return nil }

		let rule = ABNFRule(
			rulename: rulename,
			definedAs: op,
			alternation: alternation
		);
		return (rule, remainder);
	}
}

/// Represents a rulename in an ABNF grammar, which is a case-insensitive identifier.
///
/// Rulenames are used to name rules and reference them within expressions. Per RFC 5234,
/// rulenames are case-insensitive, so "DIGIT" and "digit" are equivalent.
///
/// Implements the ABNF `rulename` production:
/// ```abnf
/// rulename       =  ALPHA *(ALPHA / DIGIT / "-")
/// ```
///
/// - Example: In `digit = "0"`, "digit" is the rulename.
public struct ABNFRulename<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public let label: String;

	public init(label: String) {
		self.label = label;
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.label < rhs.label;
	}

	public var alternation: ABNFAlternation<Symbol> {
		return ABNFAlternation(matches: [self.concatenation])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		return ABNFConcatenation<Symbol>(repetitions: [self.repetition])
	}
	public var repetition: ABNFRepetition<Symbol> {
		return ABNFRepetition<Symbol>(min: 1, max: 1, element: self.element)
	}
	public var element: ABNFElement<Symbol> {
		return ABNFElement<Symbol>.rulename(self)
	}
	public var group: ABNFGroup<Symbol> {
		return ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		// At least, not _necessarially_ empty
		return false
	}
	public var isOptional: Bool {
		// Not necessarially empty
		false
	}

	public var description: String {
		return label;
	}

	public var referencedRules: Set<String> {
		return Set([label])
	}

	public func mapElements<Target>(_ transform: (ABNFElement<Symbol>) -> ABNFElement<Target>) -> ABNFRulename<Target> {
		ABNFRulename<Target>(label: label)
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFRulename<Target> {
		ABNFRulename<Target>(label: label)
	}

	/// - rules: A dictionary defining a FSM to use when the given rule is encountered.
	// This is also a clever way of preventing recursive loops
	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type?, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		assert(rules[label] != nil, "Expect rule \(label) to be in rules dictionary, only have \(rules.keys)");
		return rules[label]!
	}

	public func hasUnion(_ other: Self) -> Self? {
		if self == other {
			return self;
		}
		return nil;
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection<UInt8> {
		if let (match, remainder) = Terminals.rulename.match(input) {
			return (ABNFRulename(label: CHAR_string(match)), remainder);
		}else{
			return nil;
		}
	}
}

/// Represents an alternation of concatenations in an ABNF grammar (e.g., `a / b / c`).
///
/// An alternation specifies a choice between multiple concatenations, where any one of them
/// can match the input.
///
/// ```abnf
/// alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation)
/// c-wsp          =  WSP / (c-nl WSP)
/// c-nl           =  comment / CRLF ; comment or newline
/// comment        =  ";" *(WSP / VCHAR) CRLF
/// ```
///
/// - Example: `"0" / "1" / "2"` is an alternation of three concatenations.
public struct ABNFAlternation<S>: ABNFExpression, RegularPatternProtocol where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public static var empty: Self { ABNFAlternation<S>(matches: []) }
	public static var epsilon: Self { ABNFAlternation<S>(matches: [ABNFConcatenation(repetitions: [])]) }

	public let matches: [ABNFConcatenation<Symbol>]

	public init(matches: [ABNFConcatenation<Symbol>]) {
		self.matches = matches
	}

	/// Create an expression that matches exactly a single codepoint
	public init(symbol: Symbol) {
//		if(Int(symbol) >= 0x21 && Int(symbol) <= 0x7E){
//			self.matches = [ABNFConcatenation(repetitions: [ABNFRepetition(min: 1, max: 1, element: ABNFElement.charVal(ABNFCharVal(sequence: [UInt(symbol)])))])];
//		}
		self.matches = [ABNFNumVal<Symbol>(base: .hex, value: .sequence([symbol])).concatenation];
	}

	public init<T>(expression: T) where T: ABNFExpression, T.Symbol == Symbol {
		self = expression.alternation
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.matches < rhs.matches;
	}

	public var alternation: ABNFAlternation<Symbol> {
		if matches.count == 1 && matches[0].repetitions.count == 1 && matches[0].repetitions[0].min == 1 && matches[0].repetitions[0].max == 1, case ABNFElement.group(let group) = matches[0].repetitions[0].repeating {
			return group.alternation
		}
		return self
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		if matches.count == 1 && matches[0].repetitions.count == 1 && matches[0].repetitions[0].min == 1 && matches[0].repetitions[0].max == 1, case ABNFElement.group(let group) = matches[0].repetitions[0].repeating, group.alternation.matches.count==1 {
			return group.alternation.matches[0]
		}
		// If there's only a single match in the concatenation, unwrap it
		return (matches.count == 1) ? matches[0] : ABNFConcatenation<Symbol>(repetitions: [self.repetition])
	}
	public var repetition: ABNFRepetition<Symbol> {
		return ABNFRepetition<Symbol>(min: 1, max: 1, element: self.element)
	}
	public var element: ABNFElement<Symbol> {
		if(matches.count == 1){
			return matches[0].element;
		}
		if(matches.contains(where: { $0.isEmpty })){
			return ABNFElement<Symbol>.option(ABNFOption<Symbol>(optionalAlternation: ABNFAlternation(matches: matches.filter{ !$0.isEmpty })))
		}
		return ABNFElement<Symbol>.group(ABNFGroup<Symbol>(alternation: self))
	}
	public var group: ABNFGroup<Symbol> {
		return ABNFGroup<Symbol>(alternation: self)
	}
	public var isEmpty: Bool {
		return matches.allSatisfy({$0.isEmpty})
	}
	public var isOptional: Bool {
		// If any of the elements can be empty, the whole alternation accepts empty
		matches.contains(where: { $0.isEmpty })
	}

	public var description: String {
		return matches.map { $0.description }.joined(separator: " / ")
	}

	// An implementation for CustomDebugStringConvertible
	public var debugDescription: String {
		return self.description;
	}

	public var referencedRules: Set<String> {
		return matches.reduce(Set(), { $0.union($1.referencedRules) })
	}

	public func mapElements<Target>(_ transform: (ABNFElement<Symbol>) -> ABNFElement<Target>) -> ABNFAlternation<Target> {
		ABNFAlternation<Target>(matches: matches.map{ $0.mapElements(transform) })
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFAlternation<Target> {
		self.mapElements({ $0.mapSymbols(transform) })
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil) -> PatternType where PatternType.Symbol == Symbol {
		PatternType.union(matches.map({ $0.toPattern(as: PatternType.self, rules: [:]) }))
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		PatternType.union(matches.map({ $0.toPattern(as: PatternType.self, rules: rules) }))
	}

	public static func union(_ elements: [Self]) -> Self {
		if(elements.isEmpty){
			return Self.empty
		}else if(elements.count == 1){
			return elements[0]
		}
		return elements[1...].reduce(elements[0], {$0.union($1)})
	}

	public static func concatenate(_ elements: [Self]) -> Self {
		if(elements.isEmpty){
			return Self.epsilon
		}else if(elements.count == 1){
			return elements[0]
		}
		return elements[1...].reduce(elements[0].concatenation, {$0.concatenate($1.concatenation)}).alternation
	}

	public static func symbol(_ element: Symbol) -> ABNFAlternation<S> {
		return ABNFNumVal<Symbol>(base: .hex, value: .sequence([element])).alternation
	}

	public func union(_ other: Self) -> Self {
		// Iterate over other and try to merge it with an existing element if possible, otherwise append to the end.
		var newMatches = self.alternation.matches;
		// For every element in `other`, append it to the end.
		// Then see if the last element can be merged in with an existing element before it.
		// If so, check that element and so on.
		// Try to preserve the order as much as possible because sometimes that is significant.
		other: for otherConcat in other.alternation.matches {
			var i = newMatches.count;
			newMatches.append(otherConcat);
			var search = newMatches.last!;
			var searchIndex = newMatches.count - 1;
			while i > 0 {
				i -= 1;
				if let replacementConcat = newMatches[i].hasUnion(search) {
					newMatches[i] = replacementConcat;
					// remove elements matching `search`
					newMatches.remove(at: searchIndex)
					search = replacementConcat;
					searchIndex = i;
				}
			}
		}
		return ABNFAlternation(matches: newMatches)
	}

	public func concatenate(_ other: Self) -> Self {
		self.concatenation.concatenate(other.concatenation).alternation
	}

	// These map to ABNFElement
	public func optional() -> Self {
		self.repeating(0...1)
	}

	public func plus() -> Self {
		self.repeating(1...)
	}

	// An adaptation of ABNFElement#star
	public func star() -> Self {
		ABNFRepetition(min: 0, max: nil, element: self.element).alternation
	}

	// An adaptation of ABNFElement#repeating
	public func repeating(_ count: Int) -> Self {
		precondition(count >= 0)
		return ABNFRepetition<Symbol>(min: UInt(count), max: UInt(count), element: self.element).alternation
	}

	// An adaptation of ABNFElement#repeating
	public func repeating(_ range: ClosedRange<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		// A simple optimization, in most cases
		if case .group(let group) = self.element, range.lowerBound == 0 && range.upperBound == 1 {
			return ABNFElement.option(ABNFOption(optionalAlternation: group.alternation)).alternation
		}
		return ABNFRepetition<Symbol>(min: UInt(range.lowerBound), max: UInt(range.upperBound), element: self.element).alternation;
	}

	// An adaptation of ABNFElement#repeating
	public func repeating(_ range: PartialRangeFrom<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return ABNFRepetition<Symbol>(min: UInt(range.lowerBound), max: nil, element: self.element).alternation
	}

	public func sorted() -> Self {
		return ABNFAlternation(matches: matches.sorted())
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		var remainder = input[input.startIndex...]
		var concatenations: [ABNFConcatenation<Symbol>] = []

		// Match first concatenation
		guard let (firstConcat, remainder1) = ABNFConcatenation<Symbol>.match(remainder) else { return nil }
		concatenations.append(firstConcat)
		remainder = remainder1

		// Match zero or more *c_wsp "/" *c_wsp concatenation
		let pattern = Terminals.c_wsp_star ++ Terminals["/"] ++ Terminals.c_wsp_star;
		while true {
			// Consume *c_wsp "/" *c_wsp
			guard let (_, remainder2) = pattern.match(remainder) else { break }
			remainder = remainder2

			// Parse concatenation
			guard let (concat, remainder3) = ABNFConcatenation<Symbol>.match(remainder) else { break }
			remainder = remainder3
			concatenations.append(concat)
		}

		return (ABNFAlternation(matches: concatenations), remainder)
	}
}

/// Represents a concatenation of repetitions in an ABNF grammar (e.g., `1*a *b 2c`).
///
/// A concatenation specifies a sequence where all repetitions must match in order.
///
/// ```abnf
/// concatenation  =  repetition *(1*c-wsp repetition)
/// c-wsp          =  WSP / (c-nl WSP)
/// c-nl           =  comment / CRLF ; comment or newline
/// comment        =  ";" *(WSP / VCHAR) CRLF
/// ```
///
/// - Example: `"a" "b"` is a concatenation of two repetitions.
public struct ABNFConcatenation<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public let repetitions: [ABNFRepetition<Symbol>]

	public init(repetitions: [ABNFRepetition<Symbol>]) {
		self.repetitions = repetitions
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.repetitions < rhs.repetitions;
	}

	public var alternation: ABNFAlternation<Symbol> {
		if repetitions.count == 1 && repetitions[0].min == 1 && repetitions[0].max == 1, case ABNFElement.group(let group) = repetitions[0].repeating {
			return group.alternation
		}
		return ABNFAlternation(matches: [self])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		if repetitions.count==1 && repetitions[0].min == 1 && repetitions[0].max == 1, case ABNFElement.group(let group) = repetitions[0].repeating, group.alternation.matches.count == 1, group.alternation.matches[0].repetitions.count==1 {
			return group.alternation.matches[0]
		}
		return self
	}
	public var repetition: ABNFRepetition<Symbol> {
		// If there's only a single repetition in the string, unwrap it
		(repetitions.count == 1) ? repetitions[0] : ABNFRepetition<Symbol>(min: 1, max: 1, element: self.element)
	}
	public var element: ABNFElement<Symbol> {
		if(repetitions.count == 1){
			return repetitions[0].element;
		}
		return ABNFElement<Symbol>.group(ABNFGroup<Symbol>(alternation: ABNFAlternation(matches: [self])))
	}
	public var group: ABNFGroup<Symbol> {
		return ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		repetitions.allSatisfy { $0.isEmpty }
	}
	public var isOptional: Bool {
		repetitions.allSatisfy { $0.isOptional }
	}

	public var description: String {
		return repetitions.map { $0.description }.joined(separator: " ")
	}

	public var referencedRules: Set<String> {
		return repetitions.reduce(Set(), { $0.union($1.referencedRules) })
	}

	public func mapElements<Target>(_ transform: (ABNFElement<Symbol>) -> ABNFElement<Target>) -> ABNFConcatenation<Target> {
		ABNFConcatenation<Target>(repetitions: repetitions.map{ $0.mapElements(transform) })
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFConcatenation<Target> {
		self.mapElements({ $0.mapSymbols(transform) })
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type?, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		PatternType.concatenate(repetitions.map({ $0.toPattern(as: PatternType.self, rules: rules) }))
	}

	public static func concatenate(_ concatenations: [ABNFConcatenation<Symbol>]) -> ABNFConcatenation<Symbol> {
		var newRepetitions: Array<ABNFRepetition<Symbol>> = [];
		for repetition in concatenations.flatMap(\.repetitions) {
			if repetition.isEmpty { continue }
			if let last = newRepetitions.last, let merged = last.hasConcatenation(repetition) {
				newRepetitions[newRepetitions.count - 1] = merged
			} else {
				newRepetitions.append(repetition)
			}
		}
		return ABNFConcatenation(repetitions: newRepetitions)
	}

	public func concatenate(_ other: ABNFConcatenation) -> ABNFConcatenation {
		// See if self last element and other first element have a natural concatenation, and use that if so
		if self.repetitions.isEmpty == false && other.repetitions.isEmpty == false, let merged = self.repetitions.last!.hasConcatenation(other.repetitions.first!) {
			return ABNFConcatenation(repetitions: Array(self.repetitions[0..<self.repetitions.count-1]) + [merged] + other.repetitions[1...])
		}
		return ABNFConcatenation(repetitions: Array(self.repetitions + other.repetitions))
	}

	public func hasUnion(_ other: Self) -> Self? {
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

	public func hasConcatenation(_ other: Self) -> Self? {
		if(repetitions.count == 1 && other.repetitions.count == 1){
			if let replacement = repetitions[0].hasConcatenation(other.repetitions[0]) {
				return replacement.concatenation
			}
		}
		return nil;
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		var reps: [ABNFRepetition<Symbol>] = []

		// Match first repetition
		guard let (firstRep, remainder1) = ABNFRepetition<Symbol>.match(input) else { return nil }
		reps.append(firstRep)

		// Match zero or more (1*c-wsp repetition)
		var remainder = remainder1
		while true {
			// Consume whitespace
			guard let (_, remainder2) = Terminals.c_wsp_plus.match(remainder) else { break }
			guard let (rep, remainder3) = ABNFRepetition<Symbol>.match(remainder2) else { break }
			remainder = remainder3
			reps.append(rep)
		}

		return (ABNFConcatenation(repetitions: reps), remainder)
	}
}

/// Represents a repetition of an element in an ABNF grammar (e.g., `*element` or `3*5element`).
///
/// Repetitions specify how many times an element can or must occur, with optional minimum and
/// maximum bounds. They exist in between ``ABNFConcatenation`` and ``ABNFElement``.
/// An element with no repetition modifiers exists as an ABNFRepetition with a min and max of 1.
///
/// ```abnf
/// repetition     =  [repeat] element
/// repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)
/// ```
///
/// - Example: `2*3"a"` means "a" must appear between 2 and 3 times.
public struct ABNFRepetition<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public let min: UInt
	public let max: UInt?
	public let repeating: ABNFElement<Symbol>

	public init(min: UInt, max: UInt?, element: ABNFElement<Symbol>) {
		self.min = min
		self.max = max
		if let max {
			precondition(min <= max)
		}
		self.repeating = element
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		// FIXME: This may not be entirely accurate, may need to loop element and compare that
		return lhs.repeating < rhs.repeating;
//		return lhs.hashValue < rhs.hashValue;
	}

	public var alternation: ABNFAlternation<Symbol> {
		ABNFAlternation(matches: [self.concatenation])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		ABNFConcatenation(repetitions: [self])
	}
	public var repetition: ABNFRepetition<Symbol> {
		if min == 1 && max == 1, case ABNFElement.group(let group) = repeating, group.alternation.matches.count == 1, group.alternation.matches[0].repetitions.count==1 {
			return group.alternation.matches[0].repetitions[0]
		}
		return self
	}
	public var element: ABNFElement<Symbol> {
		(min == 1 && max == 1) ? repeating : ABNFElement.group(self.group)
	}
	public var group: ABNFGroup<Symbol> {
		return ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		max == 0 || repeating.isEmpty
	}
	public var isOptional: Bool {
		min == 0 || repeating.isOptional
	}

	public func hasUnion(_ other: Self) -> Self? {
		if self.repeating == other.repeating {
			let newMin = Swift.min(self.min, other.min);
			let newMax = self.max==nil || other.max==nil ? nil : Swift.max(self.max!, other.max!);
			return ABNFRepetition(min: newMin, max: newMax, element: self.repeating)
		}
		if(self.min == other.min && self.max == other.max && self.repeating != other.repeating){
			if let replacement = self.repeating.hasUnion(other.repeating) {
				return ABNFRepetition(min: self.min, max: self.max, element: replacement)
			}
		}
		return nil;
	}

	public func hasConcatenation(_ other: Self) -> Self? {
		if self.min == 1 && self.max == 1, let merged = self.repeating.hasConcatenation(other.repeating) {
			return merged.repetition
		}
		if self.repeating == other.repeating {
			let newMin = self.min + other.min;
			let newMax = self.max==nil || other.max==nil ? nil : (self.max! + other.max!);
			return ABNFRepetition(min: newMin, max: newMax, element: self.repeating)
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
		return repeatStr + repeating.description
	}

	public var referencedRules: Set<String> {
		return repeating.referencedRules
	}

	public func mapElements<Target>(_ transform: (ABNFElement<Symbol>) -> ABNFElement<Target>) -> ABNFRepetition<Target> {
		return ABNFRepetition<Target>(min: min, max: max, element: transform(repeating))
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFRepetition<Target> {
		self.mapElements({ $0.mapSymbols(transform) })
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		if let max = self.max {
			repeating.toPattern(as: PatternType.self, rules: rules).repeating(Int(min)...Int(max))
		} else {
			repeating.toPattern(as: PatternType.self, rules: rules).repeating(Int(min)...)
		}
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		if let (match, remainder1) = Terminals.repeat_range.match(input) {
			// (*DIGIT "*" *DIGIT) element
			// match = *DIGIT "*"
			let (minStr, _) = Terminals.DIGIT_star.match(match)!
			let (maxStr, remainder2) = Terminals.DIGIT_star.match(remainder1)!
			guard let (element, remainder) = ABNFElement<Symbol>.match(remainder2) else { return nil }
			return (ABNFRepetition(min: DIGIT_value(minStr), max: maxStr.isEmpty ? nil : DIGIT_value(maxStr), element: element), remainder)
		} else if let (exactStr, remainder1) = Terminals.repeat_min.match(input) {
			// 1*DIGIT element
			let count = DIGIT_value(exactStr);
			guard let (element, remainder) = ABNFElement<Symbol>.match(remainder1) else { return nil }
			return (ABNFRepetition(min: count, max: count, element: element), remainder)
		} else {
			// element
			guard let (element, remainder) = ABNFElement<Symbol>.match(input) else { return nil }
			return (ABNFRepetition(min: 1, max: 1, element: element), remainder)
		}
	}
}

/// An enumeration representing a basic element in an ABNF grammar.
///
/// Elements are the atomic units of ABNF expressions, such as rulenames, groups, or terminal values.
///
/// ```abnf
/// element        =  rulename / group / option / char-val / num-val / prose-val
/// ```
///
/// - Note: The order of cases in `match` reflects ABNF parsing precedence.
public enum ABNFElement<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	case rulename(ABNFRulename<Symbol>)
	case group(ABNFGroup<Symbol>)
	case option(ABNFOption<Symbol>)
	case charVal(ABNFCharVal<Symbol>)
	case numVal(ABNFNumVal<Symbol>)
	case proseVal(ABNFProseVal<Symbol>)

	public var alternation: ABNFAlternation<Symbol> {
		// If we're getting a group, unwrap the group
		if case .group(let group) = self {
			return group.alternation
		}
		return ABNFAlternation(matches: [self.concatenation])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		if case .group(let group) = self, group.alternation.matches.count == 1 {
			return group.alternation.matches[0]
		}
		return ABNFConcatenation(repetitions: [self.repetition])
	}
	public var repetition: ABNFRepetition<Symbol> {
		if case .group(let group) = self, group.alternation.matches.count == 1 && group.alternation.matches[0].repetitions.count == 1 {
			return group.alternation.matches[0].repetitions[0]
		}
		return ABNFRepetition<Symbol>(min: 1, max: 1, element: self)
	}
	public var element: ABNFElement<Symbol> {
		if case .group(let group) = self {
			return group.element
		}
		return self
	}
	public var group: ABNFGroup<Symbol> {
		return ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		switch self {
			case .rulename(let r): return r.isEmpty
			case .group(let g): return g.isEmpty
			case .option(let o): return o.isEmpty
			case .charVal(let c): return c.isEmpty
			case .numVal(let n): return n.isEmpty
			case .proseVal(let p): return p.isEmpty
		}
	}
	public var isOptional: Bool {
		switch self {
			case .rulename(let r): return r.isOptional
			case .group(let g): return g.isOptional
			case .option(let o): return o.isOptional
			case .charVal(let c): return c.isOptional
			case .numVal(let n): return n.isOptional
			case .proseVal(let p): return p.isOptional
		}
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

	public var referencedRules: Set<String> {
		switch self {
			case .rulename(let r): return r.referencedRules
			case .group(let g): return g.referencedRules
			case .option(let o): return o.referencedRules
			case .charVal(let c): return c.referencedRules
			case .numVal(let n): return n.referencedRules
			case .proseVal(let p): return p.referencedRules
		}
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFElement<Target> {
		switch self {
			case .rulename(let s): return ABNFElement<Target>.rulename(s.mapSymbols(transform))
			case .group(let s): return ABNFElement<Target>.group(s.mapSymbols(transform))
			case .option(let s): return ABNFElement<Target>.option(s.mapSymbols(transform))
			case .charVal(let s): return ABNFElement<Target>.charVal(s.mapSymbols(transform))
			case .numVal(let s): return ABNFElement<Target>.numVal(s.mapSymbols(transform))
			case .proseVal(let s): return ABNFElement<Target>.proseVal(s.mapSymbols(transform))
		}
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		switch self {
			case .rulename(let s): return s.toPattern(as: PatternType.self, rules: rules)
			case .group(let s): return s.toPattern(as: PatternType.self, rules: rules)
			case .option(let s): return s.toPattern(as: PatternType.self, rules: rules)
			case .charVal(let s): return s.toPattern(as: PatternType.self, rules: rules)
			case .numVal(let s): return s.toPattern(as: PatternType.self, rules: rules)
			case .proseVal(let s): return s.toPattern(as: PatternType.self, rules: rules)
		}
	}

	public func hasUnion(_ other: Self) -> Self? {
		// TODO: numVal can sometimes be unioned with charVal
		// TODO: group and option too
		switch self {
			case .rulename(let s): if case .rulename(let o) = other, let r = s.hasUnion(o) { return ABNFElement.rulename(r) }
			case .group(let s): if case .group(let o) = other, let r = s.hasUnion(o) { return ABNFElement.group(r) }
			case .option(let s): if case .option(let o) = other, let r = s.hasUnion(o) { return ABNFElement.option(r) }
			case .charVal(let s): if case .charVal(let o) = other, let r = s.hasUnion(o) { return ABNFElement.charVal(r) }
			case .numVal(let s): if case .numVal(let o) = other, let r = s.hasUnion(o) { return ABNFElement.numVal(r) }
			case .proseVal(let s): if case .proseVal(let o) = other, let r = s.hasUnion(o) { return ABNFElement.proseVal(r) }
		}
		return nil;
	}

	public func hasConcatenation(_ other: Self) -> Self? {
		switch self {
			case .group(let s): if case .group(let o) = other, let r = s.hasConcatenation(o) { return ABNFElement.group(r) }
			case .charVal(let s): if case .charVal(let o) = other, let r = s.hasConcatenation(o) { return ABNFElement.charVal(r) }
			case .numVal(let s): if case .numVal(let o) = other, let r = s.hasConcatenation(o) { return ABNFElement.numVal(r) }
			default: return nil;
		}
		return nil;
	}

	// These functions can go here because they tend to up-cast an ABNFElement to an ABNFRepetition
	// These are also wrapped in ABNFAlteration because that implements everything for RegularPatternProtocol conformance
	public func optional() -> ABNFRepetition<Symbol> {
		self.repeating(0...1)
	}

	public func plus() -> ABNFRepetition<Symbol> {
		self.repeating(1...)
	}

	public func star() -> ABNFRepetition<Symbol> {
		ABNFRepetition(min: 0, max: nil, element: self)
	}

	public func repeating(_ count: Int) -> ABNFRepetition<Symbol> {
		precondition(count >= 0)
		return ABNFRepetition<Symbol>(min: UInt(count), max: UInt(count), element: self)
	}

	public func repeating(_ range: ClosedRange<Int>) -> ABNFRepetition<Symbol> {
		precondition(range.lowerBound >= 0)
		// A simple optimization, in most cases
		if case .group(let group) = self, range.lowerBound == 0 && range.upperBound == 1 {
			return ABNFElement<Symbol>.option(ABNFOption<Symbol>(optionalAlternation: group.alternation)).repetition
		}
		return ABNFRepetition<Symbol>(min: UInt(range.lowerBound), max: UInt(range.upperBound), element: self.element);
	}

	public func repeating(_ range: PartialRangeFrom<Int>) -> ABNFRepetition<Symbol> {
		precondition(range.lowerBound >= 0)
		return ABNFRepetition<Symbol>(min: UInt(range.lowerBound), max: nil, element: self)
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		if let (r, remainder) = ABNFRulename<Symbol>.match(input) { return (.rulename(r), remainder) }
		if let (g, remainder) = ABNFGroup<Symbol>.match(input) { return (.group(g), remainder) }
		if let (o, remainder) = ABNFOption<Symbol>.match(input) { return (.option(o), remainder) }
		if let (c, remainder) = ABNFCharVal<Symbol>.match(input) { return (.charVal(c), remainder) }
		if let (n, remainder) = ABNFNumVal<Symbol>.match(input) { return (.numVal(n), remainder) }
		if let (p, remainder) = ABNFProseVal<Symbol>.match(input) { return (.proseVal(p), remainder) }
		return nil
	}
}

// group          =  "(" *c-wsp alternation *c-wsp ")"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
// comment        =  ";" *(WSP / VCHAR) CRLF
public struct ABNFGroup<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	// A group always unwraps to an alternation
	public let alternation: ABNFAlternation<Symbol>

	public init(alternation: ABNFAlternation<Symbol>) {
		self.alternation = alternation;
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.alternation < rhs.alternation;
	}

	// The `alternation` property functions exactly the same
	//public var alternation: ABNFAlternation {
	// ABNFAlternation(matches: [self.concatenation])
	//}
	public var concatenation: ABNFConcatenation<Symbol> {
		self.alternation.concatenation;
	}
	public var repetition: ABNFRepetition<Symbol> {
		self.alternation.concatenation.repetition
	}
	public var element: ABNFElement<Symbol> {
		self.alternation.concatenation.repetition.element;
	}
	public var group: ABNFGroup {
		self
	}
	public var isEmpty: Bool {
		alternation.isEmpty
	}
	public var isOptional: Bool {
		alternation.isOptional
	}

	public var description: String {
		return "(\(alternation.description))"
	}

	public var referencedRules: Set<String> {
		return alternation.referencedRules
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFGroup<Target> {
		ABNFGroup<Target>(alternation: alternation.mapSymbols(transform))
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type?, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		alternation.toPattern(as: PatternType.self, rules: rules)
	}

	public func hasUnion(_ other: Self) -> Self? {
		return nil
	}

	public func hasConcatenation(_ other: Self) -> Self? {
		// If both alternations have a single element, they can be joined
		if (self.alternation.matches.count == 1 && other.alternation.matches.count == 1){
			return ABNFGroup(alternation: ABNFAlternation(matches: [ABNFConcatenation(repetitions: self.alternation.matches[0].repetitions + other.alternation.matches[0].repetitions)]))
		}
		return nil
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		let prefix = Terminals["("] ++ Terminals.c_wsp_star;
		guard let (_, remainder1) = prefix.match(input) else { return nil }
		guard let (alternation, remainder2) = ABNFAlternation<Symbol>.match(remainder1) else { return nil }
		let suffix = Terminals.c_wsp_star ++ Terminals[")"];
		guard let (_, remainder) = suffix.match(remainder2) else { return nil }
		return (ABNFGroup(alternation: alternation), remainder)
	}
}

// option         =  "[" *c-wsp alternation *c-wsp "]"
// c-wsp          =  WSP / (c-nl WSP)
// c-nl           =  comment / CRLF ; comment or newline
public struct ABNFOption<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public let optionalAlternation: ABNFAlternation<Symbol>

	public init(optionalAlternation: ABNFAlternation<Symbol>) {
		self.optionalAlternation = optionalAlternation
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.optionalAlternation < rhs.optionalAlternation;
	}

	public var alternation: ABNFAlternation<Symbol> {
		ABNFAlternation(matches: [self.concatenation])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		ABNFConcatenation(repetitions: [self.repetition])
	}
	public var repetition: ABNFRepetition<Symbol> {
		ABNFRepetition(min: 1, max: 1, element: self.element)
	}
	public var element: ABNFElement<Symbol> {
		ABNFElement<Symbol>.option(self)
	}
	public var group: ABNFGroup<Symbol> {
		ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		optionalAlternation.isEmpty
	}
	public var isOptional: Bool {
		// Defitionally
		true
	}

	public var description: String {
		return "[\(optionalAlternation.description)]"
	}

	public var referencedRules: Set<String> {
		return optionalAlternation.referencedRules
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFOption<Target> {
		ABNFOption<Target>(optionalAlternation: optionalAlternation.mapSymbols(transform))
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type?, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		optionalAlternation.toPattern(as: PatternType.self, rules: rules).optional()
	}

	public func hasUnion(_ other: Self) -> Self? {
		return nil
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		let prefix_pattern = Terminals["["] ++ Terminals.c_wsp_star;
		guard let (_, remainder1) = prefix_pattern.match(input) else { return nil }
		guard let (alternation, remainder2) = ABNFAlternation<Symbol>.match(remainder1) else { return nil }
		let suffix_pattern = Terminals.c_wsp_star ++ Terminals["]"];
		guard let (_, remainder) = suffix_pattern.match(remainder2) else { return nil }
		return (ABNFOption(optionalAlternation: alternation), remainder)
	}
}

// char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
public struct ABNFCharVal<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public let sequence: Array<S>

	public init<T>(sequence: T) where T: Sequence, T.Element == Symbol {
		self.sequence = Array(sequence)
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.sequence < rhs.sequence;
	}

	public var alternation: ABNFAlternation<Symbol> {
		ABNFAlternation(matches: [self.concatenation])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		ABNFConcatenation(repetitions: [self.repetition])
	}
	public var repetition: ABNFRepetition<Symbol> {
		ABNFRepetition(min: 1, max: 1, element: self.element)
	}
	public var element: ABNFElement<Symbol> {
		ABNFElement<Symbol>.charVal(self)
	}
	public var group: ABNFGroup<Symbol> {
		ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		sequence.isEmpty
	}
	public var isOptional: Bool {
		sequence.isEmpty
	}

	public var description: String {
		sequence.forEach { assert($0 < 128); }
		let seq = sequence.map{ UInt8($0) }
		return "\"\(CHAR_string(seq))\""
	}

	public var referencedRules: Set<String> {
		return []
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFCharVal<Target> {
		ABNFCharVal<Target>(sequence: sequence.map(transform))
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		return PatternType.concatenate(sequence.map {
			codepoint in
			// Check for uppercase letters, also accept lowercase versions
			if(codepoint >= 0x41 && codepoint <= 0x5A) { return PatternType.union([ PatternType.symbol(codepoint), PatternType.symbol(codepoint+0x20) ]) }
			else if(codepoint >= 0x61 && codepoint <= 0x7A) { return PatternType.union([ PatternType.symbol(codepoint-0x20), PatternType.symbol(codepoint) ]) }
			else { return PatternType.symbol(codepoint) }
		})
	}

	public func hasUnion(_ other: Self) -> Self? {
		return nil
	}

	public func hasConcatenation(_ other: Self) -> Self? {
		return ABNFCharVal(sequence: self.sequence + other.sequence)
	}

	public static func match<T>(_ input: T) -> (Self, T.SubSequence)? where T: Collection, T.Element == UInt8 {
		guard let (_, remainder1) = Terminals.DQUOTE.match(input) else { return nil }
		let charPattern = DFA<Array<UInt8>>(range: 0x20...0x21) | DFA<Array<UInt8>>(range: 0x23...0x7E)
		guard let (chars, remainder2) = charPattern.star().match(remainder1) else { return nil }
		guard let (_, remainder) = Terminals.DQUOTE.match(remainder2) else { return nil }
		return (ABNFCharVal<Symbol>(sequence: chars.map { Symbol($0) }), remainder)
	}
}

// num-val        =  "%" (bin-val / dec-val / hex-val)
public struct ABNFNumVal<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public static func == (lhs: ABNFNumVal, rhs: ABNFNumVal) -> Bool {
		return lhs.base == rhs.base && lhs.value == rhs.value
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.value < rhs.value;
	}

	public var alternation: ABNFAlternation<Symbol> {
		ABNFAlternation(matches: [self.concatenation])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		ABNFConcatenation(repetitions: [self.repetition])
	}
	public var repetition: ABNFRepetition<Symbol> {
		ABNFRepetition(min: 1, max: 1, element: self.element)
	}
	public var element: ABNFElement<Symbol> {
		ABNFElement<Symbol>.numVal(self)
	}
	public var group: ABNFGroup<Symbol> {
		ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		// You can't actually notate an empty num_val sequence in ABNF, but if you could, it would be empty
		switch self.value {
			case .sequence(let seq): return seq.isEmpty
			case .range: return false
		}
	}
	public var isOptional: Bool {
		switch self.value {
			case .sequence(let seq): return seq.isEmpty
			case .range: return false
		}
	}

	enum Base: Int {
		case bin = 2;
		case dec = 10;
		case hex = 16;

		func parseNum<T> (_ input: T) -> Symbol? where T: Collection, T.Element == UInt8 {
			return switch self {
				case Base.bin: Symbol(BIT_value(input));
				case Base.dec: Symbol(DIGIT_value(input));
				case Base.hex: Symbol(HEXDIG_value(input));
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
		case sequence(Array<Symbol>);
		case range(Symbol, Symbol);

		static func < (lhs: Self, rhs: Self) -> Bool {
			switch (lhs, rhs) {
				case (.sequence(let l), .sequence(let r)): return l < r
				case (.range(let lMin, let lMax), .range(let rMin, let rMax)):
					return lMin < rMin || (lMin == rMin && lMax < rMax)
				case (.sequence(let l), .range(let rMin, _)): return l[0] < rMin
				case (.range(let lMin, _), .sequence(let r)): return lMin < r[0]
			}
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

	public var referencedRules: Set<String> {
		return []
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFNumVal<Target> {
		let base: ABNFNumVal<Target>.Base = switch self.base {
			case .bin: .bin;
			case .dec: .dec;
			case .hex: .hex
		}
		return switch self.value {
			case .sequence(let seq): ABNFNumVal<Target>(base: base, value: ABNFNumVal<Target>.Value.sequence(seq.map(transform)))
			case .range(let low, let high): ABNFNumVal<Target>(base: base, value: ABNFNumVal<Target>.Value.range(transform(low), transform(high)))
		}
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type? = nil, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		switch self.value {
			case .sequence(let seq): return PatternType.concatenate(seq.map { PatternType.symbol($0) })
			case .range(let low, let high): return PatternType.union((low...high).map { PatternType.symbol($0) })
		}
	}

	public func hasUnion(_ other: Self) -> Self? {
		// Extract range bounds from self
		let (selfLow, selfHigh): (Symbol, Symbol)
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
		let (otherLow, otherHigh): (Symbol, Symbol)
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

	public func hasConcatenation(_ other: Self) -> Self? {
		// This never has a union, even with an identical prose-val (probably)
		if case .sequence(let selfSeq) = self.value, case .sequence(let otherSeq) = other.value {
			return ABNFNumVal(base: base, value: .sequence(selfSeq + otherSeq))
		}
		// One of the two values is a range, which isn't concatenated back into itself
		return nil;
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
		var values: [Symbol] = [firstStr]
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
			return (ABNFNumVal<Symbol>(base: base, value: Value.range(Symbol(values.first!), Symbol(endStr))), remainder6)
		}

		return (ABNFNumVal<Symbol>(base: base, value: Value.sequence(values)), remainder)
	}
}

// prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"
public struct ABNFProseVal<S>: ABNFExpression where S: Comparable & BinaryInteger & Hashable, S.Stride: SignedInteger {
	public typealias Element = Array<S>;

	public let remark: String;

	public init(remark: String) {
		self.remark = remark;
		//self.length = remark.count;
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.remark < rhs.remark;
	}

	public var alternation: ABNFAlternation<Symbol> {
		ABNFAlternation(matches: [self.concatenation])
	}
	public var concatenation: ABNFConcatenation<Symbol> {
		ABNFConcatenation(repetitions: [self.repetition])
	}
	public var repetition: ABNFRepetition<Symbol> {
		ABNFRepetition(min: 1, max: 1, element: self.element)
	}
	public var element: ABNFElement<Symbol> {
		ABNFElement<Symbol>.proseVal(self)
	}
	public var group: ABNFGroup<Symbol> {
		ABNFGroup<Symbol>(alternation: self.alternation)
	}
	public var isEmpty: Bool {
		// Not necessarially empty
		false
	}
	public var isOptional: Bool {
		// Not necessarially empty
		false
	}

	public var description: String {
		"<\(remark)>"
	}

	public var referencedRules: Set<String> {
		return []
	}

	public func mapSymbols<Target>(_ transform: (Symbol) -> Target) -> ABNFProseVal<Target> {
		return ABNFProseVal<Target>(remark: self.remark)
	}

	public func toPattern<PatternType: RegularPatternProtocol>(as: PatternType.Type?, rules: Dictionary<String, PatternType> = [:]) -> PatternType where PatternType.Symbol == Symbol {
		fatalError("Cannot convert prose to FSM")
	}

	public func hasUnion(_ other: Self) -> Self? {
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

// A dictionary of all of the rules that ABNF provides by default
public struct ABNFBuiltins<Dfn: RegularPatternProtocol> where Dfn.Symbol: BinaryInteger, Dfn.Symbol.Stride: SignedInteger {
	typealias Symbol = Dfn.Symbol

	public static var ALPHA : Dfn { Dfn.range(0x41...0x5A) | Dfn.range(0x61...0x7A) }; // %x41-5A / %x61-7A   ; A-Z / a-z
	public static var BIT   : Dfn { Dfn.symbol(0x30) |  Dfn.symbol(0x31) }; // "0" / "1"
	public static var CHAR  : Dfn { Dfn.range(0x1...0x7F) }; // %x01-7F
	public static var CR    : Dfn { Dfn.symbol(0xD) }; // %x0D
	public static var CRLF  : Dfn { Dfn.symbol(0xD) ++ Dfn.symbol(0xA) }; // CR LF
	public static var CTL   : Dfn { Dfn.range(0...0x1F) | Dfn.symbol(0x7F) }; // %x00-1F / %x7F
	public static var DIGIT : Dfn { Dfn.range(0x30...0x39) }; // %x30-39
	public static var DQUOTE: Dfn { Dfn.symbol(0x22) }; // %x22
	public static var HEXDIG: Dfn { DIGIT | Dfn.range(0x41...0x46) | Dfn.range(0x61...0x66) }; // DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
	public static var HTAB  : Dfn { Dfn.symbol(0x9) }; // %x09
	public static var LF    : Dfn { Dfn.symbol(0xA) }; // %x0A
	public static var LWSP  : Dfn { (WSP | (CRLF ++ WSP)).star() }; // *(WSP / CRLF WSP)
	public static var OCTET : Dfn { Dfn.range(0...0xFF) }; // %x00-FF
	public static var SP    : Dfn { Dfn.symbol(0x20) }; // %x20
	public static var VCHAR : Dfn { Dfn.range(0x21...0x7E) }; // %x21-7E
	public static var WSP   : Dfn { SP | HTAB }; // SP / HTAB

	public static var dictionary: Dictionary<String, Dfn> {
		[
			"ALPHA" : ABNFBuiltins.ALPHA,
			"BIT"   : ABNFBuiltins.BIT,
			"CHAR"  : ABNFBuiltins.CHAR,
			"CR"    : ABNFBuiltins.CR,
			"CRLF"  : ABNFBuiltins.CRLF,
			"CTL"   : ABNFBuiltins.CTL,
			"DIGIT" : ABNFBuiltins.DIGIT,
			"DQUOTE": ABNFBuiltins.DQUOTE,
			"HEXDIG": ABNFBuiltins.HEXDIG,
			"HTAB"  : ABNFBuiltins.HTAB,
			"LF"    : ABNFBuiltins.LF,
			"LWSP"  : ABNFBuiltins.LWSP,
			"OCTET" : ABNFBuiltins.OCTET,
			"SP"    : ABNFBuiltins.SP,
			"VCHAR" : ABNFBuiltins.VCHAR,
			"WSP"   : ABNFBuiltins.WSP,
		]
	}
}

/// A set of values for parsing ABNF
/// Instances of ABNF documents themselves can't refer to these
struct Terminals {
	typealias Rule = DFA<Array<UInt8>>;

	static let ALPHA  = ABNFBuiltins<Rule>.ALPHA;
	static let BIT    = ABNFBuiltins<Rule>.BIT;
	static let CHAR   = ABNFBuiltins<Rule>.CHAR;
	static let CR     = ABNFBuiltins<Rule>.CR;
	static let CRLF   = ABNFBuiltins<Rule>.CRLF;
	static let CTL    = ABNFBuiltins<Rule>.CTL;
	static let DIGIT  = ABNFBuiltins<Rule>.DIGIT;
	static let DQUOTE = ABNFBuiltins<Rule>.DQUOTE;
	static let HEXDIG = ABNFBuiltins<Rule>.HEXDIG;
	static let HTAB   = ABNFBuiltins<Rule>.HTAB;
	static let LF     = ABNFBuiltins<Rule>.LF;
	static let LWSP   = ABNFBuiltins<Rule>.LWSP;
	static let OCTET  = ABNFBuiltins<Rule>.OCTET;
	static let SP     = ABNFBuiltins<Rule>.SP;
	static let VCHAR  = ABNFBuiltins<Rule>.VCHAR;
	static let WSP    = ABNFBuiltins<Rule>.WSP;

	// And now various other expressions used within the rules...
	// c-wsp          =  WSP / (c-nl WSP)
	static let c_wsp : Rule = WSP | (c_nl ++ WSP)
	static let c_wsp_plus: Rule = c_wsp.plus()
	static let c_wsp_star: Rule = c_wsp.star()

	// c-nl           =  comment / CRLF ; comment or newline
	static let c_nl  : Rule = comment | CRLF;
	static let WSP_star_c_nl: Rule = WSP.star() ++ c_nl
	static let c_wsp_star_c_nl: Rule = c_wsp_star ++ c_nl

	// comment        =  ";" *(WSP / VCHAR) CRLF
	static let comment : Rule = Rule([[0x3B]]) ++ (WSP | VCHAR).star() ++ CRLF

	// The important part of defined-as
	// defined-as     =  *c-wsp ("=" / "=/") *c-wsp
	static let defined_as_inner = Terminals["="] | Terminals["=/"];

	static let rulename = ALPHA ++ (ALPHA | DIGIT | Terminals["-"]).star();
	static let repeat_min = DIGIT.plus();
	static let repeat_range = DIGIT.star() ++ Terminals["*"];
	static let DIGIT_star = DIGIT.star();

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
