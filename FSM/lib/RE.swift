// Structures for parsing and generating most dialects of Regular Expressions
// TODO: Implement a repetition finder:
// - Sort a concatenation by its elements, to find ones that are identical.
// - If there's any duplicates, determine if there's subsequences that are duplicates that are next to each other.
// - Collapse these into a single, repeated element. It's OK to use a naive algorithm for now, something is better than nothing.

/// A parser for a common form of regular expressions
public indirect enum REPattern<Symbol>: ClosedRangePatternBuilder, SymbolClassPatternBuilder, Hashable where Symbol: BinaryInteger & Strideable, Symbol.Stride: SignedInteger {
	public static func range(_ range: ClosedRange<Symbol>) -> REPattern<Symbol> {
		.range([range])
	}
	
	public typealias SymbolClass = ClosedRangeAlphabet<Symbol>.SymbolClass
	// An instance of this enum represents a set of sequences of symbols
	public typealias Element = Array<Symbol>

	// MARK: Properties
	case alternation([Self])
	case concatenation([Self])
	case repetition(Self, min: Int, max: Int?)
	case range(SymbolClass)

	public init() {
		self = .alternation([])
	}

	public init(arrayLiteral: Array<Symbol>...) {
		self = .alternation( arrayLiteral.map{ .concatenation($0.map { Self.symbol($0) }) } )
	}

	public init (_ sequence: any Sequence<Symbol>) {
		self = .concatenation(sequence.map{ Self.symbol($0) })
	}

	// MARK: Static functions
	public static func symbol(_ element: Symbol) -> REPattern<Symbol> {
		.range([element...element])
	}

	public static func symbol(range: ClosedRangeAlphabet<Symbol>.SymbolClass) -> REPattern<Symbol> {
		Self.range(range)
	}

	// MARK: Computed properties
	/// A set of all the symbols in use in this regex.
	/// Using any symbols outside this set guarantees a transition to the oblivion state (rejection).
	public var alphabet: Set<Symbol> {
		switch self {
			case .alternation(let array): return Set(array.flatMap(\.alphabet))
			case .concatenation(let array): return Set(array.flatMap(\.alphabet))
			// TODO: Return empty if max == 0
			case .repetition(let regex, _, _): return regex.alphabet
			case .range(let c): return Set(c.flatMap { $0 }) // Cast ClosedRange to a Set
		}
	}

	public var description: String {
		REDialectBuiltins.swift.encode(self)
	}

	var precedence: Int {
		switch self {
			case .alternation: return 4
			case .concatenation: return 3
			case .repetition: return 2
			case .range: return 1
		}
	}

	static public func union(_ elements: [Self]) -> Self {
		let array = elements.flatMap({ if case .alternation(let v) = $0 { v } else { [$0] } })
		if array.count == 1 { return array[0] }
		var contains: Set<Self> = Set()
		return .alternation(array.filter { $0 != .empty && contains.insert($0).inserted })
	}

	static public func concatenate(_ elements: [Self]) -> Self {
		let array = elements.flatMap({ if case .concatenation(let v) = $0 { v } else { [$0] } })
		// Concatenation with empty is empty
		if (array.contains { $0 == .empty }) { return .empty }
		if array.count == 1 { return array[0] }
		return .concatenation(array)
	}

	static public func star(_ element: Self) -> Self {
		.repetition(element, min: 0, max: nil)
	}

	public func union(_ other: Self) -> Self {
		let lhs = if case .alternation(let array) = self { array } else { [self] }
		let rhs = if case .alternation(let array) = other { array } else { [other] }
		let array = lhs + rhs
		if array.count == 1 { return array[0] }
		var contains: Set<Self> = Set()
		return .alternation(array.filter { contains.insert($0).inserted })
	}

	public func concatenate(_ other: Self) -> Self {
		let lhs = if case .concatenation(let array) = self { array } else { [self] }
		let rhs = if case .concatenation(let array) = other { array } else { [other] }
		let array = lhs + rhs
		// Concatenation with empty is empty
		if (array.contains { $0 == .empty }) { return .empty }
		if array.count == 1 { return array[0] }
		return .concatenation(array)
	}

	public func star() -> Self {
		switch self {
			case .alternation(let array): return array.isEmpty ? .concatenation([]) : .star(self)
			case .concatenation(let array): return array.isEmpty ? self : .star(self)
			case .repetition: return .star(self)
			case .range: return .star(self)
		}
	}

	/// A default implementation of ``RegularPatternBuilder.optional()``
	/// - Returns: A pattern that unions this pattern with epsilon.
	public func optional() -> Self {
		return .repetition(self, min: 0, max: 1)
	}

	/// Implements one or more repetitions as this pattern followed by zero or more repetitions.
	/// - Returns: A pattern equivalent to `self{0,1}`.
	public func plus() -> Self {
		return .repetition(self, min: 1, max: nil)
	}

	/// Returns a DFA accepting exactly `count` repetitions of its language.
	///
	/// Implements ``RegularPatternBuilder``
	public func repeating(_ count: Int) -> Self {
		precondition(count >= 0)
		return .repetition(self, min: count, max: count)
	}

	/// Returns a DFA accepting between `range.lowerBound` and `range.upperBound` repetitions.
	public func repeating(_ range: ClosedRange<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return .repetition(self, min: range.lowerBound, max: range.upperBound)
	}

	/// Returns a DFA accepting `range.lowerBound` or more repetitions.
	///
	/// Implements ``RegularPatternBuilder``
	public func repeating(_ range: PartialRangeFrom<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return .repetition(self, min: range.lowerBound, max: nil)
	}

	public func encode(_ dialect: REDialectProtocol) -> String {
		return dialect.encode(self)
	}

	/// Normalize a regular expression with repeated expressions in a concatenation to use a repetition instead.
	/// Examples:
	/// ```
	/// AA* -> A+
	/// AAA* -> A{2,}
	/// AA? -> A{1,2}
	/// (A|) -> A?
	/// (AB)(AB) -> (AB){2}
	/// ```

	public func factorRepetition() -> REPattern {
		func collapseRepetitions(_ patterns: [REPattern]) -> REPattern {
			if patterns.isEmpty { return Self.concatenation([]) }
			let n = patterns.count
			// Try to find subsequence repetition
			// A subsequence longer than half of the sequence can't possibly be repeated, so stop trying there
			for k in 1...n/2 {
				if n % k == 0 {
					let count = n / k
					let prefix = Array(patterns[0..<k])
					var allEqual = true
					for i in 1..<count {
						let segment = Array(patterns[i*k..<(i+1)*k])
						if segment != prefix {
							allEqual = false;
							break
						}
					}
					if allEqual {
						let sub = prefix.count == 1 ? prefix[0] : Self.concatenation(prefix)
						return .repetition(sub, min: count, max: count);
					}
				}
			}
			// No subsequence repetition, collapse consecutive repetitions of the same pattern
			func effectiveRep(_ p: REPattern) -> (inner: REPattern, min: Int, max: Int?) {
				if case .repetition(let i, let m, let x) = p {
					return (i, m, x)
				} else if case .alternation(let array) = p, array.count == 2, array[0] == .concatenation([]), array[1] != .concatenation([]) {
					return (array[1], 0, 1)
				} else {
					return (p, 1, 1)
				}
			}
			var result: [REPattern] = []
			var i = 0
			while i < patterns.count {
				let (inner, min, max) = effectiveRep(patterns[i])
				var totalMin = min
				var totalMax: Int? = max
				i += 1
				while i < patterns.count {
					let (nextInner, nextMin, nextMax) = effectiveRep(patterns[i])
					if nextInner != inner { break }
					totalMin += nextMin
					if totalMax == nil || nextMax == nil {
						totalMax = nil
					} else {
						totalMax! += nextMax!
					}
					i += 1
				}
				if totalMin == 1 && totalMax == 1 {
					result.append(inner)
				} else {
					result.append(.repetition(inner, min: totalMin, max: totalMax))
				}
			}
			return Self.concatenation(result);
		}

		switch self {
			case .alternation(let parts):
				return .alternation(parts.flatMap {
					if case .alternation(let inner) = $0 { return inner }
					else { return [$0] }
				}.map { $0.factorRepetition() })

			case .concatenation(let parts):
				let flat = parts.flatMap {
					if case .concatenation(let inner) = $0 { return inner }
					else { return [$0] }
				}.map { $0.factorRepetition() }

				return collapseRepetitions(flat);

			case .repetition(let inner, let min, let max):
				return .repetition(inner.factorRepetition(), min: min, max: max)

			case .range:
				return self
		}

	}

	public func toPattern<PatternType>(as: PatternType.Type? = nil) -> PatternType where PatternType: ClosedRangePatternBuilder, PatternType.Symbol == Symbol {
		switch self {
			case .alternation(let array): return PatternType.union(array.map({ $0.toPattern(as: PatternType.self) }))
			case .concatenation(let array): return PatternType.concatenate(array.map({ $0.toPattern(as: PatternType.self) }))
			case .repetition(let regex, let min, let max):
				return if let max { regex.toPattern(as: PatternType.self).repeating(min...max) } else { regex.toPattern(as: PatternType.self).repeating(min...) }
			case .range(let c): return PatternType.union(c.map { PatternType.range($0) })
		}
	}
}

public struct REDialactCollection {
	public let languages: Array<String>;
	public let engines: Array<String>;

	public struct Constructor: Identifiable {
		public let id: String;
		public let label: String;
		public let language: String;
		public let engine: String;
		public let reference: String;
		public let description: (REPattern<UInt32>) -> String;
	}
	public let constructors: Array<Constructor>;

	public init(languages: Array<String>, engines: Array<String>, constructors: Array<Constructor>) {
		self.languages = languages
		self.engines = engines
		self.constructors = constructors
	}

	public init(_ constructors: Constructor...) {
		let languages = Set(constructors.map { $0.language }).sorted()
		let engines = Set(constructors.map { $0.engine }).sorted()
		self.languages = languages
		self.engines = engines
		self.constructors = constructors
	}

	// Return a subset of this REDialectCollection with only the engines and constructors usable from the given language
	public func filter(language: String?) -> Self {
		guard let language, language != "" else { return self }
		let filteredLanguages = languages.filter { $0 == language }
		let filteredConstructors = constructors.filter { $0.language == language }
		// Filter to engines used by at least one of the remaining constructors
		let filteredEngines = engines.filter { engineName in filteredConstructors.contains(where: { $0.engine == engineName }) }
		return REDialactCollection(languages: filteredLanguages, engines: filteredEngines, constructors: filteredConstructors)
	}

	public static var builtins = REDialactCollection.init(
		Constructor(
			id: "swift",
			label: "Swift Raw Regular Expression",
			language: "Swift",
			engine: "Swift",
			reference: "",
			description: { REDialectBuiltins.swift.encode($0) }
		),
		Constructor(
			id: "swift,literal",
			label: "Swift Regex Literal",
			language: "Swift",
			engine: "Swift",
			reference: "",
			// FIXME: Escape this string
			description: { "/" + REDialectBuiltins.swift.encode($0) + "/" }
		),
		Constructor(
			id: "swift,nswliteral",
			label: "Swift Insiginficant-Whitespace Regex Literal",
			language: "Swift",
			engine: "Swift",
			reference: "",
			description: { _ in "fatalError(\"Unimplemented\")" }
		),
		Constructor(
			id: "swift,NSRegularExpression",
			label: "Swift NSRegularExpression string",
			language: "Swift",
			engine: "Swift",
			reference: "https://developer.apple.com/documentation/foundation/nsregularexpression",
			description: { "\"\(REDialectBuiltins.swift.encode($0))\"" }
		),
		Constructor(
			id: "swift,NSRegularExpression,init",
			label: "Swift NSRegularExpression constructor",
			language: "Swift",
			engine: "NSRegularExpression",
			reference: "https://developer.apple.com/documentation/foundation/nsregularexpression",
			// FIXME: Escape this string
			description: { "try NSRegularExpression(pattern: \"\(REDialectBuiltins.swift.encode($0))\");" }
		),
		Constructor(
			id: "posixe",
			label: "POSIX Extended pattern",
			language: "Shell",
			engine: "POSIX Extended",
			reference: "",
			description: { REDialectBuiltins.posixExtended.encode($0) }
		),
		Constructor(
			id: "posixe,grep",
			label: "grep -e <pattern>",
			language: "Shell",
			engine: "POSIX Extended",
			reference: "",
			// FIXME: Escape this string
			description: { "grep -e \"\(REDialectBuiltins.posixExtended.encode($0))\"" }
		),
	);
}

public struct REString<Symbol> where Symbol: Strideable & BinaryInteger, Symbol.Stride: SignedInteger {
	let dialect: REDialectProtocol;
	let pattern: REPattern<Symbol>;

	var description: String {
		return pattern.encode(dialect)
	}
}

public protocol REDialectProtocol {
	/// Encodes a given REPattern into a string representation using this dialect.
	/// This is the "embedding" form, the form that matches a whole string and can be placed inside a group.
	/// Generally, you will want to use one of the forms below instead.
	func encode<Symbol>(_ pattern: REPattern<Symbol>) -> String where Symbol: BinaryInteger & Strideable, Symbol.Stride: SignedInteger

	/// Get a regular expression where the expression will match the input string exactly.
	/// In many regular expression dialects, this means adding anchoring characters like `($^)`.
	func encodeWhole<Symbol>(_ pattern: REPattern<Symbol>) -> String

	/// Get a regular expression where the input regular expression has to match some substring of the input.
	/// This is the default mode for many regular expression dialects; but if not, then
	func encodeFind<Symbol>(_ pattern: REPattern<Symbol>) -> String
}

/// Most regular expression dialects can be described with the appropriate parameters on this structure
/// TODO: Change these to use patterns to describe the class of strings that denote each rule.
/// Use a placeholder character like the SUB character (0x1A) to denote the inside.
public struct REDialect: REDialectProtocol {
	public let openQuote: String           // Delimiter starting the pattern (e.g., "/" for Perl)
	public let closeQuote: String          // Delimiter ending the pattern (e.g., "/" for Perl)
	public let startAnchor: String         // Delimiter for matching the start of the input, if necessary
	public let endAnchor: String           // Delimiter for matching EOF, if necessary
	public let flags: String               // Flags for the pattern (e.g., "ims" for Perl)
	public let emptyClass: String          // A pattern that matches no characters (not even the empty string)
	public let allClass: String            // A pattern that matches all characters. Note that "." usually excludes CR/LF.
	public let xEscape: Bool             // Use \x to escape characters < 0x20
	public let openGroup: String           // String opening a group (e.g., "(")
	public let closeGroup: String          // String closing a group (e.g., ")")
	public let escapeChar: Character       // Character used for escaping (e.g., "\")
	public let metaCharacters: Set<Character> // Special characters outside character classes (e.g., ".", "*")
	public let openCharClass: String       // String opening a character class (e.g., "[")
	public let closeCharClass: String      // String closing a character class (e.g., "]")
	public let charClassMetaCharacters: Set<Character> // Special characters inside character classes (e.g., "^", "-")
	public let groupTypeIndicators: Set<String> // Indicators after openGroup for special groups (e.g., "?:", "?=")
	public let charClassEscapes: [String: Set<Character>] // Predefined character class escapes (e.g., "\s", "\w")
	public let isFind: Bool // If `escape` creates a "Find" regex, as opposed to a "whole" regex

	public init(openQuote: String, closeQuote: String, startAnchor: String, endAnchor: String, flags: String, openGroup: String, closeGroup: String, allClass: String, emptyClass: String, xEscape: Bool, escapeChar: Character, metaCharacters: Set<Character>, openCharClass: String, closeCharClass: String, charClassMetaCharacters: Set<Character>, groupTypeIndicators: Set<String>, charClassEscapes: [String: Set<Character>], isFind: Bool) {
		self.openQuote = openQuote
		self.closeQuote = closeQuote
		self.startAnchor = startAnchor
		self.endAnchor = endAnchor
		self.flags = flags
		self.openGroup = openGroup
		self.closeGroup = closeGroup
		self.allClass = allClass
		self.emptyClass = emptyClass
		self.xEscape = xEscape;
		self.escapeChar = escapeChar
		self.metaCharacters = metaCharacters
		self.openCharClass = openCharClass
		self.closeCharClass = closeCharClass
		self.charClassMetaCharacters = charClassMetaCharacters
		self.groupTypeIndicators = groupTypeIndicators
		self.charClassEscapes = charClassEscapes
		self.isFind = isFind
	}

	public func encode<Symbol>(_ pattern: REPattern<Symbol>) -> String where Symbol: BinaryInteger & Strideable, Symbol.Stride: SignedInteger {
		func toString(_ other: REPattern<Symbol>) -> String {
			if other.precedence >= pattern.precedence {
				return "\(openGroup)\(other.encode(self))\(closeGroup)"
			}
			return other.encode(self)
		}

		switch pattern {
		case .alternation(let array):
			if array.isEmpty { return emptyClass }
			return array.map(\.description).joined(separator: "|")
		case .concatenation(let array):
			if array.isEmpty { return "" }
			var collapsed: [(REPattern<Symbol>, Int)] = []
			for pat in array {
				if let last = collapsed.last, last.0 == pat {
					collapsed[collapsed.count-1].1 += 1
				} else {
					collapsed.append((pat, 1))
				}
			}
			return collapsed.map { (pat, count) in
				let str = toString(pat)
				if count == 1 {
					return str
				} else {
					return "\(str){\(count)}"
				}
			}.joined(separator: "")
		case .repetition(let regex, let min, let max):
			let str = toString(regex);
			if min == 0 && max == 1 {
				return "\(str)?"
			} else if min == 0 && max == nil {
				return "\(str)*"
			} else if min == 1 && max == nil {
				return "\(str)+"
			} else if let max {
				if min == max {
					return "\(str){\(min)}"
				} else {
					return "\(str){\(min),\(max)}"
				}
			} else {
				return "\(str){\(min),}"
			}
		case .range(let list):
			if list.count == 1 && list[0].lowerBound == list[0].upperBound {
				return charPrintable(list[0].lowerBound)
			}
			return openCharClass + list.map { r in
				r.lowerBound == r.upperBound ? charClassPrintable(r.lowerBound) : "\(charClassPrintable(r.lowerBound))-\(charClassPrintable(r.upperBound))"
			}.joined(separator: "") + closeCharClass
		}

		func charPrintable(_ char: Symbol) -> String {
			//if metaCharacters.contains(Int(char)) {
			//	"\(escapeChar)\(Character(char))"
			//} else
			if(xEscape && char < 0x20) {
				"\\x0\(String(char, radix: 16, uppercase: true))"
			} else if(xEscape && char < 0x20) {
				"\\x\(String(char, radix: 16, uppercase: true))"
			} else if metaCharacters.contains(Character((UnicodeScalar(Int(char))!))) {
				"\\\(Character(UnicodeScalar(Int(char))!))"
			} else if (char >= 0x20 && char <= 0x7E) {
				//			String(UnicodeScalar(char)!)
				String(UnicodeScalar(Int(char))!)
			} else {
				"\\u{\(String(char, radix: 16, uppercase: true))}"
			}
		}

		// The characters that may need escaping in a character class may be different than elsewhere
		// e.g. "-" doesn't need to be escaped outside a character class,
		// and "[" does't need to be escaped inside one.
		func charClassPrintable(_ char: Symbol) -> String {
			if(xEscape && char < 0x10) {
				"\\x0\(String(char, radix: 16, uppercase: true))"
			} else if(xEscape && char < 0x20) {
				"\\x\(String(char, radix: 16, uppercase: true))"
			} else if charClassMetaCharacters.contains(Character((UnicodeScalar(Int(char))!))) {
				"\\\(Character(UnicodeScalar(Int(char))!))"
			} else if (char >= 0x20 && char <= 0x7E) {
				//			String(UnicodeScalar(char)!)
				String(UnicodeScalar(Int(char))!)
			} else {
				"\\u{\(String(char, radix: 16, uppercase: true))}"
			}

		}
	}

	public func encodeWhole<Symbol>(_ pattern: REPattern<Symbol>) -> String {
		if isFind {
			startAnchor + openGroup + encode(pattern) + closeGroup + endAnchor;
		} else {
			encode(pattern);
		}
	}

	public func encodeFind<Symbol>(_ pattern: REPattern<Symbol>) -> String {
		if isFind {
			encode(pattern);
		} else {
			allClass + openGroup + encode(pattern) + closeGroup + allClass;
		}
	}
}

public struct REDialectBuiltins {
	public static let swift: REDialectProtocol = REDialect(
		openQuote: "/",
		closeQuote: "/",
		startAnchor: "^",
		endAnchor: "$",
		flags: "gimsuy", // Example: global, multiline, unicode, etc.
		openGroup: "(",
		closeGroup: ")",
		allClass: "(.|\n|\r)",
		emptyClass: "^(?!.*)",
		xEscape: false,
		escapeChar: "\\",
		metaCharacters: Set([".", "^", "$", "*", "+", "?", "{", "[", "]", "\\", "|", "(", ")"]),
		openCharClass: "[",
		closeCharClass: "]",
		charClassMetaCharacters: Set(["^", "-", "[", "]"]),
		groupTypeIndicators: Set(["?:", "?=", "?!", "?<=", "?<!", "?<"]),
		charClassEscapes: [
			"\\d": Set("0123456789"),
			"\\w": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"),
		],
		isFind: true,
	)

	public static let posixExtended: REDialectProtocol = REDialect(
		openQuote: "/",
		closeQuote: "/",
		startAnchor: "",
		endAnchor: "",
		flags: "",
		openGroup: "(",
		closeGroup: ")",
		allClass: "[^]",
		emptyClass: "[]",
		xEscape: true,
		escapeChar: "\\",
		metaCharacters: Set([".", "[", "\\", "(", ")", "|", "*", "+", "?", "{", "}", "^", "$"]),
		openCharClass: "[",
		closeCharClass: "]",
		charClassMetaCharacters: Set(["^", "-", "]"]),
		groupTypeIndicators: Set(),
		charClassEscapes: [
			"[:alnum:]": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
			"[:alpha:]": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
			"[:digit:]": Set("0123456789"),
			// Add more POSIX classes like [:lower:], [:upper:], etc.
		],
		isFind: true,
	)

	public static let perl: REDialectProtocol = REDialect(
		openQuote: "/",
		closeQuote: "/",
		startAnchor: "^",
		endAnchor: "$",
		flags: "imsx",
		openGroup: "(",
		closeGroup: ")",
		allClass: "[^]",
		emptyClass: "[]",
		xEscape: true,
		escapeChar: "\\",
		metaCharacters: Set([".", "^", "$", "*", "+", "?", "{", "[", "]", "\\", "|", "(", ")"]),
		openCharClass: "[",
		closeCharClass: "]",
		charClassMetaCharacters: Set(["^", "-", "]"]),
		groupTypeIndicators: Set(["?:", "?=", "?!", "?<=", "?<!", "?>", "?P<"]),
		charClassEscapes: [
			"\\d": Set("0123456789"),                    // Digits
			"\\w": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"), // Word characters
			// Note: \p{} for Unicode properties could be added, but requires a more complex representation
		],
		isFind: true,
	)

	public static let ecmascript: REDialectProtocol = REDialect(
		openQuote: "/",
		closeQuote: "/",
		startAnchor: "^",
		endAnchor: "$",
		flags: "gimsuy",
		openGroup: "(",
		closeGroup: ")",
		allClass: "[^]",
		emptyClass: "[]",
		xEscape: true,
		escapeChar: "\\",
		metaCharacters: Set([".", "^", "$", "*", "+", "?", "{", "[", "]", "\\", "|", "(", ")"]),
		openCharClass: "[",
		closeCharClass: "]",
		charClassMetaCharacters: Set(["^", "-", "]"]),
		groupTypeIndicators: Set(["?:", "?=", "?!", "?<=", "?<!", "?<"]),
		charClassEscapes: [
			"\\d": Set("0123456789"),
			"\\w": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"),
		],
		isFind: true,
	)
}
