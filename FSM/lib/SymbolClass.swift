/// Find the partition-intersection of multiple sets, i.e. a set partitioned into the largest possible subsets that are always in the same input sets
func partitionReduce<Symbol>(_ base: Set<Set<Symbol>>, _ with: Set<Symbol>) -> Set<Set<Symbol>> where Symbol: Hashable {
	let extra = with.subtracting(Set(base.flatMap { $0 }))
	return Set((base.flatMap { [ $0.intersection(with), $0.subtracting(with)] } + [extra]).filter { !$0.isEmpty })
}

/// Find the intersection of multiple alphabets; the partitioned set with the largest possible partitions such that each set contains all or none of the elements in each partition
func alphabetCombine<Symbol>(_ seq: any Sequence<Set<Symbol>>) -> Set<Set<Symbol>> where Symbol: Hashable {
	Set(seq.reduce(Set<Set<Symbol>>([]), partitionReduce))
}

/// Makes a Dictionary that maps each character in the alphabet to the lowest-values character in its partition
public func compressPartitions<Symbol>(_ partitions: Set<Set<Symbol>>) -> (reduce: Dictionary<Symbol, Symbol>, expand: Dictionary<Symbol, Array<Symbol>>, alphabet: Set<Symbol>) where Symbol: Hashable & Comparable {
	var reduce: [Symbol: Symbol] = [:]
	var expand: [Symbol: Array<Symbol>] = [:]
	var alphabet: Set<Symbol> = []
	for partition in partitions {
		let ordered = partition.sorted();
		let key = ordered.first!
		for char in ordered {
			reduce[char] = key
			expand[key, default: []].append(char)
			alphabet.insert(key)
		}
	}
	return (reduce, expand.mapValues{$0.sorted()}, alphabet)
}

public struct SymbolClassDFA<Symbol: Comparable & Hashable>: Sequence, Equatable, FSMProtocol {
	public typealias StateNo = DFA<Symbol>.StateNo
	public typealias States = DFA<Symbol>.States
	public typealias ArrayLiteralElement = DFA<Symbol>.ArrayLiteralElement
	public typealias Iterator = DFA<Symbol>.Iterator
	
	// TODO: a variation that replaces the symbol with a character class matching the whole character class
	// Type signature would be DFA<Array<SimplePattern<Symbol>>>
	
	public let inner: DFA<Symbol>;
	public let mapping: Dictionary<Symbol, Symbol>;
	public let alphabet: Set<Symbol>;

	public var initial: StateNo { inner.initial }
	public var states: Array<Dictionary<Symbol, StateNo>> { inner.states }
	public var finals: Set<StateNo> { inner.finals }
	
	public init() {
		inner = DFA()
		mapping = [:]
		alphabet = []
	}
	
	public init(inner: DFA<Symbol>, mapping: Dictionary<Symbol, Symbol>) {
		self.inner = inner
		self.mapping = mapping;
		self.alphabet = Set(mapping.keys);
	}
	
	public init(inner: DFA<Symbol>) where Element: Comparable & Hashable {
		let (reduce, _, alphabet) = compressPartitions(inner.alphabetPartitions)
		self.inner = inner
		self.mapping = reduce
		self.alphabet = alphabet
	}
	
	public init(verbatim: DFA<Symbol>.Element) {
		inner = DFA(verbatim: verbatim)
		mapping = [:]
		alphabet = []
	}
	
	public func nextState(state: StateNo, input: Element) -> States {
		assert(state >= 0)
		assert(state < self.states.count)
		var currentState = state;
		for char in input {
			guard currentState < self.states.count,
					let mappedSymbol = self.mapping[char],
					let nextState = self.states[currentState][mappedSymbol]
			else {
				return nil
			}
			currentState = nextState
		}
		
		return currentState;
	}
	
	public func intersection(_ other: SymbolClassDFA<Symbol>) -> SymbolClassDFA<Symbol> {
		fatalError("Unimplemented")
		//SymbolClassDFA(inner: inner.intersection(other.inner), mapping: mapping)
	}
	
	public func symmetricDifference(_ other: __owned SymbolClassDFA<Symbol>) -> SymbolClassDFA<Symbol> {
		fatalError("Unimplemented")
		//SymbolClassDFA(inner: inner.symmetricDifference(other.inner), mapping: mapping)
	}
	
	public static func - (lhs: SymbolClassDFA<Symbol>, rhs: SymbolClassDFA<Symbol>) -> SymbolClassDFA<Symbol> {
		fatalError("Unimplemented")
		//SymbolClassDFA(inner: lhs.inner - rhs.inner, mapping: lhs.mapping)
	}
	
	public func star() -> SymbolClassDFA<Symbol> {
		fatalError("Unimplemented")
		//SymbolClassDFA(inner: inner.star(), mapping: mapping)
	}
	
	public mutating func formUnion(_ other: __owned SymbolClassDFA<Symbol>) {
		fatalError("Unimplemented")
		//self = SymbolClassDFA(inner: inner.union(other.inner), mapping: mapping)
	}
	
	public mutating func formIntersection(_ other: SymbolClassDFA<Symbol>) {
		fatalError("Unimplemented")
		//self = SymbolClassDFA(inner: inner.intersection(other.inner), mapping: mapping)
	}
	
	public mutating func formSymmetricDifference(_ other: __owned SymbolClassDFA<Symbol>) {
		fatalError("Unimplemented")
		//self = SymbolClassDFA(inner: inner.symmetricDifference(other.inner), mapping: mapping)
	}
	
	public static var empty: SymbolClassDFA<Symbol> {
		SymbolClassDFA(inner: DFA<Symbol>.empty, mapping: [:])
	}
	
	public static var epsilon: SymbolClassDFA<Symbol> {
		SymbolClassDFA(inner: DFA<Symbol>.epsilon, mapping: [:])
	}
	
	
	public func isFinal(_ state: DFA<Symbol>.States) -> Bool {
		inner.isFinal(state)
	}
	
	public func makeIterator() -> DFA<Symbol>.Iterator {
		fatalError("Unimplemented")
		//return inner.makeIterator()
	}
	
	public mutating func insert(_ newMember: __owned DFA<Symbol>.Element) -> (inserted: Bool, memberAfterInsert: DFA<Symbol>.Element) {
		fatalError("Unimplemented")
		//var newSet = self.inner;
		//let value = newSet.insert(newMember);
		//self = SymbolClassDFA(inner: newSet, mapping: mapping);
		//return value;
	}
	
	public mutating func remove(_ member: DFA<Symbol>.Element) -> (DFA<Symbol>.Element)? {
		fatalError("Unimplemented")
		//var newSet = self.inner;
		//let value = newSet.remove(member);
		//self = SymbolClassDFA(inner: newSet, mapping: mapping);
		//return value;
	}
	
	public mutating func update(with newMember: __owned DFA<Symbol>.Element) -> (DFA<Symbol>.Element)? {
		fatalError("Unimplemented")
		//var newSet = self.inner;
		//let value = newSet.update(with: newMember);
		//self = SymbolClassDFA(inner: newSet, mapping: mapping);
		//return value;
	}
	
	public func contains(_ member: DFA<Symbol>.Element) -> Bool {
		inner.contains(member.map { mapping[$0] ?? $0 })
	}
	
	public static func union(_ elements: [SymbolClassDFA<Symbol>]) -> SymbolClassDFA<Symbol> {
		fatalError("Unimplemented")
		//SymbolClassDFA(inner: DFA<Symbol>.union(elements.map(\.inner)), mapping: [:])
	}
	
	
	public static func concatenate(_ elements: [SymbolClassDFA<Symbol>]) -> SymbolClassDFA<Symbol> {
		fatalError("Unimplemented")
		//SymbolClassDFA(inner: DFA<Symbol>.concatenate(elements.map(\.inner)), mapping: [:])
	}
	
	public static func symbol(_ element: Symbol) -> SymbolClassDFA<Symbol> {
		fatalError("Unimplemented")
		//SymbolClassDFA(inner: DFA<Symbol>.symbol(element), mapping: [:])
	}
	
}
