// A DFA with Equivalence

/// A wrapper around a symbol of an existing FSM to also support transitions of another type
// TODO: Conformance with PartitionedSetProtocol
public enum SymbolOrTag<Symbol: Comparable & Hashable, Tag: Comparable & Hashable>: Comparable, Hashable {
	case symbol(Symbol)
	case tag(Tag)

	public static func < (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
			case (.symbol, .tag): return true
			case (.tag, .tag): if case .tag(let lhstr) = lhs, case .tag(let rhstr) = rhs { return lhstr < rhstr; }
			case (.symbol, .symbol): if case .symbol(let lhstr) = lhs, case .symbol(let rhstr) = rhs { return lhstr < rhstr; }
			case (.tag, .symbol): return false
		}
		return false;
	}

	var description: String {
		switch self {
			case .symbol(let str): return "\(str)"
			case .tag(let str): return "<\(str)>"
		}
	}
}

public struct PartitionedDFA<Component: Hashable>: AlphabetProtocol {
	public typealias SymbolClass = DFA<Component>
	public typealias Symbol = DFA<Component>.Element
	public typealias PartitionedDictionary = Table<AnyHashable>
	public typealias NFATable = Table<Set<Int>>
	public typealias DFATable = Table<Int>

	public var partitions: Set<SymbolClass>

	// MARK: Init
	public init() {
		self.partitions = []
	}

	public init<T: FiniteAlphabetProtocol>(alphabet: T) where Symbol == T.Symbol {
		fatalError()
	}

	public init(partitions: some Collection<SymbolClass>) {
		self.partitions = []
		// `partitions` may have overlaps, refine these partitions
		for part in partitions {
			self.insert(part);
		}
	}

	public static func range(_ symbol: Symbol) -> SymbolClass {
		SymbolClass([symbol]);
	}

	public func contains(_ symbol: Symbol) -> Bool {
		partitions.contains(where: { $0.contains(symbol) })
	}

	public func siblings(of: Symbol) -> SymbolClass {
		partitions.filter { $0.contains(of) }.first ?? []
	}

	public func isEquivalent(_ lhs: Symbol, _ rhs: Symbol) -> Bool {
		siblings(of: lhs).contains(rhs)
	}

	public static func label(of: SymbolClass) -> Symbol {
		fatalError()
	}

	public func label(of: Symbol) -> Symbol {
		fatalError()
	}

	/// Find the union of two DFAs, refine any partitions that overlap
	public func conjunction(_ other: Self) -> Self {
		var result = self
		for part in other {
			result.insert(part);
		}
		return result;
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

	public static func collection(_ range: SymbolClass) -> SymbolClass {
		range
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
				partitions.insert(part.subtracting(common))
			}
		}
	}

	public struct Table<Value: Hashable>: AlphabetTableProtocol {
		public typealias Alphabet = PartitionedDFA
		public typealias Symbol = PartitionedDFA.Symbol
		public typealias SymbolClass = PartitionedDFA.SymbolClass
		public typealias Key = SymbolClass
		public typealias Value = Value
		public typealias Element = (key: Key, value: Value)
		public typealias Index = Dictionary<Value, SymbolClass>.Index
		public typealias Values = Dictionary<Value, SymbolClass>.Keys

		var partitions: Dictionary<Value, SymbolClass>;

		// /// The union of all the partitions, tagged with the partition
		// typealias SymTag = SymbolOrTag<Component, Tag>
		// var tagged: DFA<SymTag>

		public var alphabet: Alphabet { Alphabet(partitions: partitions.values) }
		public var values: Values { partitions.keys }

		public init() { partitions = [:] }
		public init(_ elements: Dictionary<SymbolClass, Value>) {
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
			get {
				for (value, part) in self.partitions {
					if part.contains(symbol) {
						return value
					}
				}
				return nil
			}
			set(newValue) {
				let range = SymbolClass(verbatim: symbol);
				for (value, range) in self.partitions {
					self.partitions[value] = range.subtracting([symbol])
				}
				if let newValue {
					self.partitions[newValue] = self.partitions[newValue, default: []].union([symbol])
				}
			}
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

