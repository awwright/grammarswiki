// Structures for parsing and generating most dialects of Regular Expressions

/// A parser for a common form of regular expressions
public indirect enum REPattern<Symbol>: RegularPattern, RegularPatternProtocol, Hashable where Symbol: BinaryInteger {
	public typealias Element = Array<Symbol>

	public static var empty: Self { Self.alternation([]) }
	public static var epsilon: Self { Self.concatenation([]) }

	case alternation([Self])
	case concatenation([Self])
	case star(Self)
	case symbol(Symbol)

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

	/// The alphabet, partitioned into sets whose behaviors are equivalent
	/// (i.e. changing the symbol with an equivalent symbol won't change validation)
	public var alphabetPartitions: Set<Set<Symbol>> {
		switch self {
			case .alternation(let array):
				// A union of symbols will always result in an equivalent result, so group symbols in the alternation together
				let symbols: Set<Symbol> = Set(array.compactMap { if case .symbol(let s) = $0 { s } else { nil } })
				let nonsymbols: Array<Set<Set<Symbol>>> = array.compactMap { if case .symbol = $0 { return nil } else { return $0.alphabetPartitions } }
				return alphabetCombine([symbols] + nonsymbols.flatMap { $0 })
			case .concatenation(let array):
				return alphabetCombine(array.flatMap { $0.alphabetPartitions })
			case .star(let regex):
				return regex.alphabetPartitions
			case .symbol(let c):
				// This won't usually be called, unless the regex is literally a single symbol
				return Set([Set([c])])
		}
	}

	public var description: String {
		func toString(_ other: Self) -> String {
			if(other.precedence >= self.precedence) {
				return "(\(other.description))"
			}
			return other.description
		}
		switch self {
			case .alternation(let array):
				if array.isEmpty { return "[^]" }
				// If all in array are symbols, then map to an array of symbols
				if array.allSatisfy({ if case .symbol = $0 { true } else { false }}) {
					return combineRanges(array.map{ if case .symbol(let c) = $0 { c } else { fatalError() } }).joined(separator: "|")
				}
				return array.map(\.description).joined(separator: "|")
			case .concatenation(let array): return array.isEmpty ? "" : array.map(toString).joined(separator: "")
			case .star(let regex): return toString(regex) + "*"
			case .symbol(let c): return getPrintable(c)
		}
	}

	func combineRanges(_ rangeSet: Array<Symbol>) -> [String] {
		// Handle empty set case
		guard !rangeSet.isEmpty else { return [] }

		// Convert set to array and sort by lower bound
		let sortedRanges = rangeSet.sorted().map { $0...$0 }

		// Initialize result with the first range
		var merged: [ClosedRange<Symbol>] = [sortedRanges[0]]

		// Iterate through remaining ranges
		for current in sortedRanges.dropFirst() {
			let last = merged.last!

			// Check if current range is adjacent to or overlaps with the last merged range
			if current.lowerBound <= last.upperBound + 1 {
				// Merge by creating a new range with the same lower bound and the maximum upper bound
				let newUpper = max(last.upperBound, current.upperBound)
				merged[merged.count - 1] = last.lowerBound...newUpper
			} else {
				// If not adjacent or overlapping, add the current range as a new segment
				merged.append(current)
			}
		}

		return merged
			.map { ($0.lowerBound==$0.upperBound) ? getPrintable($0.lowerBound) : ("[" + getPrintable($0.lowerBound) + "-" + getPrintable($0.upperBound) + "]") }
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

	public func encode(dialect: REDialect) -> String {
		func toString(_ other: Self) -> String {
			if(other.precedence >= self.precedence) {
				return "(\(other.encode(dialect: dialect))"
			}
			return other.encode(dialect: dialect)
		}
		switch self {
			case .alternation(let array): return array.isEmpty ? "∅" : array.map(toString).joined(separator: "|")
			case .concatenation(let array): return array.isEmpty ? "ε" : array.map(toString).joined(separator: ".")
			case .star(let regex): return toString(regex) + "*"
			case .symbol(let c): return String(c, radix: 0x10)
		}
	}

	public func toPattern<PatternType>(as: PatternType.Type? = nil) -> PatternType where PatternType: RegularPatternProtocol, PatternType.Symbol == Symbol {
		switch self {
			case .alternation(let array): return PatternType.union(array.map({ $0.toPattern(as: PatternType.self) }))
			case .concatenation(let array): return PatternType.concatenate(array.map({ $0.toPattern(as: PatternType.self) }))
			case .star(let regex): return regex.toPattern(as: PatternType.self).star()
			case .symbol(let c): return PatternType.symbol(c)
		}
	}
}

public struct REString<Symbol> where Symbol: BinaryInteger {
	let dialect: REDialect;
	let pattern: REPattern<Symbol>;

	var description: String {
		return pattern.encode(dialect: dialect)
	}
}

public struct REDialect {
	let openRegex: String           // Delimiter starting the pattern (e.g., "/" for Perl)
	let closeRegex: String          // Delimiter ending the pattern (e.g., "/" for Perl)
	let flags: String               // Flags for the pattern (e.g., "ims" for Perl)
	let openGroup: String           // String opening a group (e.g., "(")
	let closeGroup: String          // String closing a group (e.g., ")")
	let escapeChar: Character       // Character used for escaping (e.g., "\")
	let metaCharacters: Set<Character> // Special characters outside character classes (e.g., ".", "*")
	let openCharClass: String       // String opening a character class (e.g., "[")
	let closeCharClass: String      // String closing a character class (e.g., "]")
	let charClassMetaCharacters: Set<Character> // Special characters inside character classes (e.g., "^", "-")
	let groupTypeIndicators: Set<String> // Indicators after openGroup for special groups (e.g., "?:", "?=")
	let charClassEscapes: [String: Set<Character>] // Predefined character class escapes (e.g., "\s", "\w")
}

public struct REDialectBuiltins {
	static let posixExtended = REDialect(
		openRegex: "",
		closeRegex: "",
		flags: "",
		openGroup: "(",
		closeGroup: ")",
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

	static let perl = REDialect(
		openRegex: "/",
		closeRegex: "/",
		flags: "imsx", // Example: case-insensitive, multiline, etc.
		openGroup: "(",
		closeGroup: ")",
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

	let ecmascript = REDialect(
		openRegex: "/",
		closeRegex: "/",
		flags: "gimsuy", // Example: global, multiline, unicode, etc.
		openGroup: "(",
		closeGroup: ")",
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
