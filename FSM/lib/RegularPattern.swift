/// Declares a type of sequence that can be consumed or produced by a finite state automata
/// It defines the empty sequence, and can be built from the empty sequence by appending elements.
/// An elements of this sequence is a Symbol. They must be usable as keys for a ``Dictionary``, so Symbol depends on ``Hashable``.
public protocol SymbolSequenceProtocol: Sequence where Element: Hashable {
	typealias Symbol = Element;

	/// An instance of this type that has no elements
	static var empty: Self { get }

	/// An instance of this type that has no elements
	init();

	/// Return a new sequence concatenated with the given sequence
	/// This is usually implemented by Array and String.
	static func + (_: Self, _: Self) -> Self;

	/// Return a new sequence with the given alement appended
	func appending(_: Symbol) -> Self;
}

/// A language that can be constructed through a combination of symbol, union, concatenation, and repetition operations.
/// It is very flexible and allows constructing a regular expression of any type from any other conforming type.
///
/// Default implementations for most methods are provided, except for:
/// - static var empty
/// - static var epsilon
/// - static func union
/// - static func concatenate
/// - func optional
/// - func toPattern
public protocol RegularPatternBuilder: Equatable {
	/// The type of individual symbols in the sequence, which must be hashable for set-like operations.
	associatedtype Symbol;

	/// An instance representing the empty language, which accepts no sequences.
	/// Equivalent to `init()`
	static var empty: Self { get }

	/// An instance representing the language that accepts only the empty sequence (epsilon).
	static var epsilon: Self { get }

	/// Creates an empty automaton that accepts no strings
	init();

	/// Creates an automaton that matches exactly the given strings
	init(arrayLiteral: Array<Symbol>...)

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

	//func mapSymbol<Target>(_: (Symbol) throws -> Target) rethrows -> Target;

	/// Concatenation operator
	///
	/// The selection of symbol for operator is fraught because most of these symbols have been used for most different things
	/// String concatenation is slightly different than language concatenation,
	/// I want to suggest the string concatenation of the cross product of any string from ordered pair languages
	static func ++ (lhs: Self, rhs: Self) -> Self

	/// Union/alternation
	static func | (lhs: Self, rhs: Self) -> Self
}

/// Language concatenate (string concatenation of cross-product)
infix operator ++: AdditionPrecedence;

extension RegularPatternBuilder {
	/// Default implementation of empty set constructor
	public init(){
		self = Self.union([])
	}

	/// Default implementation of array literal constructor.
	/// This is not likely to be very efficent, but it is generic.
	public init(arrayLiteral: Array<Symbol>...) {
		self = Self.union(arrayLiteral.map { Self.concatenate($0.map { Self.symbol($0) }) })
	}

	/// Default implementation of empty
	public static var empty: Self { Self() }

	/// Default implementation of epsilon
	public static var epsilon: Self { Self.concatenate([]) }

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

	/// Creates a concatenation from the symbols in the given sequence
	/// - Parameter range: The range of symbols (e.g., `0..<10`).
	public static func sequence<T: Sequence>(_ sequence: T) -> Self where T.Element == Symbol {
		return Self.concatenate(sequence.map{ Self.symbol($0) });
	}
}

public protocol ClosedRangePatternBuilder: RegularPatternBuilder where Symbol: Strideable, Symbol.Stride: SignedInteger {
	static func range(_ range: ClosedRange<Symbol>) -> Self
}

public protocol SymbolClassPatternBuilder: RegularPatternBuilder where Symbol: Comparable {
	associatedtype SymbolClass
	static func symbol(range: SymbolClass) -> Self
}

/// Indicates that the conforming structure can be exported to a RegularPatternProtocol object
public protocol RegularPattern where Symbol: Hashable {
	/// The type of individual symbols in the sequence, which must be hashable for set-like operations.
	associatedtype Symbol;

	func toPattern<PatternType: RegularPatternBuilder>(as: PatternType.Type?) -> PatternType where PatternType.Symbol == Symbol;

	/// Get exactly symbols used in the pattern
	var alphabet: Set<Symbol> { get }
}

