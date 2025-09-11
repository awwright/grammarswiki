/// A Finite Partitioned Language: A language with finite, partitioned elements
struct FPL<Symbol: Hashable & Comparable>: Hashable, Equatable, ExpressibleByArrayLiteral {
	typealias Symbol = Symbol
	typealias Alphabet = SymbolAlphabet<Symbol>
	typealias Element = Array<Symbol>

	/// The complete set of strings in the language
	var elements: Set<Element>
	var partitions: SetAlphabet<Element>

	static var empty: Self { Self() }
	static var epsilon: Self { Self(elements: Set([[]])) }

	private var dfa: SymbolDFA<Symbol> {
		get {
			elements.reduce(SymbolDFA<Symbol>(), { $0.union(SymbolDFA<Symbol>(verbatim: $1)) }).minimized()
		}
	}

	init () {
		self.elements = []
		self.partitions = []
	}

	public typealias ArrayLiteralElement = Element
	init (arrayLiteral elements: Element...) {
		self.elements = Set(elements)
		self.partitions = SetAlphabet(partitions: elements.map { Set([$0]) })
	}

	init (elements: Set<Element>) {
		self.elements = elements
		self.partitions = [elements]
	}

	static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.elements == rhs.elements
	}

	var alphabet: Alphabet {
		Alphabet(alphabet: dfa.alphabet)
	}

	func toViz(stringify: (Alphabet.Element) -> String = { String(describing: $0) }) -> String {
		self.dfa.toViz(stringify: stringify)
	}

	func targets(source state: Int) -> Dictionary<Int, Set<Symbol>> {
		dfa.targets(source: state)
	}

	func targets(source state: Int, target: Int) -> Set<Symbol> {
		dfa.targets(source: state, target: target)
	}

	func nextState(state: Int, symbol: Symbol) -> Int? {
		dfa.nextState(state: state, symbol: symbol)
	}

	func nextState(state: Int, range: Symbol) -> Int? {
		dfa.nextState(state: state, symbol: range)
	}

	func nextState(state: Int, input: any Sequence<Symbol>) -> Int? {
		dfa.nextState(state: state, input: input)
	}

	func isFinal(_ state: Int?) -> Bool {
		dfa.isFinal(state)
	}

	func isFinal(_ state: Set<Int>) -> Bool {
		dfa.isFinal(state)
	}

	func contains(_ input: Array<Symbol>) -> Bool {
		elements.contains(input)
	}

	func contains(_ input: some Sequence<Symbol>) -> Bool {
		dfa.contains(input)
	}

	func union(_ other: __owned Self) -> Self {
		Self(elements: self.elements.union(other.elements))
	}

	func intersection(_ other: Self) -> Self {
		Self(elements: self.elements.intersection(other.elements))
	}

	func symmetricDifference(_ other: __owned Self) -> Self {
		Self(elements: self.elements.symmetricDifference(other.elements))
	}

	static func union(_ elements: [Self]) -> Self {
		elements.reduce(Self(), { $0.union($1) })
	}

	static func concatenate(_ languages: Array<Self>) -> Self {
		if languages.isEmpty {
			return Self(elements: Set([[]]))
		}
		return languages.dropFirst().reduce(languages[0], { $0.concatenate($1) })
	}

	func concatenate(_ other: Self) -> Self {
		var newElements = Set<Element>()
		for a in self.elements {
			for b in other.elements {
				newElements.insert(a + b)
			}
		}
		return Self(elements: newElements)
	}

	static func symbol(_ element: Symbol) -> Self {
		Self(elements: Set([[element]]))
	}

	static func symbol(range: Symbol) -> Self {
		Self(elements: Set([[range]]))
	}

	func optional() -> Self {
		self.union(Self(elements: Set([[]])))
	}

	func star() -> Self {
		if self == Self.empty { return self; }
		if self == Self.epsilon { return self; }
		fatalError("Cannot compute star on language containing empty string")
	}

	func plus() -> Self {
		if self == Self.empty { return self; }
		if self == Self.epsilon { return self; }
		fatalError("Cannot compute plus on language containing empty string")
	}

	func repeating(_ count: Int) -> Self {
		precondition(count >= 0)
		var result = Self(elements: Set([[]]))
		for _ in 0..<count {
			result = result.concatenate(self)
		}
		return result
	}

	func repeating(_ range: ClosedRange<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		let base = repeating(range.lowerBound)
		let opt = self.optional()
		var opts = Self(elements: Set([[]]))
		for _ in 0..<range.upperBound - range.lowerBound {
			opts = opts.concatenate(opt)
		}
		return base.concatenate(opts)
	}

	func reversed() -> Self {
		Self(elements: Set(self.elements.map { Array($0.reversed()) }))
	}

	func derive(_ input: Element) -> Self {
		let newElements = elements.compactMap { elem in
			elem.starts(with: input) ? Array(elem.dropFirst(input.count)) : nil
		}
		return Self(elements: Set(newElements))
	}

	func derive(_ input: Self) -> Self {
		var result = Self()
		for prefix in input.elements {
			result = result.union(self.derive(prefix))
		}
		return result
	}

	func dock(_ input: Self) -> Self {
		self.reversed().derive(input.reversed()).reversed()
	}

	func prefixes() -> Self {
		// Find lexicographic sort
		let sorted = elements.sorted { $0.lexicographicallyPrecedes($1) }
		var prefix: Element? = nil
		var result = Set<Element>()
		// Assume that `sorted` will be in lexicographic order
		for element in sorted {
			if let prefix, element.starts(with: prefix) { continue }
			result.insert(element)
			prefix = element
		}
		return Self(elements: result)
	}

	func toPattern<PatternType: SymbolClassPatternBuilder>(as: PatternType.Type? = nil) -> PatternType where PatternType.Symbol == Symbol, PatternType.SymbolClass == Symbol {
		dfa.toPattern(as: PatternType.self)
	}

	mutating func insert(_ newMember: __owned Element) -> (inserted: Bool, memberAfterInsert: Element) {
		elements.insert(newMember)
	}

	mutating func remove(_ member: Element) -> Element? {
		elements.remove(member)
	}

	mutating func update(with newMember: __owned Element) -> Element? {
		elements.update(with: newMember)
	}

	static func - (lhs: Self, rhs: Self) -> Self {
		Self(elements: lhs.elements.subtracting(rhs.elements))
	}
}
