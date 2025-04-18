/// A protocol that is able to store a set of set of symbols, such that all the sets are disjoint from each other, each element only appearing in one partition
/// This is a protocol so that various ways of indexing the elements based on tyoe can be used
protocol PartitionedSetProtocol {
	/// This type may be any type that can compute intersections, etc.
	associatedtype Partition: SetAlgebra;
	typealias Symbol = Partition.Element

	associatedtype Partitions: Collection where Partitions.Element == Partition
	var partitions: Partitions { get }
	// Initialization
	/// Initialize an empty set (no elements, no partitions)
	init()
	/// Initialize a PartitionedSet with the given elements, taking the union-meet of the subsets
	/// If elements appear in multiple partitions, elements found in the same partitions are split out and merged into a new partition
	/// (so that they never share a partition with elements they didn't share with in all partitions).
	init(partitions: some Collection<Partition>)
	/// Get the set of symbols from the partition of the given symbol
	func siblings(of: Symbol) -> Partition
}

/// Default implementations of functions for PartitionedSetProtocol
extension PartitionedSetProtocol {
	/// Create from an array of Symbols
	init(partitions: some Collection<Partition>) {
		self.init(partitions: partitions.map{ $0 })
	}
}

/// A variation of PartitionedSetProtocol where the elements can be individually iterated
protocol PartitionedSetElementsProtocol: PartitionedSetProtocol where Partition: Collection, Symbol: Hashable {
	associatedtype Symbols: Collection where Symbols.Element == Symbol
	var components: Symbols { get }
	var alphabetReduce: Dictionary<Symbol, Symbol> { get }
	var alphabetExpand: Dictionary<Symbol, Array<Symbol>> { get }
}

/// A variation of PartitionedSetProtocol that can store multiple sets of symbols, associating each set with a label
protocol PartitionedDictionaryProtocol: PartitionedSetProtocol {
	associatedtype Label;
	subscript(labelToPartition: Label) -> Partition { set get }
	subscript(elementToLabel: Symbol) -> Label { set get }
}

public struct SymbolPartitionedSet<Symbol: Comparable & Hashable>: PartitionedSetProtocol, RegularPatternProtocol {
	public typealias Partition = Set<Symbol>

	init() {
		symbols = []
		parents = []
	}

	public init(partitions: Array<Partition>) {
		symbols = Set(partitions.flatMap { $0 }).sorted()
		let members = symbols.map { s in partitions.enumerated().compactMap { $0.1.contains(s) ? $0.0 : nil } }
		parents = members.map { members.firstIndex(of: $0)! }
	}

	var symbols: Array<Symbol>
	var parents: Array<Int>

	func siblings(of: Symbol) -> Set<Symbol> {
		let parent = parents[symbols.firstIndex(of: of)!]
		return Set(symbols.enumerated().compactMap { parents[$0.0] == parent ? $0.1 : nil })
	}

	public typealias Partitions = Array<Partition>
	public var partitions: Partitions {
		let labels = Set(parents).sorted()
		var dict: Dictionary<Int, Array<Symbol>> = Dictionary(uniqueKeysWithValues: labels.map { ($0, []) })
		for i in 0..<symbols.count {
			let label = parents[i]
			dict[label]!.append(symbols[i])
		}
		return labels.map { Set(dict[$0]!) }
	}

	// MARK: RegularPatternProtocol
	// For building a partitioned alphabet
	public static var empty: Self { Self() }
	public static var epsilon: Self { Self() }
	public static func symbol(_ element: Symbol) -> Self { .init(partitions: [[element]]) }
	public func star() -> Self { self }
	public static func union(_ elements: [Self]) -> Self {
		Self()
	}
	public static func concatenate(_ elements: [Self]) -> Self {
		Self()
	}
}

/// A set of symbols, with tracking equivalency of elements (placing symbols with the same behavior in the same partition)
/// Optimized for describing ranges of characters.
/// A replacement for Swift's builtin RangeSet which doesn't support ClosedRange and is overall garbage
///
/// In regular languages, an FSM is a machine with states and transitions labeled by symbols.
/// You can convert an FSM to a regular expression by systematically combining transitions into patterns (a process called state elimination or Arden’s rule).
/// Similarly, a regular grammar (a set of production rules) can be converted to an FSM, and then to a regex.
/// SymbolClass enables a parallel idea: converting a grammar-like structure (or a set of rules about symbols) into a partitioned set, which can then be treated as a regular pattern.
// TODO: Rename this to SymbolRangePartitionedSet or something
public struct SymbolClass<Symbol: Comparable & Hashable>: ExpressibleByArrayLiteral, SetAlgebra, RegularPatternProtocol where Symbol: Strideable & BinaryInteger, Symbol.Stride: SignedInteger {
	// MARK: Type definitions
	/// Implements PartitionedSetProtocol
	public typealias Partition = Array<ClosedRange<Symbol>>
	/// Implements ExpressibleByArrayLiteral
	public typealias ArrayLiteralElement = Symbol
	/// Implements SetAlgebra
	public typealias Element = Symbol

	// MARK: Properties
	/// Ordered list of all symbols (and ranges) in the class
	var symbols: Array<ClosedRange<Symbol>>
	/// A tree partitioning elements together
	var parents: Array<Int>

	// MARK: Initializations
	/// Empty initialization
	public init() {
		self.symbols = []
		self.parents = []
	}

	/// Initialize from pre-sorted data
	init(symbols: Array<ClosedRange<Symbol>>, parents: Array<Int>) {
		self.symbols = symbols
		self.parents = parents
	}

	/// Convenience function for writing `SymbolClass([a, b, c, ...], [d, e, f, ...], ...)`
	public init(_ partitions: Array<Symbol>...) {
		self.init(partitions: partitions.map { $0.map { $0...$0 } })
	}

	/// Convenience function for writing `SymbolClass([0...5], [10...20], ...)`
	public init(_ partitions: Partition...) {
		self.init(partitions: partitions)
	}

	/// Create from an array of Symbols
	public init(partitions: some Collection<some Collection<Symbol>>) {
		self.init(partitions: partitions.map{ $0.map { $0...$0 } })
	}

	// If a symbol appears in multiple partitions,
	public init(partitions: some Collection<some Collection<ClosedRange<Symbol>>>) {
		// Sort the elements within the partitions and merge adjacent symbols into a ClosedRange
		let sortedPartitions: Array<Array<ClosedRange<Symbol>>> = partitions.compactMap {
			ranges in
			// Return empty array if input is empty
			guard !ranges.isEmpty else { return nil }

			// Sort ranges by lower bound, then by upper bound for equal lower bounds
			let sortedRanges = ranges.sorted {
				$0.lowerBound == $1.lowerBound ? $0.upperBound < $1.upperBound : $0.lowerBound < $1.lowerBound
			}

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
		}

		// Trivial cases
		if sortedPartitions.isEmpty {
			self.symbols = []
			self.parents = []
			return
		} else if sortedPartitions.count == 1 {
			self.symbols = sortedPartitions[0]
			self.parents = Array(repeating: 0, count: sortedPartitions[0].count)
			return
		}

		// Compute the intersection of all symbols (ranges)
		let allSymbols = sortedPartitions.flatMap { $0 }.sorted { $0.lowerBound < $1.lowerBound }
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

		// Determine which input partitions the symbol is a member of
		let parts: Array<Set<Int>> = symbols.map {
			let symbol = $0.lowerBound
			return Set(partitions.enumerated().compactMap { (i, ranges) in
				ranges.contains(where: { $0.contains(symbol) }) ? i : nil
			})
		}
		// For the new partition index, just point to the first range to exist in the same set of partitions
		let parents = parts.map {
			parts.firstIndex(of: $0)!
		}
		self.symbols = symbols
		self.parents = parents
	}

	// MARK: ExpressibleByArrayLiteral
	public init(arrayLiteral elements: ArrayLiteralElement...) {
		self.symbols = elements.map { $0...$0 }.sorted { $0.lowerBound < $1.lowerBound }
		self.parents = self.symbols.enumerated().map { i, _ in i }
	}

	// MARK: RegularPatternProtocol
	/// A pattern without any elements has an empty alphabet
	public static var empty: Self { Self() }
	/// An element with no symbols also has an empty alphabet
	public static var epsilon: Self { Self() }
	/// An element with a single symbol has one symbol in the alphabet
	public static func symbol(_ element: Symbol) -> Self {
		Self([element])
	}
	public static func concatenate(_ elements: [Self]) -> Self {
		Self(partitions: elements.flatMap(\.partitions))
	}
	public static func union(_ elements: [Self]) -> Self {
		// Merge partitions that are the only partition in their alternation
		// Because they behave the same
		var symbols: Array<ClosedRange<Symbol>> = []
		var partitions: Array<Array<ClosedRange<Symbol>>> = []
		for partition in elements.map(\.partitions) {
			if(partition.count == 1){
				symbols += partition[0]
			}else if(partition.count > 1){
				partitions += partition
			}
		}
		return Self(partitions: [symbols] + partitions)
	}
	public func star() -> Self {
		self
	}

	// MARK: Various accessors

	public var partitionLabels: Array<Symbol> {
		self.parents.filter { $0 == parents[$0] }.map{ symbols[$0].lowerBound }
	}

	/// Maps partition label to set of values in partition
	public var alphabet: Partition {
		symbols
	}

	/// Maps partition label to set of values in partition
	public var partitions: Array<Partition> {
		let labels = Set(parents).sorted()
		var dict: Dictionary<Int, Array<ClosedRange<Symbol>>> = Dictionary(uniqueKeysWithValues: labels.map { ($0, []) })
		for i in 0..<symbols.count {
			let label = parents[i]
			dict[label]!.append(symbols[i])
		}
		return labels.map { dict[$0]! }
	}

	/// Computes a mapping of symbol to partition label
	public var alphabetReduce: Dictionary<Symbol, Symbol> {
		var result: Dictionary<Symbol, Symbol> = [:]
		for (index, parent) in parents.enumerated() {
			let label = symbols[parent].lowerBound
			for symbol in symbols[index] {
				result[symbol] = label
			}
		}
		return result
	}

	/// Maps partition label to set of values in partition
	public var alphabetExpand: Dictionary<Symbol, Array<Symbol>> {
		var dict: Dictionary<Symbol, Array<Symbol>> = [:]
		for i in 0..<symbols.count {
			let label = symbols[parents[i]].lowerBound
			dict[label, default: []] += Array(symbols[i])
		}
		return dict
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

	/// Get all the set of symbols in the same partition as the given symbol
	public func siblings(_ symbol: Symbol) -> Partition {
		let index = self.findIndex(symbol)
		guard let index else { fatalError("Cannot find \(symbol) in \(symbols)") }
		let parent = self.parents[index]
		return self.symbols.enumerated().compactMap { self.parents[$0]==parent ? $1 : nil }
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

	public func meet(_ other: Self) -> Self {
		return Self.meet([self, other])
	}
	public static func meet(_ i: Array<Self>) -> Self {
		return SymbolClass(partitions: i.flatMap(\.partitions))
	}

	/// The union of a partitioned set is the meet of the union of each cross products of the two sets of partitions
	/// So the union of two part-sets with one partition each will have one partition
	/// But the union of part-sets with more than one partition will be the meet of their partitions.
	public func union(_ other: __owned Self) -> Self {
		fatalError("Unimplemented")
	}

	public func intersection(_ other: Self) -> Self {
		fatalError("Unimplemented")
	}

	public func symmetricDifference(_ other: __owned Self) -> Self {
		fatalError("Unimplemented")
	}

	public mutating func formUnion(_ other: __owned Self) {
		self = self.union(other)
	}

	public mutating func formIntersection(_ other: Self) {
		self = self.intersection(other)
	}

	public mutating func formSymmetricDifference(_ other: __owned Self) {
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

	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.symbols == rhs.symbols
	}

	// TODO: A function that generates a SymbolClassDFA from a DFA and SymbolClass

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
