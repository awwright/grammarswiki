// Structures for parsing and generating most dialects of Regular Expressions

/// A parser for a common form of regular expressions
public indirect enum REPattern<Symbol>: RegularPattern, ClosedRangePatternBuilder, SymbolClassPatternBuilder, Hashable where Symbol: BinaryInteger & Strideable, Symbol.Stride: SignedInteger {
	public typealias SymbolClass = ClosedRangeAlphabet<Symbol>.SymbolClass
	// An instance of this enum represents a set of sequences of symbols
	public typealias Element = Array<Symbol>

	case alternation([Self])
	case concatenation([Self])
	case star(Self)
	case symbol(Symbol)

	public init() {
		self = .alternation([])
	}

	public init(arrayLiteral: Array<Symbol>...) {
		self = .alternation( arrayLiteral.map{ .concatenation($0.map { Self.symbol($0) }) } )
	}

	public init (_ sequence: any Sequence<Symbol>) {
		self = .concatenation(sequence.map{ Self.symbol($0) })
	}

	/// A set of all the symbols in use in this regex.
	/// Using any symbols outside this set guarantees a transition to the oblivion state (rejection).
	public var alphabet: Set<Symbol> {
		switch self {
			case .alternation(let array): return Set(array.flatMap(\.alphabet))
			case .concatenation(let array): return Set(array.flatMap(\.alphabet))
			case .star(let regex): return regex.alphabet
			case .symbol(let c): return [c]
		}
	}

	public var description: String {
		REDialectBuiltins.ecmascript.encode(self)
	}

	func getPrintable(_ char: Symbol) -> String {
		if(char < 0x20) {
			"\\x\(String(char, radix: 16, uppercase: true)))"
		} else if (char >= 0x20 && char <= 0x7E) {
//			String(UnicodeScalar(char)!)
			String(UnicodeScalar(Int(char))!)
		} else {
			"\\u{\(String(char, radix: 16, uppercase: true)))}"
		}
	}

	var precedence: Int {
		switch self {
			case .alternation: return 4
			case .concatenation: return 3
			case .star: return 2
			case .symbol: return 1
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
			case .symbol: return .star(self)
		}
	}

	public static func symbol(range: SymbolClass) -> Self {
		Self.alternation(range.flatMap { $0.map { Self.symbol($0) } })
	}

	public static func range(_ range: ClosedRange<Symbol>) -> REPattern<Symbol> {
		// FIXME: this should just store a ClosedRange
		Self.alternation(range.map { Self.symbol($0) })
	}

	public func encode(_ dialect: REDialectProtocol) -> String {
		return dialect.encode(self)
	}

	public func toPattern<PatternType>(as: PatternType.Type? = nil) -> PatternType where PatternType: RegularPatternBuilder, PatternType.Symbol == Symbol {
		switch self {
			case .alternation(let array): return PatternType.union(array.map({ $0.toPattern(as: PatternType.self) }))
			case .concatenation(let array): return PatternType.concatenate(array.map({ $0.toPattern(as: PatternType.self) }))
			case .star(let regex): return regex.toPattern(as: PatternType.self).star()
			case .symbol(let c): return PatternType.symbol(c)
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
	let openRegex: String           // Delimiter starting the pattern (e.g., "/" for Perl)
	let closeRegex: String          // Delimiter ending the pattern (e.g., "/" for Perl)
	let flags: String               // Flags for the pattern (e.g., "ims" for Perl)
	let emptyClass: String          // A pattern that matches no characters (not even the empty string)
	let openGroup: String           // String opening a group (e.g., "(")
	let closeGroup: String          // String closing a group (e.g., ")")
	let escapeChar: Character       // Character used for escaping (e.g., "\")
	let metaCharacters: Set<Character> // Special characters outside character classes (e.g., ".", "*")
	let openCharClass: String       // String opening a character class (e.g., "[")
	let closeCharClass: String      // String closing a character class (e.g., "]")
	let charClassMetaCharacters: Set<Character> // Special characters inside character classes (e.g., "^", "-")
	let groupTypeIndicators: Set<String> // Indicators after openGroup for special groups (e.g., "?:", "?=")
	let charClassEscapes: [String: Set<Character>] // Predefined character class escapes (e.g., "\s", "\w")

	public init(openRegex: String, closeRegex: String, flags: String, openGroup: String, closeGroup: String, emptyClass: String, escapeChar: Character, metaCharacters: Set<Character>, openCharClass: String, closeCharClass: String, charClassMetaCharacters: Set<Character>, groupTypeIndicators: Set<String>, charClassEscapes: [String: Set<Character>]) {
		self.openRegex = openRegex
		self.closeRegex = closeRegex
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
			return array.isEmpty ? "\(openGroup)\(closeGroup)" : array.map(toString).joined(separator: "")
		case .star(let regex):
			return toString(regex) + "*"
		case .symbol(let c):
			// Convert symbol to character if possible, for readability
			if let s = UnicodeScalar(Int(c)), metaCharacters.contains(Character(s)) {
				return "\(escapeChar)\(Character(s))"
			} else if let s = UnicodeScalar(Int(c)) {
				return String(Character(s))
			} else {
				return "\\u{\(String(c, radix: 16, uppercase: true))}"
			}
		}
	}
}

public struct REDialectBuiltins {
	static let posixExtended: REDialectProtocol = REDialect(
		openRegex: "",
		closeRegex: "",
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
//			"[:space:]": Set(" \t\n\r\f\v"),
			// Add more POSIX classes like [:lower:], [:upper:], etc.
		]
	)

	static let perl: REDialectProtocol = REDialect(
		openRegex: "/",
		closeRegex: "/",
		flags: "imsx", // Example: case-insensitive, multiline, etc.
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
//			"\\D": Set(Character.min...Character.max).subtracting(Set("0123456789")), // Non-digits
//			"\\s": Set(" \t\n\r\f\v"),                   // Whitespace
//			"\\S": Set(Character.min...Character.max).subtracting(Set(" \t\n\r\f\v")), // Non-whitespace
			"\\w": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"), // Word characters
//			"\\W": Set(Character.min...Character.max).subtracting(Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")), // Non-word
			// Note: \p{} for Unicode properties could be added, but requires a more complex representation
		]
	)

	static let ecmascript: REDialectProtocol = REDialect(
		openRegex: "/",
		closeRegex: "/",
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
//			"\\D": Set(Character.min...Character.max).subtracting(Set("0123456789")),
//			"\\s": Set(" \t\n\r\f\v"),
//			"\\S": Set(Character.min...Character.max).subtracting(Set(" \t\n\r\f\v")),
			"\\w": Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"),
//			"\\W": Set(Character.min...Character.max).subtracting(Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"))
		]
	)
}
