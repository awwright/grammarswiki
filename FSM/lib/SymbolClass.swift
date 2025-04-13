/// A set of symbols, with tracking equivalency of elements (placing symbols with the same behavior in the same partition)
/// Optimized for describing ranges of characters.
/// A replacement for Swift's builtin RangeSet which doesn't support ClosedRange and is overall garbage
public struct SymbolClass<Symbol: Comparable & Hashable>: ExpressibleByArrayLiteral, SetAlgebra where Symbol: BinaryInteger {
	// MARK: Type definitions
	public typealias ArrayLiteralElement = Symbol
	public typealias Element = Symbol

	// MARK: Properties
	// Ordered list of all symbols (and ranges) in the class
	var symbols: Array<ClosedRange<Symbol>>
	// A tree partitioning elements together
	var parents: Array<Int>

	// MARK: Initializations
	public init() {
		self.symbols = []
		self.parents = []
	}

	public init(symbols: Array<ClosedRange<Symbol>>, parents: Array<Int>) {
		self.symbols = symbols
		self.parents = parents
	}

	public init(partitions: Array<Array<Symbol>>) {
		self = Self.meet(partitions.compactMap {
			if($0.isEmpty){ return nil }
			let sorted = $0.sorted();
			return SymbolClass(symbols: sorted.map{ $0...$0 }, parents: Array(repeating: 0, count: sorted.count))
		})
	}

	public init(_ partitions: Array<Symbol>...) {
		let union = partitions.flatMap { $0 }
		self.symbols = union.map { $0...$0 }.sorted { $0.lowerBound < $1.lowerBound }
		self.parents = self.symbols.enumerated().map { i, _ in i }
		for part in partitions {
			if part.isEmpty { continue }
			let partSorted = part.sorted { $0 < $1 }
			let partLabel = partSorted[0]
			let partLabelIndex = findIndex(partLabel)!
			for i in 0..<partSorted.count {
				self.parents[findIndex(partSorted[i])!] = partLabelIndex
			}
		}
	}

	public init(partitions: Array<Array<ClosedRange<Symbol>>>) {
		let union = partitions.flatMap { $0 }
		self.symbols = union.sorted { $0.lowerBound < $1.lowerBound }
		self.parents = self.symbols.enumerated().map { i, _ in i }
		for part in partitions {
			if part.isEmpty { continue }
			let partSorted = part.sorted { $0.lowerBound < $1.lowerBound }
			let partLabel = partSorted[0].lowerBound
			let partLabelIndex = findIndex(partLabel)!
			for i in 0..<partSorted.count {
				self.parents[findIndex(partSorted[i].lowerBound)!] = partLabelIndex
			}
		}
	}

	public init(_ partitions: Array<ClosedRange<Symbol>>...) {
		self.init(partitions: partitions)
	}

	// MARK: ExpressibleByArrayLiteral
	public init(arrayLiteral elements: ArrayLiteralElement...) {
		self.symbols = elements.map { $0...$0 }.sorted { $0.lowerBound < $1.lowerBound }
		self.parents = self.symbols.enumerated().map { i, _ in i }
	}

	public var partitionLabels: Array<Symbol> {
		self.parents.filter { $0 == parents[$0] }.map{ symbols[$0].lowerBound }
	}

	/// Computes a mapping of symbol to partition label
	public var alphabetReduce: Dictionary<Symbol, Symbol> {
		return [:]
	}

	/// Maps partition label to set of values in partition
	public var alphabetExpand: Dictionary<Symbol, Set<Symbol>> {
		return [:]
	}

	public var partitionCount: Int {
		Set(parents).count
	}

	public func isEquivalent(_ lhs: Symbol, _ rhs: Symbol) -> Bool {
		func find(_ symbol: Symbol) -> Int {
			var index = self.findFirstIndex(symbol)
			assert(self.symbols[index].contains(symbol));
			while index != self.parents[index] {
				index = self.parents[index]
			}
			return index
		}
		return find(lhs) == find(rhs)
	}

	public func getPartitionLabel(_ symbol: Symbol) -> Symbol {
		let index = self.findIndex(symbol)
		guard let index else { fatalError() }
		return self.symbols[self.parents[index]].lowerBound
	}

	// MARK: SetAlgebra
	public func contains(_ member: Symbol) -> Bool {
		// Binary search `symbols` for a matching symbol
		var lower = self.symbols.startIndex
		var upper = self.symbols.endIndex
		while lower != upper {
			let middle = (lower + upper) / 2
			let node = self.symbols[middle]
			if node.upperBound < member {
				lower = middle + 1
			} else if member < node.lowerBound {
				upper = middle
			} else if node.lowerBound <= member && member <= node.upperBound {
				return true
			}
		}
		return false
	}

	/// Find the union of the elements with `other`, but divide partitions along their intersections
	public static func meet(_ other: Array<SymbolClass<Symbol>>) -> SymbolClass<Symbol> {
		if other.isEmpty {
			return Self()
		} else if other.count == 1 {
			return other[0]
		}

		// Compute the intersection of all symbols (ranges)
		let allSymbols = other.flatMap { $0.symbols }.sorted { $0.lowerBound < $1.lowerBound }
		var lowerBounds: Array<Symbol> = allSymbols.map(\.lowerBound).sorted();
		var upperBounds: Array<Symbol> = allSymbols.map(\.upperBound).sorted();
		assert(lowerBounds.count == upperBounds.count)

		// Un-nest ranges by adding lower or upper bounds as necessary
		// Only add bounds inside one range or another, test this by counting how many bounds are open
		let nestedUpperBounds: Array<Symbol> = lowerBounds.compactMap {
			offset in
			if (lowerBounds.filter { $0 < offset }.count > upperBounds.filter { $0 < offset }.count) { return offset-1 }
			else { return nil }
		};
		let nestedLowerBounds: Array<Symbol> = upperBounds.compactMap {
			offset in
			if (lowerBounds.filter { $0 <= offset }.count >= upperBounds.filter { $0 <= offset }.count + 1) { return offset+1 }
			else { return nil }
		};
		lowerBounds = Set(lowerBounds+nestedLowerBounds).sorted()
		upperBounds = Set(upperBounds+nestedUpperBounds).sorted()
		assert(lowerBounds.count == upperBounds.count)
		let symbols: [ClosedRange<Symbol>] = zip(lowerBounds, upperBounds).map { $0...$1 }

		// Assign each range in `symbols` to a new partition
		let parts: Array<Array<Symbol?>> = symbols.map {
			subrange in
			other.map { other in
				let index = other.symbols.firstIndex(where: { $0.contains(subrange.lowerBound) })
				guard let index else { return nil }
				return other.symbols[other.parents[index]].lowerBound
			}
		}
		// For the new partition index, just point to the first range to exist in the same set of partitions
		let parents = parts.map {
			parts.firstIndex(of: $0)!
		}
		return SymbolClass(
			symbols: symbols,
			parents: parents
		)
	}
	public func meet(_ other: __owned SymbolClass<Symbol>) -> SymbolClass<Symbol> {
		return Self.meet([self, other])
	}

	public func union(_ other: __owned SymbolClass<Symbol>) -> SymbolClass<Symbol> {
		fatalError("Unimplemented")
	}

	public func intersection(_ other: SymbolClass<Symbol>) -> SymbolClass<Symbol> {
		fatalError("Unimplemented")
	}

	public func symmetricDifference(_ other: __owned SymbolClass<Symbol>) -> SymbolClass<Symbol> {
		fatalError("Unimplemented")
	}

	public mutating func formUnion(_ other: __owned SymbolClass<Symbol>) {
		self = self.union(other)
	}

	public mutating func formIntersection(_ other: SymbolClass<Symbol>) {
		self = self.intersection(other)
	}

	public mutating func formSymmetricDifference(_ other: __owned SymbolClass<Symbol>) {
		self = self.symmetricDifference(other)
	}

	public mutating func insert(_ newMember: __owned Symbol) -> (inserted: Bool, memberAfterInsert: Symbol) {
		let range = ClosedRange(uncheckedBounds: (newMember, newMember))
		// Find insertion point
		let insertionIndex = symbols.firstIndex(where: { $0.lowerBound > newMember }) ?? symbols.count
		symbols.insert(range, at: insertionIndex)
		symbols.insert(range, at: insertionIndex)
		return (true, newMember)
	}

	public mutating func remove(_ member: Symbol) -> Symbol? {
		guard let index = symbols.firstIndex(where: { $0.contains(member) }) else {
			return nil
		}
		symbols.remove(at: index)
		parents.remove(at: index)
		return member
	}

	public mutating func update(with newMember: __owned Symbol) -> Symbol? {
		let (inserted, _) = insert(newMember)
		return inserted ? nil : newMember
	}

	public static func == (lhs: SymbolClass<Symbol>, rhs: SymbolClass<Symbol>) -> Bool {
		return lhs.symbols == rhs.symbols
	}

	// MARK: Helpers

	/// Finds the lowest index at or after the given symbol
	private func findIndex(_ symbol: Symbol) -> Int? {
		var lowerBound = 0
		var upperBound = symbols.count - 1
		while lowerBound <= upperBound {
			let midIndex = (lowerBound + upperBound) / 2
			let midRange = symbols[midIndex]
			if midRange.contains(symbol) {
				return midIndex
			} else if symbol < midRange.lowerBound {
				upperBound = midIndex - 1
			} else if midRange.upperBound < symbol {
				lowerBound = midIndex + 1
			}
		}
		return nil
	}

	private func findFirstIndex(_ symbol: Symbol) -> Int {
		var lowerBound = 0
		var upperBound = symbols.count - 1
		while lowerBound <= upperBound {
			let midIndex = (lowerBound + upperBound) / 2
			let midRange = symbols[midIndex]
			if midRange.contains(symbol) {
				return midIndex
			} else if symbol < midRange.lowerBound {
				upperBound = midIndex - 1
			} else if midRange.upperBound < symbol {
				lowerBound = midIndex + 1
			}
		}
		return lowerBound
	}
}

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

/// Transparently maps a regular language with a large alphabet onto a DFA with a smaller alphabet where some symbols are equivalent
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
