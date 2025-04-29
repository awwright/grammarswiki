/// Transparently maps a regular language with a large alphabet onto a DFA with a smaller alphabet where some symbols are equivalent
public struct ClosedRangeDFA<ExpandedSymbol: Hashable & Comparable & BinaryInteger>: DFAProtocol, RegularPatternBuilder where ExpandedSymbol.Stride: SignedInteger {
	public typealias Alphabet = ClosedRangeSymbolClass<ExpandedSymbol>
	public typealias Symbol = ClosedRange<ExpandedSymbol>
	public typealias Element = Array<Symbol>
	public typealias StateNo = DFA<Symbol>.StateNo
	public typealias States = DFA<Symbol>.States
	public typealias ArrayLiteralElement = DFA<Symbol>.ArrayLiteralElement

	public struct Expanded: DFAProtocol {
		public typealias Alphabet = SymbolClass<ExpandedSymbol>
		public typealias Symbol = ExpandedSymbol
		public typealias Element = Array<Symbol>
		var underlying: ClosedRangeDFA<ExpandedSymbol>
		public var alphabet: Set<ExpandedSymbol> { Set() }
		public var alphabetPartitions: SymbolClass<ExpandedSymbol> { fatalError() }
		public var states: Array<Dictionary<ExpandedSymbol, Int>> { fatalError("Implement") }
		public var initial: Int { underlying.initial }
		public var finals: Set<Int> { underlying.finals }
		public func contains(_ input: Array<Symbol>) -> Bool { fatalError("Implement") }
		public func nextState(state: StateNo, input: Element) -> States {
			assert(state >= 0)
			assert(state < self.states.count)
			fatalError("Unimplemented")
		}
		public func isFinal(_ state: Int?) -> Bool { underlying.isFinal(state) }
		public func isFinal(_ state: Set<Int>) -> Bool { underlying.isFinal(state) }
		public static func == (lhs: ClosedRangeDFA<Symbol>.Expanded, rhs: ClosedRangeDFA<Symbol>.Expanded) -> Bool { lhs.underlying == rhs.underlying }

		public func toPattern<PatternType>(as: PatternType.Type?) -> PatternType where PatternType : RegularPatternBuilder, ExpandedSymbol == PatternType.Symbol { fatalError("Unimplemented") }
	}

	// TODO: a variation that replaces the symbol with a character class matching the whole character class
	// Type signature would be DFA<Array<SimplePattern<Symbol>>>

	public let inner: DFA<Symbol>;

	public var states: Array<Dictionary<Symbol, StateNo>> { inner.states }
	public var statesMapping: Array<(symbols: ClosedRangeSymbolClass<ExpandedSymbol>, target: Dictionary<ExpandedSymbol, Int>)>
	public var initial: StateNo { inner.initial }
	public var finals: Set<StateNo> { inner.finals }

	public init() {
		self.inner = DFA()
		self.statesMapping = [];
		//		states.map {
		//			var dict = Dictionary<Int, Array<Symbol>>();
		//			for (range, target) in $0 {
		//				dict[target, default: []].append(range)
		//			}
		//			var symbols = ClosedRangeSymbolClass<ExpandedSymbol>(partitions: dict.values);
		//			var targets = Dictionary<Int, Symbol>(uniqueKeysWithValues: symbols.partitionLabels)
		//			return (symbols: symbols, target: targets)
		//		}
	}

	public init(_ inner: DFA<ClosedRange<ExpandedSymbol>>) {
		self.inner = inner
		self.statesMapping = [];
	}

	public init(verbatim: DFA<Symbol>.Element) {
		inner = DFA(verbatim: verbatim)
		statesMapping = []
	}

	public var expanded: Expanded {
		Expanded(underlying: self)
	}

	public var alphabet: Set<ClosedRange<ExpandedSymbol>> { fatalError() }
	public var alphabetPartitions: Alphabet { fatalError() }

	public func contains(_ member: Element) -> Bool {
		fatalError("Unimplemented")
	}

	public func isFinal(_ state: Set<Int>) -> Bool {
		inner.isFinal(state)
	}

	public func isFinal(_ state: Int?) -> Bool {
		inner.isFinal(state)
	}

	public func nextState(state: StateNo, input: Element) -> States {
		assert(state >= 0)
		assert(state < self.states.count)
		fatalError("Unimplemented")
	}

	public static func symbol(_ element: ClosedRange<ExpandedSymbol>) -> Self {
		let val: DFA<ClosedRange<ExpandedSymbol>> = [[element]];
		return Self(val)
	}

	public static func union(_ elements: [Self]) -> Self {
		Self(DFA<Symbol>.union(elements.map(\.inner)))
	}

	public static func concatenate(_ elements: [Self]) -> Self {
		Self(DFA<Symbol>.concatenate(elements.map(\.inner)))
	}

	public func star() -> Self {
		Self(inner.star())
	}

	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.inner == rhs.inner
	}

	public func toPattern<PatternType>(as: PatternType.Type?) -> PatternType where PatternType : RegularPatternBuilder, ClosedRange<ExpandedSymbol> == PatternType.Symbol {
		fatalError("Unimplemented")
	}
}
