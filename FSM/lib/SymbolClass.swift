/// An Alphabet stores a set of symbol classes: Partitions on a set of symbols that all have the same behavior within some context.
/// The Alphabet has two core features: Iterating over the partitions, and intersecting multiple partitions to create a new symbol class.
///
/// RandomAccessCollection is required to be used in ForEach in SwiftUI
/// ExpressibleByArrayLiteral for initializing with default values
/// Equatable for comparison
public protocol AlphabetProtocol: RandomAccessCollection, ExpressibleByArrayLiteral, Equatable, Hashable where Element == SymbolClass {
	// TODO: Add an interface exposing the binary relation tuples, so you can go: set.tuples ~= (a, b)
	/// This type may be any type that can compute intersections, etc.
	associatedtype SymbolClass: Equatable & Hashable;
	associatedtype Symbol: Equatable & Hashable;
	associatedtype DFATable: AlphabetTableProtocol where DFATable.Alphabet == Self, DFATable.Value == Int, DFATable.Element == (key: DFATable.Key, value: DFATable.Value)
	associatedtype NFATable: AlphabetTableProtocol where NFATable.Alphabet == Self, NFATable.Value == Set<Int>, NFATable.Element == (key: NFATable.Key, value: NFATable.Value)
//	typealias Element = SymbolClass

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

	/// Inserts the given partition into the Alphabet
	mutating func insert(_ newElement: SymbolClass)
}

/// Default implementations of functions for PartitionedSetProtocol
extension AlphabetProtocol {
	public init(arrayLiteral elements: SymbolClass...) {
		self.init(partitions: elements)
	}

//	public func mapSymbolClass<Target: AlphabetProtocol>(_ transform: (SymbolClass) -> Target.SymbolClass) -> Target where Self.Symbol == Target.Symbol {
//		Target(partitions: self.map { transform($0) })
//	}
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
	public typealias SymbolClass = Symbol
	public typealias ArrayLiteralElement = SymbolClass
	public typealias Table<T> = Dictionary<Symbol, T>
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

	public var startIndex: Index {
		symbols.startIndex
	}

	public var endIndex: Index {
		symbols.endIndex
	}

	public func index(before i: Index) -> Index {
		fatalError()
	}

	public func index(after i: Index) -> Index {
		symbols.index(after: i)
	}

	public subscript(position: Index) -> Element {
		symbols[position]
	}

	public static func collection(_ range: Symbol) -> any Collection<Symbol> {
		AnyCollection([range])
	}

	/// Mutations
	public mutating func insert(_ newElement: SymbolClass) {
		symbols.insert(newElement)
	}
}

public struct SetAlphabet<Symbol: Hashable & Comparable>: FiniteAlphabetProtocol {
	public typealias Symbol = Symbol
	public typealias SymbolClass = Set<Symbol>
	public typealias ArrayLiteralElement = SymbolClass
	public typealias NFATable = AlphabetTable<Self, Set<Int>>
	public typealias DFATable = AlphabetTable<Self, Int>
	public typealias Table<T: Equatable> = AlphabetTable<Self, T> where T: Hashable

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

	public func index(before i: Set<SymbolClass>.Index) -> Set<SymbolClass>.Index {
		fatalError()
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
}

public protocol ClosedRangeAlphabetProtocol: AlphabetProtocol {}

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
	/// Implements ExpressibleByArrayLiteral
	public typealias ArrayLiteralElement = SymbolClass
	public typealias DFATable = AlphabetTable<Self, Int>
	public typealias NFATable = AlphabetTable<Self, Set<Int>>
	public typealias Table<T: Equatable> = AlphabetTable<Self, T> where T: Hashable
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
	public init(partitions: some Collection<some Collection<ClosedRange<Symbol>>>) {
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
		}

		events.sort { e1, e2 in
			if e1.1 != e2.1 {
				return e1.1 < e2.1
			}
			// start comes before end
			return e1.0 && !e2.0
		}

		var symbols: [ClosedRange<Symbol>] = []
		var currentStart: Symbol? = nil
		var depth = 0
		var members = Array(repeating: false, count: partitions.count)
		var members_parent: Dictionary<Array<Bool>, Int> = [:]
		var parents: Array<Int> = []
		for (side, p, index) in events {
			if side {
				if depth > 0, let start = currentStart, start <= p - 1 {
					members_parent[members] = members_parent[members] ?? symbols.count
					symbols.append(start...(p - 1))
					parents.append(members_parent[members]!)
				}
				currentStart = p
				members[index] = true
				depth += 1
			} else {
				if let start = currentStart, start <= p {
					members_parent[members] = members_parent[members] ?? symbols.count
					symbols.append(start...p)
					parents.append(members_parent[members]!)
				}
				depth -= 1
				members[index] = false
				currentStart = (depth > 0) ? (p + 1) : nil
			}
		}

		self.symbols = symbols
		self.parents = parents
		self.parts = []
		self.resort()
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

	private mutating func resort() {
		self.parts = Array(Dictionary(grouping: self.parents.enumerated(), by: { $0.1 }).mapValues { $0.map { symbols[$0.0] } }.values).sorted()
	}
}

public protocol AlphabetTableProtocol: Collection, ExpressibleByDictionaryLiteral, Equatable, Hashable where Key == Alphabet.SymbolClass, Element == (key: Key, value: Value) {
	associatedtype Alphabet: AlphabetProtocol
	associatedtype Values: Collection where Values.Element == Value
//	typealias Element = (key: Key, value: Value)
	init(_ elements: Dictionary<Alphabet.SymbolClass, Value>)
	init<S: Sequence>(uniqueKeysWithValues: S) where S.Element == (Key, Value)
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
	public typealias Index = Alphabet.Index
	public typealias Element = Dictionary<Alphabet.SymbolClass, Value>.Element

	public var alphabet: Alphabet
	var dict: Dictionary<Alphabet.Symbol, Value>

	public init() {
		self.alphabet = Alphabet()
		self.dict = [:]
	}

	public init<S>(uniqueKeysWithValues: S) where S : Sequence, S.Element == (Alphabet.Element, Value) {
		var table = Self.init()
		for (part, index) in uniqueKeysWithValues {
			table[part] = index
		}
		self = table
	}

	public init(_ elements: Dictionary<Alphabet.SymbolClass, Value>) {
		self.init(uniqueKeysWithValues: elements.map { ($0.key, $0.value) })
	}

	public init(dictionaryLiteral elements: (Alphabet.SymbolClass, Value)...) {
		self.init(uniqueKeysWithValues: elements)
	}

	public subscript(position: Dictionary<Alphabet.Symbol, Value>.Index) -> Dictionary<Alphabet.Symbol, Value>.Element {
		get {
			fatalError("init(uniqueKeysWithValues:) has not been implemented")
		}
		set {
			fatalError("init(uniqueKeysWithValues:) has not been implemented")
		}
	}

	public var keys: Alphabet {
		alphabet
	}

	public var values: some Collection<Value> {
		dict.values
	}


	public subscript(of: Alphabet.SymbolClass) -> Value? {
		get {
			dict[Alphabet.label(of: of)]
		}
		set(newValue) {
			// Subdivide the alphabet
			alphabet.insert(of)
			// Assign values for any new partitions that appeared
			for range in alphabet {
				dict[Alphabet.label(of: range)] = dict[Alphabet.label(of: range)]
			}
			// Assign the value for the partition with the updated value
			dict[Alphabet.label(of: of)] = newValue
		}
	}
	public subscript(symbol of: Alphabet.Symbol) -> Value? {
		alphabet.contains(of) ? dict[alphabet.label(of: of)] : nil
	}

	// MARK: Collection
	public var startIndex: Index {
		alphabet.startIndex
	}

	public var endIndex: Index {
		alphabet.endIndex
	}

	public func index(after i: Index) -> Index {
		alphabet.index(after: i)
	}

	public subscript(position: Index) -> Element {
		let key: Alphabet.Element = alphabet[position]
		let value: Value = dict[Alphabet.label(of: key)]!
		return (key: key, value: value)
	}

	public static func == (lhs: AlphabetTable<Alphabet, Value>, rhs: AlphabetTable<Alphabet, Value>) -> Bool {
		lhs.alphabet == rhs.alphabet && lhs.dict == rhs.dict
	}
}
