/// Declares a type of sequence that has an empty sequence, and can be built from the empty sequence by appending elements.
/// The elements of this sequence are called Symbol. They must be usable as keys for a ``Dictionary``, so Symbol depends on ``Hashable``.
public protocol SymbolSequenceProtocol: Sequence where Element: Hashable {
	typealias Symbol = Element;

	/// An instance of this type that has no elements
	static var empty: Self { get }

	/// Return a new sequence concatenated with the given sequence
	/// This is usually implemented by Array and String.
	static func + (_: Self, _: Self) -> Self;

	/// Return a new sequence with the given alement appended
	func appending(_: Symbol) -> Self;
}

/// A protocol allowing the construction of regular languages.
/// It is very flexible and allows constructing a regular expression of any type from any other conforming type.
///
/// Default implementations for most methods are provided, except for:
/// - static var empty
/// - static var epsilon
/// - static func union
/// - static func concatenate
/// - func optional
/// - func toPattern
public protocol RegularPatternProtocol: Equatable {
	/// The type of sequence this pattern operates over, such as an array of symbols.
	associatedtype Element: SymbolSequenceProtocol;

	/// The type of individual symbols in the sequence, which must be hashable for set-like operations.
	typealias Symbol = Element.Symbol;

	/// An instance representing the empty language, which accepts no sequences.
	static var empty: Self { get }

	/// An instance representing the language that accepts only the empty sequence (epsilon).
	static var epsilon: Self { get }

	/// Creates a pattern accepting the union of the languages defined by the given patterns.
	/// - Parameter elements: An array of patterns to union with this one.
	/// - Returns: A pattern accepting any sequence accepted by at least one of the input patterns.
	static func union(_ elements: [Self]) -> Self
	//static func union<T>(_ elements: T) -> Self where T: Sequence, T.Element==Symbol

	/// Creates a pattern accepting the concatenation of the languages defined by the given patterns.
	/// - Parameter elements: An array of patterns to concatenate with this one.
	/// - Returns: A pattern accepting sequences formed by appending sequences from each pattern in order.
	static func concatenate(_ elements: [Self]) -> Self
	//static func concatenate<T>(_ elements: T) -> Self where T: Sequence, T.Element==Symbol

	/// Creates a pattern that accepts only a single input with one element of the given symbol
	/// - Parameter element: The symbol to turn into a regular expression
	/// - Returns: A pattern accepting the given symbol
	static func symbol(_ element: Symbol) -> Self

	/// Returns a pattern to also accept the empty sequence, making it optional.
	/// - Returns: A pattern that accepts either the empty sequence or any sequence this pattern accepts.
	func optional() -> Self

	/// Creates a pattern accepting one or more repetitions of this pattern's language.
	/// - Returns: A pattern equivalent to concatenating this pattern with itself zero or more additional times.
	func plus() -> Self

	/// Creates a pattern accepting zero or more repetitions of this pattern's language (Kleene star).
	/// - Returns: A pattern equivalent to the empty sequence or any finite concatenation of this pattern.
	func star() -> Self

	/// Creates a pattern accepting exactly `count` repetitions of this pattern's language.
	/// - Parameter count: The exact number of repetitions (must be non-negative).
	/// - Returns: A pattern accepting sequences formed by concatenating this pattern `count` times.
	func repeating(_ count: Int) -> Self

	/// Creates a pattern accepting between `range.lowerBound` and `range.upperBound` repetitions.
	/// - Parameter range: A closed range specifying the minimum and maximum repetitions.
	/// - Returns: A pattern accepting sequences formed by concatenating this pattern between `lowerBound` and `upperBound` times.
	func repeating(_ range: ClosedRange<Int>) -> Self

	/// Creates a pattern accepting `range.lowerBound` or more repetitions.
	/// - Parameter range: A range specifying the minimum number of repetitions.
	/// - Returns: A pattern accepting sequences formed by concatenating this pattern at least `lowerBound` times.
	func repeating(_ range: PartialRangeFrom<Int>) -> Self

	// Interfaces to implement later, depending on need
	//func intersection(_ other: Self) -> Self
	//func subtracting(_ other: Self) -> Self
	//func symmetricDifference(_ other: Self) -> Self

	//func mapSymbol<Target>(_: (Symbol) throws -> Target) rethrows -> Target;
}

infix operator ++: AdditionPrecedence;

extension RegularPatternProtocol {
	/// Convenience method to union this pattern with another.
	/// - Parameter other: The pattern to union with.
	/// - Returns: A pattern accepting sequences from either this pattern or `other`.
	public func union(_ other: Self) -> Self {
		Self.union([self, other])
	}

	/// Convenience method to concatenate this pattern with another.
	/// - Parameter other: The pattern to concatenate with.
	/// - Returns: A pattern accepting sequences formed by appending `other`’s sequences to this pattern’s.
	public func concatenate(_ other: Self) -> Self {
		Self.concatenate([self, other])
	}

	/// A default implementation of ``RegularPatternProtocol.optional()``
	/// - Returns: A pattern that unions this pattern with epsilon.
	public func optional() -> Self {
		return Self.epsilon.union(self)
	}

	/// Implements one or more repetitions as this pattern followed by zero or more repetitions.
	/// - Returns: A pattern equivalent to `self{0,1}`.
	public func plus() -> Self {
		return self.concatenate(self.star())
	}

	/// Returns a DFA accepting exactly `count` repetitions of its language.
	public func repeating(_ count: Int) -> Self {
		precondition(count >= 0)
		return Self.concatenate(Array(repeating: self, count: count))
	}

	/// Returns a DFA accepting between `range.lowerBound` and `range.upperBound` repetitions.
	public func repeating(_ range: ClosedRange<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return Self.concatenate(Array(repeating: self, count: range.lowerBound) + Array(repeating: self.optional(), count: Int(range.upperBound-range.lowerBound)));
	}

	/// Returns a DFA accepting `range.lowerBound` or more repetitions.
	public func repeating(_ range: PartialRangeFrom<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return Self.concatenate(Array(repeating: self, count: range.lowerBound) + [self.star()])
	}

	// Operator shortcuts

	/// Concatenation operator
	// The selection of symbol for operator is fraught because most of these symbols have been used for most different things
	// String concatenation is slightly different than language concatenation,
	// I want to suggest the string concatenation of the cross product of any string from ordered pair languages
	public static func ++ (lhs: Self, rhs: Self) -> Self {
		return Self.concatenate([lhs, rhs]);
	}
	/// Union/alternation
	// This is another case where the operator is confusing.
	// SQL uses || for string concatenation, but in C it would suggest union.
	// You could also use + to suggest union, but many languages including Swift use it for string concatenation.
	public static func | (lhs: Self, rhs: Self) -> Self {
		return Self.union([lhs, rhs])
	}
}

// For symbol types that support it, allow generating a range of symbols
extension RegularPatternProtocol where Symbol: Comparable & Strideable, Symbol.Stride: SignedInteger {
	/// Creates a pattern that accepts any single symbol within the given range (exclusive upper bound).
	/// - Parameter range: The range of symbols (e.g., `0...10`). 
	public static func range(_ range: ClosedRange<Symbol>) -> Self {
		return Self.union(range.map{ Self.symbol($0) });
	}

	/// Creates a pattern that accepts any single symbol within the given range (exclusive upper bound).
	/// - Parameter range: The range of symbols (e.g., `0..<10`).
	public static func range(_ range: Range<Symbol>) -> Self {
		return Self.union(range.map{ Self.symbol($0) });
	}

	/// Creates an alternation between all of the symbols in the given sequence
	/// - Parameter range: The range of symbols (e.g., `0..<10`).
	public static func range<T: Sequence>(_ range: T) -> Self where T.Element == Symbol {
		return Self.union(range.map{ Self.symbol($0) });
	}

	/// Creates a concatenation from the symbols in the given sequence
	/// - Parameter range: The range of symbols (e.g., `0..<10`).
	public static func sequence<T: Sequence>(_ sequence: T) -> Self where T.Element == Symbol {
		return Self.concatenate(sequence.map{ Self.symbol($0) });
	}
}
/// A very simple implementation of RegularPatternProtocol. Likely the simplest possible implementation.
/// For example, it doesn't support repetition operators except kleene star (required for infinity).
/// An optional element is represented as an alternation with the empty string.
public indirect enum SimpleRegex<S>: RegularPatternProtocol, Hashable where S: BinaryInteger {
	public typealias Element = Array<S>
	public typealias Symbol = S

	public static var empty: Self { Self.alternation([]) }
	public static var epsilon: Self { Self.concatenation([]) }

	case alternation([Self])
	case concatenation([Self])
	case star(Self)
	case symbol(Symbol)

	public init (_ sequence: any Sequence<Symbol>) {
		self = .concatenation(sequence.map{ Self.symbol($0) })
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

	public var description: String {
		func toString(_ other: Self) -> String {
			if(other.precedence >= self.precedence) {
				return "(\(other.description))"
			}
			return other.description
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

