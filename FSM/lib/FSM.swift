/// An abstraction of a regular language
public protocol RegularLanguageProtocol: ExpressibleByArrayLiteral, RegularPatternBuilder {
	associatedtype Symbol: Equatable;
	associatedtype Element: Collection where Element.Element == Symbol

	/// Checks if the DFA accepts a given sequence (element of the language)
	func contains(_ input: Element) -> Bool
}

/// A regular language structure that provides set algebra operations
public protocol RegularLanguageSetAlgebra: SetAlgebra, ExpressibleByArrayLiteral, RegularPatternBuilder {
	/// Returns a DFA accepting the union of this DFA’s language and another’s.
	/// Implements ``SetAlgebra``
	func union(_ other: __owned Self) -> Self

	/// Returns a DFA accepting the intersection of this DFA’s language and another’s.
	/// Implements ``SetAlgebra``
	func intersection(_ other: Self) -> Self

	/// Returns a DFA accepting the symmetric difference of this DFA’s language and another’s.
	/// That is, the set of elements in exactly one set or the other set, and not both.
	/// To only remove elements, see ``subtracting(_:)`` or the ``-(lhs:rhs:)`` operator
	func symmetricDifference(_ other: __owned Self) -> Self

	// Also provide a static implementation of union since it applies to any number of inputs
	static func union(_ languages: Array<Self>) -> Self

	/// Finds the language of all the the ways to join a string from the first language with strings in the second language
	static func concatenate(_ languages: Array<Self>) -> Self

	func concatenate(_ other: Self) -> Self

	/// Return a DFA that also accepts the empty sequence
	/// i.e. adds the initial state to the set of final states
	func optional() -> Self

	/// Returns a DFA accepting one or more repetitions of its language.
	func plus() -> Self

	/// Returns a DFA accepting zero or more repetitions of its language.
	func star() -> Self

	/// Returns a DFA accepting exactly `count` repetitions of its language.
	func repeating(_ count: Int) -> Self

	/// Returns a DFA accepting between `range.lowerBound` and `range.upperBound` repetitions.
	func repeating(_ range: ClosedRange<Int>) -> Self

	/// Returns a DFA accepting `range.lowerBound` or more repetitions.
	func repeating(_ range: PartialRangeFrom<Int>) -> Self

	/// Required by ``SetAlgebra``
	///
	/// If you are inserting multiple elements, ``formUnion`` will be significantly more performant.
	mutating func insert(_ newMember: __owned Element) -> (inserted: Bool, memberAfterInsert: Element)

	/// Required by ``SetAlgebra``
	mutating func remove(_ member: Element) -> (Element)?

	/// Required by ``SetAlgebra``
	mutating func update(with newMember: __owned Element) -> (Element)?

	/// Required by ``SetAlgebra``
	mutating func formUnion(_ other: __owned Self)

	/// Required by ``SetAlgebra``
	mutating func formIntersection(_ other: Self)

	/// Required by ``SetAlgebra``
	mutating func formSymmetricDifference(_ other: __owned Self)

	/// Subtract/difference
	/// Returns a version of `lhs` but removing any elements in `rhs`
	///
	/// Note: I think (-) is pretty unambiguous here, but some math notation uses \ for this operation.
	static func - (lhs: Self, rhs: Self) -> Self
}

extension RegularLanguageSetAlgebra {
	/// Subtraction default implementation
	public static func - (lhs: Self, rhs: Self) -> Self {
		return lhs.subtracting(rhs)
	}

	public mutating func formUnion(_ other: __owned Self) {
		self = self.union(other);
	}

	public mutating func formIntersection(_ other: Self) {
		self = self.intersection(other);
	}

	public mutating func formSymmetricDifference(_ other: __owned Self) {
		self = self.symmetricDifference(other);
	}
}
