/// A very simple implementation of RegularPatternProtocol. Likely the simplest possible implementation.
/// For example, it doesn't support repetition operators except kleene star (required for infinity).
/// An optional element is represented as an alternation with the empty string.
public indirect enum SimpleRegex<Symbol>: RegularPattern, SymbolClassPatternBuilder, Hashable where Symbol: BinaryInteger {
	public typealias Alphabet = SymbolAlphabet<Symbol>
	public typealias SymbolClass = Alphabet.SymbolClass
	public typealias Element = Array<SymbolClass>

	case alternation([Self])
	case concatenation([Self])
	case star(Self)
	case symbol(SymbolClass)

	public init() {
		self = .alternation([])
	}

	public init(arrayLiteral: Array<SymbolClass>...) {
		self = .alternation( arrayLiteral.map{ .concatenation($0.map { Self.symbol($0) }) } )
	}

	public init (_ sequence: any Sequence<SymbolClass>) {
		self = .concatenation(sequence.map{ Self.symbol($0) })
	}

	public static func symbol(range: Alphabet.SymbolClass) -> SimpleRegex<Symbol> {
		.symbol(range)
	}

	/// Shorthand to create an alternation over a range of values
	public static func range(_ range: ClosedRange<Symbol>) -> SimpleRegex<Symbol> where Symbol: Strideable, Symbol.Stride: SignedInteger {
		.alternation(range.map { .symbol($0) })
	}

	/// A set of all the symbols in use in this regex.
	/// Using any symbols outside this set guarantees a transition to the oblivion state (rejection).
	public var alphabet: Set<SymbolClass> {
		switch self {
			case .alternation(let array): return Set(array.flatMap(\.alphabet))
			case .concatenation(let array): return Set(array.flatMap(\.alphabet))
			case .star(let regex): return regex.alphabet
			case .symbol(let c): return [c]
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

	public func toPattern<PatternType: RegularPatternBuilder>(as: PatternType.Type? = nil) -> PatternType where PatternType.Symbol == Symbol {
		switch self {
			case .alternation(let array): return PatternType.union(array.map({ $0.toPattern(as: PatternType.self) }))
			case .concatenation(let array): return PatternType.concatenate(array.map({ $0.toPattern(as: PatternType.self) }))
			case .star(let regex): return regex.toPattern(as: PatternType.self).star()
			case .symbol(let c): return PatternType.symbol(c)
		}
	}
}
