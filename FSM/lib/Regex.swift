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
public protocol RegularPatternProtocol {
	/// The type of sequence this pattern operates over, such as an array of symbols.
	associatedtype Element: Sequence, EmptyInitial where Element.Element == Symbol;

	/// The type of individual symbols in the sequence, which must be hashable for set-like operations.
	associatedtype Symbol;

	/// An instance representing the empty language, which accepts no sequences.
	static var empty: Self { get }

	/// An instance representing the language that accepts only the empty sequence (epsilon).
	static var epsilon: Self { get }

	/// Creates a pattern accepting the union of the languages defined by the given patterns.
	/// - Parameter other: An array of patterns to union with this one.
	/// - Returns: A pattern accepting any sequence accepted by at least one of the input patterns.
	static func union(_ elements: [Self]) -> Self

	/// Creates a pattern accepting the concatenation of the languages defined by the given patterns.
	/// - Parameter other: An array of patterns to concatenate with this one.
	/// - Returns: A pattern accepting sequences formed by appending sequences from each pattern in order.
	static func concatenate(_ elements: [Self]) -> Self

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

	/// Converts this pattern to an equivalent pattern of the specified type.
	/// - Parameter patternType: The target pattern type to convert to.
	/// - Returns: An equivalent pattern constructed using the target type's interface.
//	func toPattern<PatternType: RegularPatternProtocol>(_ patternType: PatternType.Type) -> PatternType
}

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
}

/// A very simple implementation of RegularPatternProtocol. Likely the simplest possible implementation.
/// For example, it doesn't support repetition operators except kleene star (required for infinity).
/// An optional element is represented as an alternation with the empty string.
indirect enum SimpleRegex<S>: RegularPatternProtocol where S: BinaryInteger {
	typealias RawValue = Int

	typealias Element = Array<S>
	typealias Symbol = S

	static var empty: Self { Self.union([]) }
	static var epsilon: Self { Self.concatenate([]) }

	case union([Self])
	case concatenate([Self])
	case star(Self)
	case symbol(Symbol)

	public init (_ sequence: any Sequence<Symbol>) {
		self = .concatenate(sequence.map{ Self.symbol($0) })
	}

	var precedence: Int {
		switch self {
			case .union: return 4
			case .concatenate: return 3
			case .star: return 2
			case .symbol: return 1
		}
	}

	func concatenate(_ other: Self) -> Self {
		if case .concatenate(let array) = self {
			return .concatenate(array + [other])
		}else{
			return .concatenate([self, other])
		}

	}

	func union(_ other: Self) -> Self {
		if case .union(let array) = self {
			return .union(array + [other])
		}else{
			return .union([self, other])
		}
	}

	func star() -> Self {
		return .star(self)
	}

	var description: String {
		func toString(_ other: Self) -> String {
			if(other.precedence >= self.precedence) {
				return "(\(other.description))"
			}
			return other.description
		}
		switch self {
			case .union(let array): return array.isEmpty ? "∅" : array.map(toString).joined(separator: "|")
			case .concatenate(let array): return array.isEmpty ? "ε" : array.map(toString).joined(separator: ".")
			case .star(let regex): return toString(regex) + "*"
			case .symbol(let c): return String(c, radix: 0x10)
		}
	}

	func toPattern<PatternType>(_ patternType: PatternType.Type) -> PatternType where PatternType : RegularPatternProtocol {
		PatternType.empty
	}
}

