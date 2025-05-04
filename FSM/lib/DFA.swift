public protocol DFAProtocol: NFAProtocol {
	var states: Array<Dictionary<SymbolClass, Int>> { get }
	var initial: Int { get }
	// `finals` from NFAProtocol
}

extension DFAProtocol {
	/// Implements NFAProtocol
	/// In a DFA, there is exactly one transition per state
	public var statesSet: Array<Dictionary<SymbolClass, Set<Int>>> {
		states.map {
			$0.mapValues { Set([$0]) }
		}
	}

	/// Implements NFAProtocol
	/// In a DFA, there is exactly one initial state
	public var initials: Set<Int> {
		Set([initial])
	}

	/// Implements NFAProtocol
	/// In a DFA, there are no epsilon transitions, so this is filled in.
	public var epsilon: Array<Set<Int>> {
		return Array(repeating: [], count: states.count)
	}
}

/// A Deterministic Finite Automaton (DFA) that recognizes a set of sequences over a given alphabet.
/// It is an optimized form of ``NFA`` where each state has at most one "next" state.
/// It represents a set of strings (possibily infinitely large), where each string is a finitely long sequence of symbols, from a finitely large alphabet.
/// It can represent any such set of strings that are "regular" (describable with a finite state machine).
///
/// An element of the set is also known as a "string".
/// A character in the string/element is also known as a "symbol".
/// The set of possible symbols that can be used is called the "alphabnet". In this implementation, the alphabet is computed implicitly.
///
/// States are represented by an Int, or nil, the oblivion state.
/// The initial state cannot be `nil`, so at least one state must be provided.
///
/// - Type Parameters:
///   - `Element`: The type of sequence (e.g., `Array<UInt8>`), which must conform to `Hashable`, `Sequence`, `EmptyInitial`, and `Comparable`.
///   - `Element.Element`: The symbol type (e.g., `UInt8`), which must be `Hashable` and `Comparable`.
///
/// - Note: States are represented by integers (`StateNo`), with `nil` as the "oblivion" (non-accepting sink) state.
public struct DFA<Symbol: Hashable>: Hashable, DFAProtocol, RegularLanguageSetAlgebra {
	// TODO: Implement BidirectionalCollection
	public typealias Alphabet = SymbolAlphabet<Symbol>

	/// A partition might contain more than one symbols, represented with a different type.
	/// Presently, each symbol forms its own partition.
	public typealias SymbolClass = Alphabet.SymbolClass
	/// Default element type produced reading this as a Sequence
	public typealias Element = Array<SymbolClass>
	/// The type used to index states
	public typealias StateNo = Int;
	/// The type of a set of states, which in the case of a DFA is optional to include the oblivion state (`nil`).
	public typealias States = StateNo?;

	/// The transition table, mapping each state to a dictionary of symbol-to-next-state transitions.
	public let states: Array<Dictionary<SymbolClass, StateNo>>;
	/// The initial state of the DFA.
	public let initial: StateNo;
	/// The set of accepting (final) states.
	public let finals: Set<StateNo>;

	/// Creates an empty DFA that accepts no sequences.
	public init() {
		self.states = [ [:] ];
		self.initial = 0;
		self.finals = [];
	}

	/// Creates a DFA with specified states, initial state, and final states.
	///
	/// - Parameters:
	///   - states: The transition table; defaults to an empty state if not provided.
	///   - initial: The starting state; must be within `states` bounds.
	///   - finals: The set of accepting states; all must be within `states` bounds.
	/// - Precondition: All referenced states must exist within `states`.
	public init(
		states: Array<Dictionary<SymbolClass, StateNo>> = [],
		initial: StateNo = 0,
		finals: Set<StateNo> = []
	) {
		// Sanity check that the target states actually exist
		for transitions in states {
			for (_, state) in transitions {
				assert(state >= 0);
				assert(state < states.count);
			}
		}
		assert(initial >= 0);
		assert(initial < states.count);
		for state in finals {
			assert(state >= 0);
			assert(state < states.count);
		}

		self.states = states;
		self.initial = initial;
		self.finals = finals;
	}

	/// Creates a DFA that accepts exactly the given sequence.
	///
	/// - Parameter verbatim: The sequence to recognize (e.g., `[UInt8(97), UInt8(98)]` for "ab").
	///
	/// You can also provide an array literal, e.g. `DFA([element])`
	public init(verbatim: some Collection<Symbol>){
		let states = verbatim.enumerated().map { [ $1: $0 + 1 ] } + [[:]]
		self.init(
			states: states,
			initial: 0,
			finals: [ states.count-1 ]
		)
	}

	/// Creates a DFA out of an NFA.
	///
	/// - Parameter nfa: The NFA to convert.
	/// - Precondition: The NFA must have at most one transition per symbol per state.
	public init(nfa: NFA<SymbolClass>){
		let translation = NFA<SymbolClass>.parallel(fsms: [nfa], merge: { $0[0] });
		assert(translation.statesSet.allSatisfy { $0.allSatisfy { $0.value.count == 1 } })
		self.states = translation.statesSet.map { $0.mapValues { $0.first! } }
		self.initial = translation.initials.first!;
		self.finals = translation.finals;
	}

	public static func == (lhs: Self, rhs: Self) -> Bool {
		if(
			lhs.states == rhs.states &&
			lhs.initial == rhs.initial &&
			lhs.finals == rhs.finals
		){
			return true;
		}
		let difference = lhs.symmetricDifference(rhs);
		return difference.finals.isEmpty;
	}

	public var alphabet: Alphabet {
		Alphabet(partitions: self.states.flatMap(\.keys))
	}

	public var alphabetPartitions: Set<Set<SymbolClass>> {
		// If two symbols follow the same path, they might have the same behavior.
		return alphabetCombine(states.indices.flatMap { v in targets(source: v).values })
	}

	/// Generates a Graphviz DOT representation of the DFA for visualization.
	///
	/// - Returns: A string in DOT format, viewable with tools like Graphviz.
	public func toViz() -> String {
		var viz = "";
		viz += "digraph G {\n";
		viz += "\t_initial [shape=point];\n";
		viz += "\t_initial -> \(initial);\n";
		for source in states.indices {
			let shape = finals.contains(source) ? "doublecircle" : "circle";
			viz += "\t\(source) [label=\"\(source)\", shape=\"\(shape)\"];\n";
			for (target, symbols) in targets(source: source) {
				viz += "\t\(source) -> \(target) [label=\(graphvizLabelEscapedString(symbols.map { String(describing: $0) }.joined(separator: " ")))];\n";
			}
		}
		viz += "}\n";
		return viz;
	}

	/// Get a table of all of the symbols that point to each state, from some given state
	public func targets(source state: StateNo) -> Dictionary<StateNo, Set<SymbolClass>> {
		var partitions: Dictionary<StateNo, Set<SymbolClass>> = [:];
		for (symbol, target) in states[state] {
			partitions[target, default: []].insert(symbol);
		}
		return partitions
	}

	/// Get a table of all of the symbols that transition from and to the given states
	public func targets(source state: StateNo, target: StateNo) -> Set<SymbolClass> {
		return targets(source: state)[target] ?? []
	}

	/// Transitions from a state on a given symbol.
	///
	/// - Parameters:
	///   - state: The state to compute a transition from.
	///   - symbol: The input symbol.
	/// - Returns: The next state, or `nil` if no transition exists.
	public func nextState(state: StateNo, symbol: SymbolClass) -> States {
		assert(state >= 0)
		assert(state < self.states.count)
		return self.states[state][symbol];
	}

	/// Compute multiple transitions over a whole sequence.
	///
	/// - Parameters:
	///   - state: The starting state.
	///   - input: The sequence to process.
	/// - Returns: The resulting state, or `nil` if any transition fails.
	public func nextState(state: StateNo, input: any Sequence<SymbolClass>) -> States {
		assert(state >= 0)
		assert(state < self.states.count)
		var currentState = state;
		for char in input {
			guard currentState < self.states.count,
					let nextState = self.states[currentState][char]
			else {
				return nil
			}
			currentState = nextState
		}

		return currentState;
	}

	/// Checks if a state is accepting.
	///
	/// - Parameter state: The state to check (may be `nil`).
	/// - Returns: `true` if the state is final, `false` otherwise (always `false` for `nil`).
	public func isFinal(_ state: StateNo?) -> Bool {
		guard let state else { return false }
		return self.finals.contains(state)
	}

	/// Checks if a state is accepting.
	///
	/// - Parameter states: The state to check (may be `nil`).
	/// - Returns: `true` when any state is a final state, `false` otherwise.
	public func isFinal(_ states: Set<StateNo>) -> Bool {
		self.finals.contains(where: { states.contains($0) })
	}

	/// Attempts to match the longest prefix of the input that reaches a final state.
	///
	/// This is particularly useful for writing tokenizers.
	///
	/// - Parameter input: The input collection to match against.
	/// - Returns: A tuple of the matched prefix and remaining input, or `nil` if no match exists.
	public func match<T>(_ input: T) -> (T.SubSequence, T.SubSequence)? where T: Collection<SymbolClass> {
		var currentState = self.initial;
		// Test the initial condition
		var finalIndex: T.Index? = self.isFinal(currentState) ? input.startIndex : nil;

		// If we reach the end or nil, then there can be no more final states.
		for currentIndex in input.indices {
			let symbol = input[currentIndex];
			if let nextState = self.states[currentState][symbol] {
				currentState = nextState;
			} else {
				break;
			}
			assert(currentState < self.states.count);
			if(self.isFinal(currentState)){
				finalIndex = input.index(after: currentIndex)
			}
		}

		guard let finalIndex else { return nil; }
		assert(finalIndex >= input.startIndex, "Index is too low");
		assert(finalIndex <= input.endIndex, "Index is too high");

		return (input[input.startIndex..<finalIndex], input[finalIndex...])
	}

	/// Instant Description (ID), describes a FSM and its specific state during execution
	public struct ID {
		public typealias OuterDFA = DFA<Symbol>

		public let fsm: OuterDFA
		public let state: StateNo

		/// Indicates if the current state of the ID is a final state
		public var isFinal: Bool {
			fsm.isFinal(state)
		}

		/// Returns new ID after consuming the given symbol
		public subscript(symbol: SymbolClass) -> Self? {
			let state = self.fsm.states[self.state][symbol];
			if let state {
				return Self.init(fsm: self.fsm, state: state)
			}else{
				return nil;
			}
		}

		/// Returns a new DFA whose initial state is the current state
		public var derived: OuterDFA {
			OuterDFA(
				states: self.fsm.states,
				initial: self.state,
				finals: self.fsm.finals
			)
		}
	}

	/// Get the ID of the state machine without any input
	var initialDescription: ID {
		return ID(fsm: self, state: initial);
	}

	/// Get the ID of the state machine at a specific state
	subscript(state: StateNo) -> Self.ID {
		return Self.ID(fsm: self, state: state)
	}

	/// Get a FSM representing all the inputs that get you to an equivalent state
	/// I.e. all of the other inputs that will produce the same results with any additional input
	/// I.e. all the values of `other` where `other + extra == input + extra` for all `extra`
	/// Combine this with tags on states to distinguish different end states that have different semantics
	/// However, this will return `nil` if input lands on a non-live state.
	/// In this case, it is equivalent to all inputs that land on a non-live state, which canot be enumerated without an alphabet. So don't do that.
	public func equivalentInputs(input: any Sequence<SymbolClass>) -> Self? {
		// Minimizing the FSM ensures that there's no equivalent final states
		// If the FSM is already minimized this should be a somewhat speedy operation
		let minimized = self.minimized()
		var currentState = minimized.initial;
		for char in input {
			guard currentState < minimized.states.count, let nextState = minimized.states[currentState][char]
			else { return nil } //uh-oh, now we have to find all of the oblivion states
			currentState = nextState
		}
		return Self(
			states: minimized.states,
			initial: minimized.initial,
			finals: [currentState]
		).minimized()
	}

	// TODO: Give these default values (self.initial and self.finals, respectively)
	/// Return a DFA representing all the paths from `source` to `target`
	public func subpaths(source: StateNo?, target: some Collection<StateNo>) -> Self {
		guard let source else {	return Self.empty }
		return Self(states: states, initial: source, finals: Set(target)).minimized()
	}

	/// Provides a list of all the tuples (alpha, symbol, beta) where alpha matches strings that can come before the given symbol, and beta matches all the strings that come after.
	/// Symbol matches the input symbol and any other symbols that can be found in between alpha and beta.
	/// This function is used to partition
	// TODO: This could also return a Dict? A beta value is unique per alpha value
	public func symbolContext(input: SymbolClass) -> Array<(alpha: Self, symbols: Self, beta: Self)> {
		self.states.enumerated().compactMap {
			(source, table) in
			let target = table[input]
			guard let target else { return nil }
			// Get all of the keys that map to the same target
			let symbols: Array<SymbolClass> = table.keys.filter { table[$0] == target }
			return (
				alpha: self.subpaths(source: self.initial, target: [source]),
				symbols: Self(symbols.map { [$0] }),
				beta: self.subpaths(source: target, target: self.finals)
			)
		}
	}

	/// Derive a new FSM using a parallel construction
	///
	/// This crawls all the different possible combinations of states that can be reached from every possible input.
	///
	/// - Parameter fsms: The DFAs to merge together.
	/// - Parameter merge: Given an array of the states for the respective FSMs, return if this is a final state.
	/// 	To find a union, return true if any is true. To find the intersection, return true only when all are true.
	///
	public static func parallel(fsms: [Self], merge: ([Bool]) -> Bool) -> Self {
		var newStates = Array<Dictionary<SymbolClass, StateNo>>();
		var newFinals = Set<StateNo>();
		var forward = Dictionary<Array<States>, StateNo>();
		var backward = Array<Array<States>>();

		// TODO: See if using the FSM-wide alphabet is cheaper
		// e.g. let alphabet = fsms.reduce(Set<Symbol>()) { $0.union($1.alphabet) }

		func forwardStateId(inStates: Array<States>) -> StateNo {
			if let next = forward[inStates] {
				return next;
			}
			let next = backward.count;
			backward.insert(inStates, at: next);
			assert(backward.count == next + 1);
			forward[inStates] = next;
			return next;
		}

		// The initial state of the new FSM maps to the initial state of the original FSMs
		let initialStates = fsms.map { $0.initial }
		let newInitialState = forwardStateId(inStates: initialStates);
		assert(newInitialState == 0);

		var newStateId = 0;
		while(newStateId < backward.count){
			var newStateTransitions = Dictionary<SymbolClass, StateNo>();
			let inStates = backward[newStateId];
			var alphabets = Set<SymbolClass>();
			// enumerate over inStates and build the alphabet for the new state
			for (fsm, state) in zip(fsms, inStates) {
				if let state {
					alphabets.formUnion(fsm.states[state].keys);
				}
			}
			// For each of the symbols in the alphabet, get the next state following the current one
			for symbol in alphabets {
				let nextStates = zip(fsms, inStates).map { (fsm, state) in state == nil ? nil : fsm.nextState(state: state!, symbol: symbol) }
				newStateTransitions[symbol] = forwardStateId(inStates: nextStates)
			}

			newStates.insert(newStateTransitions, at: newStateId);
			if(merge(zip(fsms, inStates).map { (fsm, state) in state == nil ? false : fsm.finals.contains(state!) })) {
				newFinals.insert(newStateId)
			}

			newStateId += 1;
		}

		return Self.init(states: newStates, initial: newInitialState, finals: newFinals);
	}

	/// Minimizes this DFA by merging equivalent states.
	/// A minimized DFA has the fewest number of states possible of any equivalent DFA.
	/// It does this by merging states with the "same" behavior into the same state.
	/// Implemented by Hopcroft's Algorithm.
	/// - Returns: The minimized DFA
	public func minimized() -> Self {
		// Step 1: Remove unreachable states
		var reachable = Set<Int>([initial])
		var reachableStates = [initial]
		var index = 0
		while index < reachableStates.count {
			let current = reachableStates[index]
			index += 1
			for nextState in states[current].values {
				if reachable.insert(nextState).inserted {
					reachableStates.append(nextState)
				}
			}
		}

		// Step 2. Remove dead states
		var coReachable = Set<Int>(finals).intersection(reachable)
		var coReachableList = Array(coReachable)
		index = 0
		while index < coReachableList.count {
			let current = coReachableList[index]
			index += 1
			for (state, transitions) in states.enumerated() {
				for nextState in transitions.values {
					if nextState == current && coReachable.insert(state).inserted {
						coReachableList.append(state)
					}
				}
			}
		}
		reachableStates = reachableStates.filter { coReachable.contains($0) }
		let stateMap = Dictionary(uniqueKeysWithValues: reachableStates.enumerated().map { ($1, $0) })
		if(stateMap.isEmpty) {
			return Self.empty
		}
		let trimmedStates = reachableStates.map { state in
			// Remove transitions to dead states, remap remaining transitions
			Dictionary(uniqueKeysWithValues: states[state].compactMap { if let target = stateMap[$0.value] { ($0.key, target) } else { nil } })
		}
		let trimmedFinals = Set(finals.intersection(reachableStates).map { stateMap[$0]! })
		let trimmedInitial = stateMap[initial]!

		// Initialize partition with accepting and non-accepting states
		var partition = [Set<Int>]()
		let accepting = Set(0..<trimmedStates.count).intersection(trimmedFinals)
		let nonAccepting = Set(0..<trimmedStates.count).subtracting(trimmedFinals)

		if !accepting.isEmpty {
			partition.append(accepting)
		}
		if !nonAccepting.isEmpty {
			partition.append(nonAccepting)
		}

		// Initialize worklist with symbols from alphabet
		let alphabet = Set(trimmedStates.flatMap { $0.keys })
		var worklist = alphabet.map { ($0, partition) }

		// Refine partitions
		while !worklist.isEmpty {
			let (symbol, currentPartition) = worklist.removeFirst()

			// Map each state to its block index in the current partition
			let stateToPartition = Dictionary(uniqueKeysWithValues: currentPartition.enumerated().flatMap { (index, set) in set.map { ($0, index) } })
			var newPartition = [Set<Int>]()
			var changed = false

			for block in currentPartition {
				// Group states by the block of their transition target
				let transitions = Dictionary(grouping: block) { state -> Int? in
					if let target = trimmedStates[state][symbol] {
						return stateToPartition[target]
					} else {
						return nil // Handle incomplete DFA if necessary
					}
				}

				if transitions.count > 1 {
					changed = true
					newPartition.append(contentsOf: transitions.values.map { Set($0) })
				} else {
					newPartition.append(block)
				}
			}

			if changed {
				// Remove old partition and add new ones
				worklist = worklist.filter { $1 != currentPartition }
				worklist.append(contentsOf: alphabet.map { ($0, newPartition) })
				partition = newPartition
			}
		}

		let stateToPartition = Dictionary(uniqueKeysWithValues: partition.enumerated().flatMap { (index, set) in set.map { ($0, index) } })
		let newStates = partition.map {
			return Dictionary(uniqueKeysWithValues: trimmedStates[$0.first!].map { ($0.key, stateToPartition[$0.value]!) })
		}
		let newInitial = stateToPartition[trimmedInitial]!
		let newFinals = Set(partition.enumerated().filter { trimmedFinals.contains($1.first!) }.map { $0.offset })

		return Self(states: newStates, initial: newInitial, finals: newFinals)
	}

	/// Maps the DFA’s symbols to a new type.
	///
	/// - Parameter transform: A function mapping each symbol to a new symbol type.
	/// - Returns: A new DFA with transformed transitions.
	public func mapSymbols<Target>(_ transform: (SymbolClass) -> Target) -> DFA<Target> {
		let newStates = states.map {
			// Map the key of the dictionary using `transform`
			Dictionary(uniqueKeysWithValues: $0.map { (key, value) in
				(transform(key), value)
			})
		}
		assert(newStates.count == states.count)
		return DFA<Target>(
			states: newStates,
			initial: self.initial,
			finals: self.finals
		)
	}

	/// Checks if the DFA accepts a given sequence (element of the language)
	public func contains(_ input: some Sequence<Symbol>) -> Bool {
		var currentState = self.initial;

		for symbol in input {
			guard currentState < self.states.count,
					let nextState = self.states[currentState][symbol]
			else {
				return false
			}
			currentState = nextState
		}

		return self.finals.contains(currentState)
	}

	/// Returns a DFA accepting the union of this DFA’s language and another’s.
	/// Implements ``SetAlgebra``
	public func union(_ other: __owned Self) -> Self {
		return Self.parallel(fsms: [self, other], merge: { $0[0] || $0[1] });
	}

	/// Returns a DFA accepting the intersection of this DFA’s language and another’s.
	/// Implements ``SetAlgebra``
	public func intersection(_ other: Self) -> Self {
		return Self.parallel(fsms: [self, other], merge: { $0[0] && $0[1] });
	}

	/// Returns a DFA accepting the symmetric difference of this DFA’s language and another’s.
	/// That is, the set of elements in exactly one set or the other set, and not both.
	/// To only remove elements, see ``subtracting(_:)`` or the ``-(lhs:rhs:)`` operator
	public func symmetricDifference(_ other: __owned Self) -> Self {
		return Self.parallel(fsms: [self, other], merge: { $0[0] != $0[1] });
	}

	// Also provide a static implementation of union since it applies to any number of inputs
	public static func union(_ languages: Array<Self>) -> Self {
		if(languages.count == 0){
			return Self();
		} else if(languages.count == 1) {
			return languages[0];
		}
		return Self.parallel(fsms: languages, merge: { $0.contains(where: { $0 }) });
	}

	/// Finds the language of all the the ways to join a string from the first language with strings in the second language
	public static func concatenate(_ languages: Array<Self>) -> Self {
		if(languages.count == 0){
			// Concatenation identity is epsilon
			return Self(states: [[:]], initial: 0, finals: [0]);
		} else if(languages.count == 1) {
			return languages[0];
		}
		let nfa = NFA<SymbolClass>.concatenate(languages.map { NFA<SymbolClass>($0) });
		return Self(nfa: nfa);
	}

	public func concatenate(_ other: Self) -> Self {
		return Self.concatenate([self, other]);
	}

	public static func symbol(_ element: SymbolClass) -> Self {
		return Self(
			states: [[element: 1], [:]],
			initial: 0,
			finals: [ 1 ]
		)
	}

	/// Return a DFA that also accepts the empty sequence
	/// i.e. adds the initial state to the set of final states
	public func optional() -> Self {
		return Self(
			states: self.states,
			initial: self.initial,
			finals: self.finals.union([self.initial])
		);
	}

	/// Returns a DFA accepting one or more repetitions of its language.
	public func plus() -> Self {
		let nfa = NFA<SymbolClass>(
			states: self.states.map { $0.mapValues { Set([$0]) } },
			// Add an epsilon transition from the final states to the initial state
			epsilon: self.states.enumerated().map { stateNo, _ in self.finals.contains(stateNo) ? [self.initial] : [] },
			initial: self.initial,
			finals: self.finals
		);
		return Self(nfa: nfa);
	}

	/// Returns a DFA accepting zero or more repetitions of its language.
	public func star() -> Self {
		return self.plus().optional();
		// Should be equal to:
		//let nfa = NFA<Element>(
		//	states: self.states.map { $0.mapValues { Set([$0]) } },
		//	// Add an epsilon transition from the final states to the initial state
		//	epsilon: self.states.enumerated().map { stateNo, _ in self.finals.contains(stateNo) ? [self.initial] : [] },
		//	initial: self.initial,
		//	finals: self.finals.union([self.initial])
		//);
		//return Self(nfa: nfa);
	}

	/// Returns a DFA accepting exactly `count` repetitions of its language.
	public func repeating(_ count: Int) -> Self {
		precondition(count >= 0)
		return Self.concatenate(Array(repeating: self, count: count))
	}

	/// Returns a DFA accepting between `range.lowerBound` and `range.upperBound` repetitions.
	public func repeating(_ range: ClosedRange<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return Self.concatenate(Array(repeating: self, count: range.lowerBound) + Array(repeating: self.optional(), count: Int(range.upperBound-range.lowerBound)));
	}

	/// Returns a DFA accepting `range.lowerBound` or more repetitions.
	public func repeating(_ range: PartialRangeFrom<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return Self.concatenate(Array(repeating: self, count: range.lowerBound) + [self.star()])
	}

	//func derive(_ input: Element) -> Self
	//{
	//	let nextStates = self.next(initial: self.initial, )
	//	return Self.init(states: self.states, initial: currentState, finals: self.finals);
	//}

	/// An iterator over all accepted sequences. Implements ``Sequence``.
	///
	/// Example:
	///
	/// ```
	/// for element in dfa { print(element) }
	/// ```x1
	public func makeIterator() -> Iterator where SymbolClass: Comparable {
		return Iterator(self);
	}

	/// A simple way to create a view on a struct to change how it is iterated or enumerated
	public struct IteratorFactory<T>: Sequence where T: IteratorProtocol {
		public typealias OuterDFA = DFA<Symbol>

		let dfa: OuterDFA;
		let constructor: (OuterDFA) -> T;
		init(_ dfa: OuterDFA, constructor: @escaping (OuterDFA) -> T) {
			self.dfa = dfa;
			self.constructor = constructor;
		}
		public func makeIterator() -> T {
			return constructor(dfa)
		}
	}

	/// Returns an iterator that walks over all of the possible of the paths in the state graph.
	/// - Parameter filter: A function that decides if the paths in the given state should be walked. This is for filtering out paths that have already been visited or otherwise don't mean anything.
	public func pathIterator(filter: @escaping (PathIterator, PathIterator.Path) -> Bool) -> IteratorFactory<PathIterator> where SymbolClass: Comparable {
		return IteratorFactory(self) {
			PathIterator($0, filter: filter);
		};
	}

	/// An iterator that can iterate over all of the elements of the FSM.
	/// Indefinitely, if need be.
	// TODO: Consider using AsyncStream for this
	public struct PathIterator: IteratorProtocol where SymbolClass: Comparable {
		public typealias OuterDFA = DFA<Symbol>
		public struct Segment: Equatable {
			public var source: StateNo
			public var index: Int
			public var symbol: SymbolClass
			public var target: StateNo
		};
		public typealias Path = Array<Segment>;
		let fsm: OuterDFA;
		let states: Array<Array<(symbol: SymbolClass, toState: StateNo)>>
		let filter: (Self, Path) -> Bool;

		var stack: Path;
		var visited: Set<StateNo>?;
		var started = false;

		init(_ fsm: OuterDFA, filter: @escaping (Self, Path) -> Bool) {
			// let fsm = options.fsm;
			self.fsm = fsm;
			self.filter = filter;

			// First we want to figure out the "live" states, the states from where it's still possible to reach a final state
			// Usually all states in a FSM struct are live, unless the user did something funny in its construction.
			var reverse = Array<Set<StateNo>>(repeating: [], count: fsm.states.count);
			for(i, state) in fsm.states.enumerated() {
				for j in state.values {
					reverse[j].insert(i);
				}
			}

			var live = fsm.finals;
			var nextFinals = fsm.finals;
			repeat {
				// Find all of the states that reach a final
				nextFinals = Set(nextFinals.flatMap{ reverse[$0] }).subtracting(live);
				// If there's no new states, then we're done
				if(nextFinals.count == 0){
					break;
				}
				live.formUnion(nextFinals);
			} while true;

			// Precomputed values
			// Map the dictionary to an array of tuples, filter out transitions to dead states
			self.states = fsm.states.map { $0.map { (symbol: $0.key, toState: $0.value) }.filter { live.contains($0.toState) }.sorted { $0.0 < $1.0 } };

			self.stack = [];
		}

		init(_ fsm: OuterDFA) {
			self.init(fsm, filter: { _, _ in true });
		}

		// This needs a `filter` function to determine if we descend into the current state or not.
		// A `false` might be used to prevent loops, or to zskip over entire trees of uninteresting values.
		public mutating func next() -> Path? {
			if started == false {
				started = true;
				// An empty path is implicitly the inital state, where no segments have been followed
				return [];
			}
			if(stack.isEmpty){
				// There's nothing on the stack, so we're currently on the initial state,
				// and need to begin iterating over its transitions.
				if states[fsm.initial].count > 0 {
					// Follow the first state from the current state, if there is one
					stack.append(Segment(source: fsm.initial, index: 0, symbol: self.states[fsm.initial][0].symbol, target: self.states[fsm.initial][0].toState));
				}else{
					// The unlikely case where the initial state is the only state
					return nil;
				}
			} else if let previous = stack.last, states[previous.target].count > 0 {
				// Follow the first state from the current state, if there is one
				stack.append(Segment(source: previous.target, index: 0, symbol: self.states[previous.target][0].symbol, target: self.states[previous.target][0].toState));
			} else {
				// Prepare to increment the index by one, carrying down if necessary
				// Remove final elements that are on the last index
				while(stack.last!.index >= states[stack.last!.source].count - 1){
					stack.removeLast();
					if(stack.count == 0){
						return nil;
					}
				}
				if(stack.count == 0){ return nil };
				stack[stack.count-1].index += 1;
				stack[stack.count-1].symbol = self.states[stack[stack.count-1].source][stack[stack.count-1].index].symbol;
				stack[stack.count-1].target = self.states[stack[stack.count-1].source][stack[stack.count-1].index].toState;
			}
			// Run `filter` to see if we want to visit this state (true), or skipping it and all of its children (false)
			// If skip, then increment the index and carry up as necessary until we find a state to stay on
			while stack.isEmpty==false && filter(self, stack)==false {
				// Prepare to increment the index by one, carrying down if necessary
				// Remove final elements that are on the last index
				while(stack.last!.index >= states[stack.last!.source].count - 1){
					stack.removeLast();
					if(stack.count == 0){ return nil }
				}
				if(stack.count == 0){ return nil };
				stack[stack.count-1].index += 1;
				stack[stack.count-1].symbol = self.states[stack[stack.count-1].source][stack[stack.count-1].index].symbol;
				stack[stack.count-1].target = self.states[stack[stack.count-1].source][stack[stack.count-1].index].toState;
			}

			return stack;
		}
	}

	public struct Iterator: IteratorProtocol where SymbolClass: Comparable {
		public typealias OuterDFA = DFA<Symbol>
		public typealias Element = Array<SymbolClass>

		let fsm: OuterDFA;
		var iterator: PathIterator;
		var currentDepth: Int;

		init(_ fsm: OuterDFA) {
			// let fsm = options.fsm;
			self.fsm = fsm;
			self.iterator = PathIterator(fsm, filter: { _, path in path.count <= 0 });
			self.currentDepth = 0;
		}

		public mutating func next<T>() -> T? where T: SymbolSequenceProtocol, T.Element == SymbolClass {
			while currentDepth <= fsm.states.count {
				while let stack = iterator.next() {
					if stack.count < currentDepth { continue }
					// TODO: if repeats == .Skip then keep iterating this until we have a value that's not used by an ancestor
					let state = stack.isEmpty ? fsm.initial : stack.last!.target;
					if fsm.finals.contains(state) {
						return stack.reduce(T.empty, { $0.appending(iterator.states[$1.source][$1.index].symbol) });
					}
				}
				self.currentDepth += 1
				let maxDepth = currentDepth;
				self.iterator = PathIterator(fsm, filter: { _, path in path.count <= maxDepth });
			}
			return nil;
		}
	}

	// Now we're really getting into alchemy land
	/// This follows all the paths walked by a set of strings provided as another DFA
	/// It takes a state and follows all the states from `state` according to the input FSM and returns the ones that are marked final according to that input FSM
	public func nextStates(initial: StateNo, input: Self) -> Set<StateNo> where SymbolClass: Comparable {
		var finalStates: Set<StateNo> = [];
		//var derivative = DFA<Symbol>(
		//	states: self.states,
		//	initial: state,
		//	finals: self.finals
		//);
		func filter(iterator: PathIterator, path: PathIterator.Path) -> Bool {
			var current = initial;
			for segment in path {
				guard let nextState = self.states[current][segment.symbol] else { return false }
				current = nextState;
			}
			return true;
		}
		var iterator = PathIterator(input, filter: filter)
		loop: while let path = iterator.next() {
			let inputState = path.isEmpty ? input.initial : path.last!.target;
			if input.finals.contains(inputState) {
				// Compute the cooresponding state in self
				var current = initial;
				for segment in path {
					guard let nextState = self.states[current][segment.symbol] else { continue loop }
					current = nextState;
				}
				finalStates.insert(current);
			}
		}
		return finalStates;
	}

	public func homomorphism<Target>(mapping: [(some Collection<SymbolClass>, some Collection<Target>)]) -> DFA<Target> {
		let nfa: NFA<Target> = NFA<SymbolClass>(self).homomorphism(mapping: mapping);
		return DFA<Target>(nfa: nfa)
	}

	public func homomorphism<Target>(mapping: [(Self, DFA<Target>)]) -> DFA<Target> {
		let nfa: NFA<Target> = NFA<SymbolClass>(self).homomorphism(mapping: mapping);
		return DFA<Target>(nfa: nfa)
	}

	public func toPattern<PatternType: RegularPatternBuilder>(as: PatternType.Type? = nil) -> PatternType where PatternType.SymbolClass == SymbolClass {
		// Make a new initial state at 0, epsilon transition to old initial state
		// Create an empty new-final state at 1
		// And add epsilon transitions for all old-final states to new-final state at 1
		let empty = PatternType.empty;
		let epsilon = PatternType.epsilon;
		let newInitial: Dictionary<Int, PatternType> = [self.initial + 2: epsilon];
		let newFinal: Dictionary<Int, PatternType> = [:];

		// Convert the FSM to a FSM with regular expressions as the transitions
		var states: Array<Dictionary<Int, PatternType>> = [newInitial, newFinal] + self.states.enumerated().map {
			(oldNo, oldTable) in
			var newTable: Dictionary<Int, PatternType> = [:]

			// Merge transitions with the same source and target together
			// Renumber the states accordingly
			oldTable.forEach {
				(symbol, target) in
				newTable[target + 2] = newTable[target + 2, default: PatternType.empty].union(PatternType.symbol(symbol))
			}

			// If the state was a final state, add an epsilon transition to state 1
			if(self.finals.contains(oldNo)){
				newTable[1] = epsilon
			}
			return newTable;
		}

		// Begin state elimination
		// Iterate through non-final abnfFSM.states backwards
		var eliminating = states.count;
		while eliminating > 2 {
			eliminating -= 1;
			// Rewrite all two-segment paths def (d->e->f) to the form:
			// df' = df | de *ee ef
			// Precompute (*ee ef)
			var fe: Dictionary<Int, PatternType> = [:]
			for (f, segment) in states[eliminating] {
				fe[f] = segment
			}
			let ee = fe.removeValue(forKey: eliminating);
			var ee_ef_i: Dictionary<Int, PatternType> = [:]
			for (f, segment) in fe {
				ee_ef_i[f] = if let ee { ee.star().concatenate(segment) } else { segment }
			}
			states = (0..<eliminating).map {
				d in
				// Take the table of transitions for state d
				// If there are any transitions d->e
				var table = states[d];
				let de = table.removeValue(forKey: eliminating)
				if let de {
					// For each f from e, redraw transition e->f as d->f (add alternate to (union with) existing d->f as necessary)
					for (f, ee_ef) in ee_ef_i {
						if let existing_f = table[f] {
							// These first two options produce optimized versions
							if(existing_f == de){
								table[f] = de.concatenate(ee_ef.optional());
							}else if(existing_f == ee_ef){
								table[f] = de.optional().concatenate(ee_ef)
							}else{
								table[f] = existing_f.union(de.concatenate(ee_ef));
							}
						}else{
							table[f] = de.concatenate(ee_ef);
						}
					}
				}
				return table;
			};
		}

		// According to _Introduction to Automata Theory_...
		// Given an initial state ⓪, a final state ①, and paths ⓪-R→⓪, ⓪-S→①, ①-T→⓪, and ①-U→①,
		// the resulting regular expression will be (R | S U* T)* S U*
		assert(states.count == 2)
		let R = states[0][0] ?? empty;
		let S = states[0][1] ?? empty;
		let T = states[1][0] ?? empty;
		let U = states[1][1] ?? empty;
		return ( (R).union( (S).concatenate(U.star()).concatenate(T) ) ).star().concatenate(S).concatenate(U.star())
	}

	public mutating func insert(_ newMember: __owned Element) -> (inserted: Bool, memberAfterInsert: Element) {
		if(contains(newMember)) {
			return (false, newMember)
		}
		self = self.union(Self(verbatim: newMember));
		return (true, newMember)
	}

	public mutating func remove(_ member: Element) -> (Element)? {
		self.formSymmetricDifference(Self(verbatim: member));
		return member;
	}

	public mutating func update(with newMember: __owned Element) -> (Element)? {
		return insert(newMember).1
	}

	// Operator shortcuts

	/// Subtract/difference
	/// Returns a version of `lhs` but removing any elements in `rhs`
	///
	/// Note: I think (-) is pretty unambiguous here, but some math notation uses \ for this operation.
	public static func - (lhs: Self, rhs: Self) -> Self {
		return Self.parallel(fsms: [lhs, rhs], merge: { $0[0] && !$0[1] });
	}
}

extension DFA: Comparable, Sequence where SymbolClass: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		// Generate instances of each side, compare if lhs < rhs
		// If they are the same, generate next instance (in alphabetical order)
		// Test if they are equal, and return false if so (this is the same operation performed in func ==)
		let difference = lhs.symmetricDifference(rhs);
		if difference.finals.isEmpty {
			return false;
		}
		// Get the first item that exists in only one of the two
		var first = difference.makeIterator()
		let next: Element = first.next()!
		// If it exists in lhs, then lhs < rhs
		return lhs.contains(next)
	}

	// A sequence that walks over all of the different paths
	public var paths: IteratorFactory<PathIterator> {
		return IteratorFactory(self) {
			PathIterator($0)
		}
	};
}

// Conditional protocol compliance
extension DFA: Sendable where SymbolClass: Sendable {}

extension DFA where SymbolClass == Character {
//	typealias Element = String
	init (_ val: Array<String>) {
		self.init(val.map{ Array($0) })
	}

	public mutating func insert(_ newMember: __owned String) -> (inserted: Bool, memberAfterInsert: String) {
		if(contains(newMember)) {
			return (false, newMember)
		}
		self = self.union(Self(verbatim: newMember));
		return (true, newMember)
	}

	public mutating func remove(_ member: String) -> (String)? {
		self.formSymmetricDifference(Self(verbatim: member));
		return member;
	}
}
