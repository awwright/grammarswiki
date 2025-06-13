/// An Alphabet stores a set of symbol classes: Partitions on a set of symbols that all have the same behavior within some context.
/// The Alphabet has two core features: Iterating over the partitions, and intersecting multiple partitions to create a new symbol class.
///
/// RandomAccessCollection is required to be used in ForEach in SwiftUI
/// ExpressibleByArrayLiteral for initializing with default values
/// Equatable for comparison
public protocol AlphabetProtocol: Collection, ExpressibleByArrayLiteral, Equatable, Hashable where Element == SymbolClass {
	// TODO: Add an interface exposing the binary relation tuples, so you can go: set.tuples ~= (a, b)
	/// This type may be any type that can compute intersections, etc.
	associatedtype SymbolClass: Equatable & Hashable;
	associatedtype Symbol: Equatable & Hashable;
	associatedtype ArrayLiteralElement = SymbolClass;
	associatedtype PartitionedDictionary: AlphabetTableProtocol where PartitionedDictionary.Alphabet == Self, PartitionedDictionary.Value == AnyHashable, PartitionedDictionary.Element == (key: PartitionedDictionary.Key, value: AnyHashable);
	associatedtype DFATable: AlphabetTableProtocol where DFATable.Alphabet == Self, DFATable.Value == Int, DFATable.Element == (key: DFATable.Key, value: DFATable.Value)
	associatedtype NFATable: AlphabetTableProtocol where NFATable.Alphabet == Self, NFATable.Value == Set<Int>, NFATable.Element == (key: NFATable.Key, value: NFATable.Value)

	/// Initialize a PartitionedSet with the given elements, taking the union-meet of the subsets
	/// If elements appear in multiple partitions, elements found in the same partitions are split out and merged into a new partition
	/// (so that they never share a partition with elements they didn't share with in all partitions).
	init(partitions: Array<SymbolClass>)
	/// Copy symbols from another Alphabet.
	///
	/// - Note: Classes may be split apart, but should be preserved as much as possible.
	init<T: FiniteAlphabetProtocol>(alphabet: T) where T.Symbol == Symbol
//	init<T: AlphabetProtocol>(range: T) where T: Collection, T.Element == Symbol
	/// Generate a SymbolClass containing the given Symbol
	static func range(_ symbol: Symbol) -> SymbolClass
	/// Determine if the partitioned set contains the given value as a component
	func contains(_ component: Symbol) -> Bool
	/// Get the set of symbols from the partition of the given symbol
	func siblings(of: Symbol) -> SymbolClass
	/// Determine if the given two components exist in the same partition
	func isEquivalent(_ lhs: Symbol, _ rhs: Symbol) -> Bool
//	/// Create an Alphabet that contains the same (or some related) set of symbols, in a different shaped symbol class.
//	/// The partitions can legally be split apart, but cannot be merged together.
//	func mapSymbolClass<Target: AlphabetProtocol>(_ transform: (Self.SymbolClass) -> Target.SymbolClass) -> Target where Target.Symbol == Symbol
	/// Get some sort of identifier that uniquely identifies the partition with the given symbol
	/// It is Hashable so it can be used as a Dictionary key.
	/// It is assumed the symbol exists in the alphabet.
	static func label(of: SymbolClass) -> Symbol
	func label(of: Symbol) -> Symbol

	/// Inserts the given partition into the Alphabet, refining partitions when the symbols already exists
	mutating func insert(_ newPartition: SymbolClass)

	/// Removes the given components from the Alphabet
	mutating func remove(_ removePartition: SymbolClass)
}

/// Default implementations of functions for PartitionedSetProtocol
extension AlphabetProtocol {
	public init(arrayLiteral elements: SymbolClass...) {
		self.init(partitions: elements)
	}

//	public func mapSymbolClass<Target: AlphabetProtocol>(_ transform: (SymbolClass) -> Target.SymbolClass) -> Target where Self.Symbol == Target.Symbol {
//		Target(partitions: self.map { transform($0) })
//	}
	public subscript(_ component: Symbol) -> SymbolClass? {
		contains(component) ? siblings(of: component) : nil
	}
}

public protocol FiniteAlphabetProtocol: AlphabetProtocol {
	static func collection(_: SymbolClass) -> any Collection<Symbol>
}

extension FiniteAlphabetProtocol {
	func toAlphabet<T: FiniteAlphabetProtocol>() -> T where T.Symbol == Symbol {
		T(alphabet: self)
	}
}

// TODO: Define CharsetProtocol, a subset of AlphabetProtocol that has a guaranteed mapping to Character/String

/// An Alphabet where every symbol is its own SymbolClass
public struct SymbolAlphabet<Symbol: Hashable>: FiniteAlphabetProtocol, Hashable {
	public typealias Symbol = Symbol
	public typealias SymbolClass = Symbol
	public typealias Table<T> = Dictionary<Symbol, T>
	public typealias PartitionedDictionary = Dictionary<Symbol, AnyHashable>
	public typealias NFATable = Dictionary<Symbol, Set<Int>>
	public typealias DFATable = Dictionary<Symbol, Int>

	public var symbols: Set<Symbol>

	public init() {
		self.symbols = []
	}

	public init<T: FiniteAlphabetProtocol>(alphabet: T) where T.Symbol == Symbol {
		let symbols: Array<Symbol> = alphabet.flatMap { Array(T.collection($0)) }
		self.symbols = Set(symbols)
	}

	public init(partitions: some Collection<SymbolClass>) {
		self.symbols = Set(partitions)
	}

	public static func range(_ symbol: Symbol) -> SymbolClass {
		return symbol
	}

	public func contains(_ symbol: Symbol) -> Bool{
		symbols.contains(symbol)
	}

	public func siblings(of: Symbol) -> SymbolClass {
		guard contains(of) else { fatalError() }
		return of
	}

	public func isEquivalent(_ lhs: Symbol, _ rhs: Symbol) -> Bool {
		lhs == rhs
	}

	public static func label(of: Symbol) -> Symbol {
		of
	}

	public func label(of: Symbol) -> Symbol {
		of
	}

	// MARK: Collection
	public typealias Element = SymbolClass
	public typealias Index = Set<Symbol>.Index
	public var startIndex: Index { symbols.startIndex }
	public var endIndex: Index { symbols.endIndex }
	public func index(after i: Index) -> Index { symbols.index(after: i) }
	public subscript(position: Index) -> Element { symbols[position] }
	public static func collection(_ range: Symbol) -> any Collection<Symbol> { AnyCollection([range]) }

	// MARK: Mutations
	public mutating func insert(_ newElement: SymbolClass) {
		symbols.insert(newElement)
	}

	public mutating func remove(_ newElement: SymbolClass) {
		symbols.remove(newElement)
	}
}

extension SymbolAlphabet: ClosedRangeAlphabetProtocol where Symbol: Strideable & BinaryInteger, Symbol.Stride: SignedInteger {
	public static func range(_ range: ClosedRange<Symbol>) -> Self {
		.init(partitions: Set(range))
	}
}

public struct SetAlphabet<Symbol: Hashable & Comparable>: FiniteAlphabetProtocol {
	public typealias Symbol = Symbol
	public typealias SymbolClass = Set<Symbol>
	public typealias PartitionedDictionary = Table<AnyHashable>
	public typealias NFATable = Table<Set<Int>>
	public typealias DFATable = Table<Int>

	public var partitions: Set<SymbolClass>

	public init() {
		self.partitions = []
	}

	public init<T: FiniteAlphabetProtocol>(alphabet: T) where Symbol == T.Symbol {
		self.partitions = Set(alphabet.map { Set(T.collection($0)) })
	}

	public init(partitions: some Collection<Set<Symbol>>) {
		let symbols = partitions.flatMap { $0 }
		var dict: Dictionary<Set<Int>, Set<Symbol>> = [:]
		for s in symbols {
			let sets = Set(partitions.enumerated().compactMap { $0.1.contains(s) ? $0.0 : nil })
			dict[sets, default: []].insert(s)
		}
		self.partitions = Set(dict.values)
	}

	public static func range(_ symbol: Symbol) -> SymbolClass {
		return [symbol]
	}

	public func contains(_ symbol: Symbol) -> Bool{
		partitions.contains(where: { $0.contains(symbol) })
	}

	public func siblings(of: Symbol) -> Set<Symbol> {
		partitions.filter { $0.contains(of) }.first ?? []
	}

	public func isEquivalent(_ lhs: Symbol, _ rhs: Symbol) -> Bool {
		siblings(of: lhs).contains(rhs)
	}

	/// This may be somewhat inefficent! But it's the best one can do as a stable identifier when Symbol is not Comparable.
	public static func label(of: SymbolClass) -> Symbol {
		of.sorted().first!
	}
	public func label(of: Symbol) -> Symbol {
		siblings(of: of).sorted().first!
	}

	// MARK: Collection
	public typealias Element = SymbolClass
	public typealias Index = Set<SymbolClass>.Index

	public var startIndex: Index {
		partitions.startIndex
	}

	public var endIndex: Index {
		partitions.endIndex
	}

	public func index(after i: Index) -> Index {
		partitions.index(after: i)
	}

	public subscript(position: Index) -> Element {
		partitions[position]
	}

	public static func collection(_ range: SymbolClass) -> any Collection<Symbol> {
		AnyCollection<Symbol>(range)
	}

	/// Mutations
	public mutating func insert(_ newElement: SymbolClass) {
		var remainingNewElements = newElement;
		for part in partitions {
			let common = newElement.intersection(part)
			if !common.isEmpty {
				remainingNewElements.subtract(common)
				partitions.remove(part)
				partitions.insert(common)
				partitions.insert(part.subtracting(common))
			}
		}
		if !remainingNewElements.isEmpty {
			partitions.insert(remainingNewElements)
		}
	}

	public mutating func remove(_ removeSymbols: SymbolClass) {
		for part in partitions {
			let common = removeSymbols.intersection(part)
			if !common.isEmpty {
				partitions.remove(part)
				partitions.insert(part.subtracting(removeSymbols))
			}
		}
	}

	public struct Table<Value: Hashable>: AlphabetTableProtocol {
		public typealias Alphabet = SetAlphabet
		public typealias Symbol = SetAlphabet.Symbol
		public typealias SymbolClass = SetAlphabet.SymbolClass
		public typealias Key = SymbolClass
		public typealias Value = Value
		public typealias Element = (key: Key, value: Value)
		public typealias Index = Dictionary<Value, SymbolClass>.Index
		public typealias Values = Dictionary<Value, SymbolClass>.Keys

		var partitions: Dictionary<Value, SymbolClass>;

		public var alphabet: Alphabet { Alphabet(partitions: partitions.values) }
		public var values: Values { partitions.keys }

		public init() { partitions = [:] }
		public init(_ elements: Dictionary<Set<Symbol>, Value>) {
			self.partitions = [:]
			for (part, value) in elements {
				self[part] = value
			}
		}
		public init(dictionaryLiteral elements: (SymbolClass, Value)...) {
			self.partitions = [:]
			for (part, value) in elements {
				self[part] = value
			}
		}

		public subscript(symbol symbol: Symbol) -> Value? {
			for (value, part) in self.partitions {
				if part.contains(symbol) {
					return value
				}
			}
			return nil
		}

		public subscript(_ symbol: SymbolClass) -> Value? {
			get {
				for (value, part) in self.partitions {
					if part.isSubset(of: symbol) {
						return value
					}
				}
				return nil
			}
			set(newValue) {
				if let newValue {
					for (value, range) in self.partitions {
						if value == newValue {
							continue;
						}
						let newRange = range.intersection(symbol);
						if range == newRange {
							self.partitions.removeValue(forKey: value)
						} else {
							self.partitions[value] = range.subtracting(newRange);
						}
					}
					self.partitions[newValue] = self.partitions[newValue, default: []].union(symbol)
				} else {
					for (value, range) in self.partitions {
						if value == newValue {
							continue;
						}
						let newRange = range.intersection(symbol);
						if range == newRange {
							self.partitions.removeValue(forKey: value)
						} else {
							self.partitions[value] = range.subtracting(newRange);
						}
					}
				}
			}
		}

		// MARK: Collection
		public var startIndex: Index { self.partitions.startIndex }
		public var endIndex: Index { self.partitions.endIndex }
		public func index(after i: Index) -> Index { self.partitions.index(after: i) }
		public subscript(position: Index) -> Element {
			let (value, symbolClass) = partitions[position]
			return (key: symbolClass, value: value)
		}
	}
}

extension SetAlphabet: ClosedRangeAlphabetProtocol where Symbol: Strideable & BinaryInteger, Symbol.Stride: SignedInteger {
	public static func range(_ range: ClosedRange<Symbol>) -> Self {
		.init(partitions: [Set(range)])
	}
}

public protocol ClosedRangeAlphabetProtocol: AlphabetProtocol where Symbol: Comparable {
	static func range(_: ClosedRange<Symbol>) -> Self
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
public struct ClosedRangeAlphabet<Symbol: Comparable & Hashable>: FiniteAlphabetProtocol, ClosedRangeAlphabetProtocol, Hashable, CustomStringConvertible where Symbol: Strideable & BinaryInteger, Symbol.Stride: SignedInteger {
	public typealias Symbol = Symbol
	// MARK: Type definitions
	/// Implements PartitionedSetProtocol
	public typealias SymbolClass = Array<ClosedRange<Symbol>>
	public typealias PartitionedDictionary = Table<AnyHashable>
	public typealias DFATable = Table<Int>
	public typealias NFATable = Table<Set<Int>>
	public typealias Element = SymbolClass
	public typealias Index = Array<SymbolClass>.Index

	// MARK: Properties
	/// Ordered list of all symbols (and ranges) in the class
	var symbols: Array<ClosedRange<Symbol>>
	/// A tree partitioning elements together
	var parents: Array<Int>
	/// Lists the the first range in each partition
	var parts: Array<SymbolClass>

	// MARK: Initializations
	/// Empty initialization
	public init() {
		self.symbols = []
		self.parents = []
		self.parts = []
	}

	/// Initialize from pre-sorted data
	init(symbols: Array<ClosedRange<Symbol>>, parents: Array<Int>) {
		self.symbols = symbols
		self.parents = parents
		self.parts = []
		self.resort()
	}

	/// Convenience function for writing `SymbolClass([a, b, c, ...], [d, e, f, ...], ...)`
	public init(_ partitions: Array<Symbol>...) {
		self.init(partitions: partitions.map { $0.map { $0...$0 } })
	}

	/// Convenience function for writing `SymbolClass([0...5], [10...20], ...)`
	public init(_ partitions: SymbolClass...) {
		self.init(partitions: partitions)
	}

	public init<T: FiniteAlphabetProtocol>(alphabet: T) where Symbol == T.Symbol {
		self.init(partitions: alphabet.map{ T.collection($0).map{$0...$0} })
	}

	public init(arrayLiteral elements: SymbolClass...) {
		self.init(partitions: elements)
	}

	/// Create from an array of Symbols
	public init(alphabet: some Collection<some Collection<Symbol>>) {
		self.init(partitions: alphabet.map{ $0.map { $0...$0 } })
	}

	/// Initialize from a lower SetAlphabet
	public init(_ from: SymbolAlphabet<Symbol>) {
		self.init(alphabet: from.map{ $0...$0 })
	}
	public init(_ from: SetAlphabet<Symbol>) {
		self.init(partitions: from.map{ $0.map { $0...$0 } })
	}

	/// Merge together multiple partitions
	/// Symbols may appear in multiple partitions (the ranges may overlap), in which case the overlap will be split into its own partition.
	/// Also, ranges may appear out of order, although ranges within a partition may not overlap (I will not guarantee the behavior).
	public init(partitions: some Collection<Array<ClosedRange<Symbol>>>) {
		// Trivial cases
		if partitions.isEmpty {
			self.symbols = []
			self.parents = []
			self.parts = []
			return
		}

		var events: [(Bool, Symbol, Int)] = []
		for (index, innerArray) in partitions.enumerated() {
			let ranges = innerArray.sorted { $0.lowerBound < $1.lowerBound }
			var i = 0;
			while i < ranges.count {
				events.append((true, ranges[i].lowerBound, index))
				while i < ranges.count - 1 && ranges[i].upperBound >= ranges[i + 1].lowerBound - 1 {
					i += 1
				}
				events.append((false, ranges[i].upperBound, index))
				i += 1
			}
			// TODO: this can be merged together with the next for loop to avoid an intermediate `events` array and sort call
		}

		events.sort { e1, e2 in
			if e1.1 != e2.1 {
				return e1.1 < e2.1
			}
			// start comes before end
			return e1.0 && !e2.0
		}

		var symbols: [ClosedRange<Symbol>] = []
		// Distinguishing which boundary the symbol came from is necessary in order to not overflow the Symbol
		var currentStart: Symbol? = nil
		var currentEnd: Symbol? = nil;
		var depth = 0
		var members = Array(repeating: false, count: partitions.count)
		var members_parent: Dictionary<Array<Bool>, Int> = [:]
		var parents: Array<Int> = []
		for (side, p, index) in events {
			if side {
				if currentStart == nil, let currentEnd {
					currentStart = currentEnd + 1
				}
				if depth > 0, let start = currentStart, start < p {
					members_parent[members] = members_parent[members] ?? symbols.count
					symbols.append(start...(p - 1))
					parents.append(members_parent[members]!)
				}
				currentStart = p
				currentEnd = nil
				members[index] = true
				depth += 1
			} else {
				if let currentStart, currentStart <= p {
					members_parent[members] = members_parent[members] ?? symbols.count
					symbols.append(currentStart...p)
					parents.append(members_parent[members]!)
				} else if let currentEnd, currentEnd < p {
					members_parent[members] = members_parent[members] ?? symbols.count
					symbols.append((currentEnd+1)...p)
					parents.append(members_parent[members]!)
				}
				depth -= 1
				members[index] = false
				currentStart = nil
				currentEnd = (depth > 0) ? p : nil
			}
		}

		self.symbols = symbols
		self.parents = parents
		self.parts = []
		self.resort()
	}

	public static func range(_ range: ClosedRange<Symbol>) -> ClosedRangeAlphabet<Symbol> {
		.init(partitions: [[range]])
	}

	public static func range(_ symbol: Symbol) -> SymbolClass {
		return [symbol...symbol]
	}

	// MARK: Various accessors

	public var partitionLabels: Array<Symbol> {
		self.parents.filter { $0 == parents[$0] }.map{ symbols[$0].lowerBound }
	}

	/// Maps partition label to set of values in partition
	public var alphabet: SymbolClass {
		symbols
	}

	/// Maps partition label to set of values in partition
	private var partitions: Array<SymbolClass> {
		return parts;
		let labels = Set(parents).sorted()
		var dict: Dictionary<Int, Array<ClosedRange<Symbol>>> = Dictionary(uniqueKeysWithValues: labels.map { ($0, []) })
		for i in 0..<symbols.count {
			let label = parents[i]
			dict[label]!.append(symbols[i])
		}
		return labels.map { dict[$0]! }
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
	public func siblings(of symbol: Symbol) -> SymbolClass {
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

	/// This may be somewhat inefficent! But it's the best one can do as a stable identifier when Symbol is not Comparable.
	public func label(of: Symbol) -> Symbol {
		siblings(of: of).sorted { $0.lowerBound < $1.lowerBound }.first!.lowerBound
	}
	public static func label(of: SymbolClass) -> Symbol {
		of.sorted { $0.lowerBound < $1.lowerBound }.first!.lowerBound
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

	/// Find the first range at or above the given symbol
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

	// MARK: Collection
	public var startIndex: Index {
		0
	}

	public var endIndex: Index {
		parts.endIndex
	}

	public func index(after i: Index) -> Index {
		parts.index(after: i)
	}

	public subscript(position: Index) -> Element {
		parts[position]
	}

	public static func collection(_ range: SymbolClass) -> any Collection<Symbol> {
		AnyCollection(range.lazy.joined())
	}

	// CustomStringConvertable
	public var description: String {
		"\(Self.self)(" + self.map { "[" + $0.map { "\($0)" }.joined(separator: ", ") + "]" }.joined(separator: ", ") + ")"
	}

	/// Mutations
	public mutating func insert(_ newElement: SymbolClass) {
		// TODO: Optimize this
		self = Self(partitions: partitions + [newElement])
	}

	public mutating func remove(_ removeSymbols: SymbolClass) {
		// TODO: Optimize this
		self = Self(partitions: partitions.map { Self.difference($0, Self.intersection($0, removeSymbols)) })
	}

	private mutating func resort() {
		self.parts = Array(Dictionary(grouping: self.parents.enumerated(), by: { $0.1 }).mapValues { $0.map { symbols[$0.0] } }.values).sorted()
	}

	public struct Table<Value: Hashable>: AlphabetTableProtocol {
		public typealias Alphabet = ClosedRangeAlphabet
		public typealias SymbolClass = ClosedRangeAlphabet.SymbolClass
		public typealias Symbol = ClosedRangeAlphabet.Symbol
		public typealias Key = SymbolClass
		public typealias Value = Value
		public typealias Element = (key: Key, value: Value)
		public typealias Keys = ClosedRangeAlphabet<Symbol>
		public typealias Values = Array<Value>
		public typealias Index = Dictionary<Value, SymbolClass>.Index

		var partitions: Dictionary<Value, SymbolClass>;

		public var alphabet: Alphabet {
			Alphabet(partitions: partitions.values)
		}

		public var values: Values {
			partitions.keys.map { $0 as Value }
		}

		public init() {
			partitions = [:]
		}

		public init(_ elements: Dictionary<Array<ClosedRange<Symbol>>, Value>) {
			self.partitions = [:]
			for (part, value) in elements {
				self[part] = value
			}
		}
		public init(dictionaryLiteral elements: (SymbolClass, Value)...) {
			self.partitions = [:]
			for (part, value) in elements {
				self[part] = value
			}
		}

		public subscript(symbol symbol: Symbol) -> Value? {
			for (value, part) in self.partitions {
				// TODO: Performance improvement
				if part.contains(where: { $0.contains(symbol) }) {
					return value
				}
			}
			return nil
		}

		public subscript(partition: SymbolClass) -> Value? {
			get {
				var matchingValue: Value? = nil
				for (value, storedPartition) in partitions {
					// Check if storedPartition completely contains the input partition
					let isContained = partition.allSatisfy { range in
						storedPartition.contains { storedRange in
							storedRange.lowerBound <= range.lowerBound && range.upperBound <= storedRange.upperBound
						}
					}
					if isContained {
						// If we already found a match, multiple partitions contain the input, so return nil
						if matchingValue != nil {
							return nil
						}
						matchingValue = value
					}
				}
				return matchingValue
			}
			set {
				if let newValue {
					for (value, range) in self.partitions {
						if value == newValue {
							continue;
						}
						let newRange = ClosedRangeAlphabet.intersection(range, partition);
						if range == newRange {
							self.partitions.removeValue(forKey: value)
						} else {
							self.partitions[value] = ClosedRangeAlphabet.difference(range, newRange);
						}
					}
					self.partitions[newValue] = ClosedRangeAlphabet.union(self.partitions[newValue, default: []], partition)
				} else {
					for (value, range) in self.partitions {
						if value == newValue {
							continue;
						}
						let newRange = ClosedRangeAlphabet.intersection(range, partition);
						if range == newRange {
							self.partitions.removeValue(forKey: value)
						} else {
							self.partitions[value] = ClosedRangeAlphabet.difference(range, newRange);
						}
					}
				}
			}
		}

		// MARK: Collection
		public var startIndex: Index { self.partitions.startIndex }
		public var endIndex: Index { self.partitions.endIndex }
		public func index(after i: Index) -> Index { self.partitions.index(after: i) }
		public subscript(position: Index) -> Element {
			let (value, symbolClass) = partitions[position]
			return (key: symbolClass, value: value)
		}
	}

	// MARK: Utility
	private static func union(_ lhs: SymbolClass, _ rhs: SymbolClass) -> SymbolClass {
		let merged = (lhs + rhs).sorted(by: { $0.lowerBound < $1.lowerBound })
		var result: [ClosedRange<Symbol>] = []
		for range in merged {
			if result.isEmpty || result.last!.upperBound < range.lowerBound - 1 {
				result.append(range)
			} else {
				let last = result.removeLast()
				result.append(last.lowerBound...Swift.max(last.upperBound, range.upperBound))
			}
		}
		return result
	}

	private static func intersection(_ lhs: SymbolClass, _ rhs: SymbolClass) -> SymbolClass {
		var result: [ClosedRange<Symbol>] = []
		var i = 0
		var j = 0
		let sortedA = lhs.sorted(by: { $0.lowerBound < $1.lowerBound })
		let sortedB = rhs.sorted(by: { $0.lowerBound < $1.lowerBound })
		while i < sortedA.count && j < sortedB.count {
			let rangeA = sortedA[i]
			let rangeB = sortedB[j]
			if rangeA.upperBound < rangeB.lowerBound {
				i += 1
			} else if rangeB.upperBound < rangeA.lowerBound {
				j += 1
			} else {
				let lower = Swift.max(rangeA.lowerBound, rangeB.lowerBound)
				let upper = Swift.min(rangeA.upperBound, rangeB.upperBound)
				result.append(lower...upper)
				if rangeA.upperBound < rangeB.upperBound {
					i += 1
				} else {
					j += 1
				}
			}
		}
		return result
	}

	private static func difference(_ lhs: SymbolClass, _ rhs: SymbolClass) -> SymbolClass {
		var result: [ClosedRange<Symbol>] = []
		for rangeA in lhs {
			var current = rangeA.lowerBound
			let overlappingB = rhs.filter { $0.overlaps(rangeA) }.sorted(by: { $0.lowerBound < $1.lowerBound })
			for rangeB in overlappingB {
				if current < rangeB.lowerBound {
					result.append(current...(rangeB.lowerBound - 1))
				}
				current = Swift.max(current, rangeB.upperBound + 1)
			}
			if current <= rangeA.upperBound {
				result.append(current...rangeA.upperBound)
			}
		}
		return result
	}
}

public typealias RangeDFA<Symbol: BinaryInteger> = SymbolClassDFA<ClosedRangeAlphabet<Symbol>> where Symbol.Stride: SignedInteger;

public protocol AlphabetTableProtocol: Collection, ExpressibleByDictionaryLiteral, Equatable, Hashable where Key == Alphabet.SymbolClass, Element == (key: Key, value: Value) {
	associatedtype Alphabet: AlphabetProtocol
	associatedtype Value;
	associatedtype Values: Collection where Values.Element == Value
//	typealias Element = (key: Key, value: Value)
//	init(_ elements: Dictionary<Alphabet.SymbolClass, Value>)
	//init<S: Sequence>(uniqueKeysWithValues: S) where S.Element == (Key, Value)
	var alphabet: Alphabet { get }
	var values: Values { get }

//	func get(element: Alphabet.Symbol) -> Value?
//	func get(forKey: Alphabet.SymbolClass) -> Value?
//	func updateValue(_: Value, forKey: Alphabet.SymbolClass) -> Value?
	subscript(_ of: Alphabet.SymbolClass) -> Value? { get set }
	subscript(symbol of: Alphabet.Symbol) -> Value? { get }

	// TODO: I can't figure out how you would write this
	//func mapValues<T: AlphabetTableProtocol>(_: (Value) throws -> T.Value) rethrows -> T where T.Key == Key
}

public extension AlphabetTableProtocol {
	init(_ elements: Dictionary<Alphabet.SymbolClass, Value>) {
		self.init()
		for (part, value) in elements {
			self[part] = value;
		}
	}
	init<S: Sequence>(uniqueKeysWithValues: S) where S.Element == (Key, Value) {
		self.init()
		for (part, value) in uniqueKeysWithValues {
			self[part] = value;
		}
	}
}

extension Dictionary: AlphabetTableProtocol where Key: Hashable, Value: Equatable & Hashable {
	public typealias Alphabet = SymbolAlphabet<Key>
	public init(_ elements: Dictionary<Alphabet.SymbolClass, Value>) {
		self = elements
	}
	public var alphabet: SymbolAlphabet<Key> {
		SymbolAlphabet(partitions: keys)
	}
	public subscript(symbol of: Alphabet.Symbol) -> Value? {
		self[of]
	}
}

/// A variation of a Dictionary that allows setting a range of keys (possibly continuous ranges of values) and looking up values within the range.
/// There's no grouping of keys other than the values they can point to, so ranges that point to the same value will become "grouped".
public struct AlphabetTable<Alphabet: AlphabetProtocol & Hashable, Value: Equatable>: AlphabetTableProtocol where Alphabet.Symbol: Hashable, Value: Hashable {
	public typealias Alphabet = Alphabet
	public typealias SymbolClass = Alphabet.SymbolClass
	public typealias Symbol = Alphabet.Symbol
	public typealias Value = Value
	public typealias Element = Dictionary<Alphabet.SymbolClass, Value>.Element
	public typealias Values = Array<Value>
	public typealias Index = Alphabet.PartitionedDictionary.Index

	var storage: Alphabet.PartitionedDictionary;

	public var alphabet: Alphabet {
		storage.alphabet
	}

	public var values: Values {
		storage.values.map { $0 as! Value }
	}

	public init() {
		self.storage = Alphabet.PartitionedDictionary()
	}

	// Implements ExpressibleByDictionaryLiteral
	public init(_ elements: Dictionary<Alphabet.SymbolClass, Value>) {
		self.storage = [:]
		for (part, value) in elements {
			self.storage[part] = value
		}
	}

	public init(dictionaryLiteral elements: (Alphabet.SymbolClass, Value)...) {
		self.storage = [:]
		for (key, value) in elements {
			self.storage[key] = value
		}
	}

	public subscript(position: Dictionary<Alphabet.Symbol, Value>.Index) -> Dictionary<Alphabet.Symbol, Value>.Element {
		get {
			fatalError("init(uniqueKeysWithValues:) has not been implemented")
		}
		set {
			fatalError("init(uniqueKeysWithValues:) has not been implemented")
		}
	}

	public subscript(of: Alphabet.SymbolClass) -> Value? {
		get {
			storage[of] as! Value?
		}
		set(newValue) {
			storage[of] = newValue
		}
	}
	public subscript(symbol symbol: Alphabet.Symbol) -> Value? {
		storage[symbol: symbol] as! Value?
	}

	// MARK: Collection
	public var startIndex: Index { self.storage.startIndex }
	public var endIndex: Index { self.storage.endIndex }
	public func index(after i: Index) -> Index { self.storage.index(after: i) }
	public subscript(position: Index) -> Element { fatalError() }

	// MARK: Equatable
	public static func == (lhs: AlphabetTable<Alphabet, Value>, rhs: AlphabetTable<Alphabet, Value>) -> Bool {
		lhs.storage == rhs.storage
	}
}
