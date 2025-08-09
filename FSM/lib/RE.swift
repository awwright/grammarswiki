// Structures for parsing and generating most dialects of Regular Expressions

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
	case star(Self)
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
			case .star(let regex): return regex.alphabet
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
			case .star: return 2
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
			case .star: return self
			case .range: return .star(self)
		}
	}

	public func encode(_ dialect: REDialectProtocol) -> String {
		return dialect.encode(self)
	}

	public func toPattern<PatternType>(as: PatternType.Type? = nil) -> PatternType where PatternType: ClosedRangePatternBuilder, PatternType.Symbol == Symbol {
		switch self {
			case .alternation(let array): return PatternType.union(array.map({ $0.toPattern(as: PatternType.self) }))
			case .concatenation(let array): return PatternType.concatenate(array.map({ $0.toPattern(as: PatternType.self) }))
			case .star(let regex): return regex.toPattern(as: PatternType.self).star()
			case .range(let c): return PatternType.union(c.map { PatternType.range($0) })
		}
	}
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
	func encode<Symbol>(_ pattern: REPattern<Symbol>) -> String where Symbol: BinaryInteger & Strideable, Symbol.Stride: SignedInteger
}

/// Most regular expression dialects can be described with the appropriate parameters on this structure
public struct REDialect: REDialectProtocol {
	public let openQuote: String           // Delimiter starting the pattern (e.g., "/" for Perl)
	public let closeQuote: String          // Delimiter ending the pattern (e.g., "/" for Perl)
	public let startAnchor: String         // Delimiter for matching the start of the input, if necessary
	public let endAnchor: String           // Delimiter for matching EOF, if necessary
	public let flags: String               // Flags for the pattern (e.g., "ims" for Perl)
	public let emptyClass: String          // A pattern that matches no characters (not even the empty string)
	public let openGroup: String           // String opening a group (e.g., "(")
	public let closeGroup: String          // String closing a group (e.g., ")")
	public let escapeChar: Character       // Character used for escaping (e.g., "\")
	public let metaCharacters: Set<Character> // Special characters outside character classes (e.g., ".", "*")
	public let openCharClass: String       // String opening a character class (e.g., "[")
	public let closeCharClass: String      // String closing a character class (e.g., "]")
	public let charClassMetaCharacters: Set<Character> // Special characters inside character classes (e.g., "^", "-")
	public let groupTypeIndicators: Set<String> // Indicators after openGroup for special groups (e.g., "?:", "?=")
	public let charClassEscapes: [String: Set<Character>] // Predefined character class escapes (e.g., "\s", "\w")

	public init(openQuote: String, closeQuote: String, startAnchor: String, endAnchor: String, flags: String, openGroup: String, closeGroup: String, emptyClass: String, escapeChar: Character, metaCharacters: Set<Character>, openCharClass: String, closeCharClass: String, charClassMetaCharacters: Set<Character>, groupTypeIndicators: Set<String>, charClassEscapes: [String: Set<Character>]) {
		self.openQuote = openQuote
		self.closeQuote = closeQuote
		self.startAnchor = startAnchor
		self.endAnchor = endAnchor
		self.flags = flags
		self.openGroup = openGroup
		self.closeGroup = closeGroup
		self.emptyClass = emptyClass
		self.escapeChar = escapeChar
		self.metaCharacters = metaCharacters
		self.openCharClass = openCharClass
		self.closeCharClass = closeCharClass
		self.charClassMetaCharacters = charClassMetaCharacters
		self.groupTypeIndicators = groupTypeIndicators
		self.charClassEscapes = charClassEscapes
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
			return array.isEmpty ? "" : array.map(toString).joined(separator: "")
		case .star(let regex):
			return toString(regex) + "*"
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
			if(char < 0x20) {
				"\\x\(String(char, radix: 16, uppercase: true)))"
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
			if(char < 0x20) {
				"\\x\(String(char, radix: 16, uppercase: true)))"
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
		emptyClass: "[^]",
		escapeChar: "\\",
		metaCharacters: Set([".", "^", "$", "*", "+", "?", "{", "[", "]", "\\", "|", "(", ")"]),
		openCharClass: "[",
		closeCharClass: "]",
		charClassMetaCharacters: Set(["^", "-", "]"]),
		groupTypeIndicators: Set(["?:", "?=", "?!", "?<=", "?<!", "?<"]),
		charClassEscapes: [
			"\\d": Set("0123456789"),
			"\\w": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"),
		]
	)

	public static let posixExtended: REDialectProtocol = REDialect(
		openQuote: "/",
		closeQuote: "/",
		startAnchor: "",
		endAnchor: "",
		flags: "",
		openGroup: "(",
		closeGroup: ")",
		emptyClass: "[^]",
		escapeChar: "\\",
		metaCharacters: Set([".", "[", "\\", "(", ")", "|", "*", "+", "?", "{"]),
		openCharClass: "[",
		closeCharClass: "]",
		charClassMetaCharacters: Set(["^", "-", "]"]),
		groupTypeIndicators: Set(),
		charClassEscapes: [
			"[:alnum:]": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
			"[:alpha:]": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
			"[:digit:]": Set("0123456789"),
			// Add more POSIX classes like [:lower:], [:upper:], etc.
		]
	)

	public static let perl: REDialectProtocol = REDialect(
		openQuote: "/",
		closeQuote: "/",
		startAnchor: "^",
		endAnchor: "$",
		flags: "imsx",
		openGroup: "(",
		closeGroup: ")",
		emptyClass: "[^]",
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
		]
	)

	public static let ecmascript: REDialectProtocol = REDialect(
		openQuote: "/",
		closeQuote: "/",
		startAnchor: "^",
		endAnchor: "$",
		flags: "gimsuy",
		openGroup: "(",
		closeGroup: ")",
		emptyClass: "[^]",
		escapeChar: "\\",
		metaCharacters: Set([".", "^", "$", "*", "+", "?", "{", "[", "]", "\\", "|", "(", ")"]),
		openCharClass: "[",
		closeCharClass: "]",
		charClassMetaCharacters: Set(["^", "-", "]"]),
		groupTypeIndicators: Set(["?:", "?=", "?!", "?<=", "?<!", "?<"]),
		charClassEscapes: [
			"\\d": Set("0123456789"),
			"\\w": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"),
		]
	)
}
