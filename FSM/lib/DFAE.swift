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

/// DFAE (DFA with Equivalence) is a struct that maps elements in the FSM to some target element.
/// You can also get a FSM denoting the set of elements in the same partition.
public struct DFAE<Symbol: Comparable & Hashable, Value: Comparable & Hashable> {
	public typealias Key = Array<Symbol>
	public typealias Partition = DFA<Symbol>

	public typealias Partitions = Dictionary<Value, DFA<Symbol>>.Values
	public var partitions: Dictionary<Value, DFA<Symbol>>.Values { partitionsDict.values }

	typealias Inner = SymbolOrTag<Symbol, Value>;
	typealias SymTag = SymbolOrTag<Symbol, Value>;

	/// Specifies a set of elements and the partition they map to
	public let partitionsDict: Dictionary<Value, DFA<Symbol>>

	/// The union of all the partitions, tagged with the partition
	let inner: DFA<SymTag>

	/// Final states and the partition they are members of
	let stateToTarget: Dictionary<DFA<Symbol>.StateNo, Value>

	public init() {
		self.partitionsDict = [:]
		self.inner = []
		self.stateToTarget = [:]
	}

	init(partitions: Dictionary<Value, DFA<Symbol>>){
		let innerMap: Array<DFA<SymTag>> = partitions.map {
			(partNo, fsm) in
			DFA<SymTag>(
				// Convert the symbols to SymTag.symbol
				// If a final state, add a SymTag.tag pointing the state to itself
				states: fsm.states.enumerated().map {
					stateNo, table in
					Dictionary(uniqueKeysWithValues:
						table.map {	(key, target) in (SymTag.symbol(key), target) }
						+ (fsm.isFinal(stateNo) ? [(SymTag.tag(partNo), stateNo)] : [])
					)
				},
				initial: fsm.initial,
				finals: fsm.finals
			)
		}
		let inner = DFA<SymTag>.union(innerMap)
		let stateToTarget = Dictionary<DFA<Symbol>.StateNo, Value>(uniqueKeysWithValues: inner.finals.compactMap {
			stateNo in
			let table = inner.states[stateNo]
			var value: (DFA<Symbol>.StateNo, Value)? = nil
			for (key, _) in table {
				if case .tag(let tag) = key {
					if value != nil {
						fatalError("Partitions overlap at \(stateNo): \(value!) and \(tag)")
					}
					value = (stateNo, tag)
				}
			}
			return value
		})

		self.partitionsDict = partitions
		self.inner = inner
		self.stateToTarget = stateToTarget
	}

	public func contains(_ component: Key) -> Bool {
		self[component] != nil
	}

	subscript(_ value: some Sequence<Symbol>) -> Value? {
		let resultState = self.inner.nextState(state: self.inner.initial, input: value.map { SymbolOrTag<Symbol, Value>.symbol($0) })
		guard self.inner.isFinal(resultState) else { return nil }
		guard let resultState else { return nil }
		assert(resultState < self.inner.states.count)
		let resultTarget = stateToTarget[resultState]
		guard let resultTarget else { return nil }
		assert(self.inner.states[resultState][SymbolOrTag<Symbol, Value>.tag(resultTarget)] != nil)
		return resultTarget
	}


	func siblings(label: Value) -> DFA<Symbol>? {
		fatalError("Unimplemented")
	}

	func label(component: Key) -> Value? {
		fatalError("Unimplemented")
	}

	public func siblings(of val: Array<Symbol>) -> DFA<Symbol> {
		fatalError("Unimplemented")
	}

	public func isEquivalent(_ lhs: Key, _ rhs: Key) -> Bool {
		return self[lhs] == self[rhs]
	}
}
