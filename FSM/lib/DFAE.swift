// A DFA with Equivalence

/// A wrapper around a symbol of an existing FSM to also support transitions of another type
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
}

/// DFAE (DFA with Equivalence) is a struct that maps elements in the FSM to some target element.
/// You can also get a FSM denoting the set of elements in the same partition.
public struct DFAE<Element: SymbolSequenceProtocol & Hashable, PartNo: Comparable & Hashable> where Element.Element: Comparable & Hashable {
	typealias Symbol = Element.Element;
	typealias Inner = SymbolOrTag<Symbol, PartNo>;
	typealias SymTag = SymbolOrTag<Symbol, PartNo>;

	/// Specifies a set of elements and the partition they map to
	public let partitions: Dictionary<PartNo, DFA<Element>>

	/// The union of all the partitions, tagged with the partition
	let inner: DFA<Array<SymTag>>

	/// Final states and the partition they are members of
	let stateToTarget: Dictionary<DFA<Element>.StateNo, PartNo>

	init(partitions: Dictionary<PartNo, DFA<Element>>){
		let innerMap = partitions.map {
			(partNo, fsm) in
			DFA<Array<SymTag>>(
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
		let inner = DFA.union(innerMap)
		let stateToTarget = Dictionary(uniqueKeysWithValues: inner.finals.compactMap {
			stateNo in
			let table = inner.states[stateNo]
			var value: (DFA.StateNo, PartNo)? = nil
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

		self.partitions = partitions
		self.inner = inner
		self.stateToTarget = stateToTarget
	}

	subscript(_ value: Element) -> PartNo? {
		let resultState = self.inner.nextState(state: self.inner.initial, input: value.map { SymbolOrTag.symbol($0) })
		guard self.inner.isFinal(resultState) else { return nil }
		guard let resultState else { return nil }
		assert(resultState < self.inner.states.count)
		let resultTarget = stateToTarget[resultState]
		guard let resultTarget else { return nil }
		assert(self.inner.states[resultState][SymbolOrTag<Symbol, PartNo>.tag(resultTarget)] != nil)
		return resultTarget
	}
}
