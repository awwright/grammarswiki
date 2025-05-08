public protocol NFAProtocol: RegularLanguageProtocol, RegularLanguageSetAlgebra where Symbol: Hashable {
	var statesSet: Array<Alphabet.NFATable> {get};
	var epsilon: Array<Set<Int>> {get};
	var initials: Set<Int> {get};
	var finals: Set<Int> {get};

	func isFinal(_ state: Int?) -> Bool;
	func isFinal(_ state: Set<Int>) -> Bool;
}

// TODO: LosslessStringConvertible
// TODO: CustomDebugStringConvertible

public struct SymbolClassNFA<Alphabet: AlphabetProtocol>: NFAProtocol {
	// TODO: Implement BidirectionalCollection
	public typealias Symbol = Alphabet.Symbol
	public typealias SymbolClass = Alphabet.SymbolClass
	public typealias Element = Array<Symbol>
	public typealias StateNo = Int;
	public typealias States = Set<StateNo>;

	/// For each state, a mapping of the next input symbol to the set of states it should transition to
	public let statesSet: Array<Alphabet.NFATable>;
	/// For each state, a set of the states that should automatically be transitioned to
	public let epsilon: Array<Set<Int>>;
	// I allow initials to be a set of states so that the result of following from the initial state can be a closed operation
	/// The set of states to start on
	public let initials: Set<Int>;
	/// A set of states that matches the input symbols (just one final has to match to accept a given string)
	public let finals: Set<Int>;

	init(
		states: Array<Alphabet.NFATable> = [ [:] ],
		epsilon: Array<States> = [ [] ],
		initials: States = [0],
		finals: Set<Int> = []
	) {
		assert(states.count == epsilon.count);
		// Sanity check that the target states actually exist
		for transitions in states {
			for (_, nextStates) in transitions {
				for state in nextStates {
					assert(state >= 0);
					assert(state < states.count);
					assert(state < epsilon.count);
				}
			}
		}
		for nextStates in epsilon {
			for state in nextStates {
				assert(state >= 0);
				assert(state < states.count);
				assert(state < epsilon.count);
			}
		}
		for state in initials {
			assert(state >= 0);
			assert(state < states.count);
			assert(state < epsilon.count);
		}
		for state in finals {
			assert(state >= 0);
			assert(state < states.count);
			assert(state < epsilon.count);
		}

		self.statesSet = states;
		self.epsilon = epsilon;
		self.initials = initials;
		self.finals = finals;
	}

	// Empty set constructor, with one initial state and no final states
	public init() {
		self.init(states: [[:]], epsilon: [[]], initials: [0], finals: []);
	}

	// Variation with single initial state
	public init(
		states: Array<Alphabet.NFATable> = [],
		epsilon: Array<States> = [],
		initial: StateNo = 0,
		finals: Set<StateNo> = []
	) {
		self.init(states: states, epsilon: epsilon, initials: [initial], finals: finals)
	}

	public init(verbatim: some Sequence<Symbol>){
		// Generate one state per symbol in Element, plus a final state
		let states: Array<Alphabet.NFATable> = verbatim.enumerated().map { [ Alphabet.range($1): Set([$0 + 1]) ] } + [[:]]
		self.init(
			states: states,
			epsilon: Array(repeating: [], count: states.count),
			initials: [0],
			finals: [states.count-1]
		);
	}

	public init<T: NFAProtocol>(_ nfa: T) where T.Alphabet == Alphabet {
		self.init(
			states: nfa.statesSet,
			epsilon: nfa.epsilon,
			initials: nfa.initials,
			finals: nfa.finals
		)
	}

	//	static func == (lhs: Self, rhs: Self) -> Bool {
	//		if(
	//			lhs.states == rhs.states &&
	//			lhs.initial == rhs.initial &&
	//			lhs.finals == rhs.finals
	//		){
	//			return true;
	//		}
	//		// TODO also determine if the languages are equivalent
	//		return false;
	//	}

	public func toViz() -> String {
		var viz = "";
		viz += "digraph G {\n";
		viz += "\t_initial [shape=point];\n";
		for i in initials {
			viz += "\t_initial -> \(i) [style=\"dashed\"];\n";
		}
		for (i, transitions) in statesSet.enumerated() {
			let shape = finals.contains(i) ? "doublecircle" : "circle";
			viz += "\t\(i) [label=\"\(i)\", shape=\"\(shape)\"];\n";
			for target in epsilon[i] {
				viz += "\t\(i) -> \(target) [style=\"dashed\"];\n";
			}
			for (symbol, states) in transitions {
//				viz += "\t\(symbol) \(states)\n";
				for target in states {
					viz += "\t\(i) -> \(target) [label=\(graphvizLabelEscapedString(String(describing: symbol)))];\n";
				}
			}
		}
		viz += "}\n";
		return viz;
	}

	public var alphabet: Alphabet {
		Alphabet(partitions: self.statesSet.flatMap(\.alphabet))
	}

	public func nextStates(state: StateNo, symbol: Symbol) -> States {
		return self.nextStates(states: [state], symbol: symbol);
	}

	public func nextStates(state: StateNo, string: any Sequence<Symbol>) -> States {
		return self.nextStates(states: [state], string: string);
	}

	public func nextStates(states: States, range: SymbolClass) -> States {
		// Map each element in `states` to the next symbol in states[state][symbol], if it exists
		return self.followε(states: Set(self.followε(states: states).flatMap { self.statesSet[$0][range] ?? [] }))
	}

	public func nextStates(states: States, symbol: Symbol) -> States {
		// Map each element in `states` to the next symbol in states[state][symbol], if it exists
		return self.followε(states: Set(self.followε(states: states).flatMap { self.statesSet[$0][symbol: symbol] ?? [] }))
	}

	public func nextStates(states: States, string: any Sequence<Symbol>) -> States {
		var currentState = states;
		for symbol in string {
			currentState = self.nextStates(states: currentState, symbol: symbol)
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

	/// Tries to match as many characters from input as possible, returning the last final state
	public func match<T>(_ input: T) -> (T.SubSequence, T.SubSequence)? where T: Collection<Symbol> {
		var currentState = self.initials;
		var finalIndex: T.Index? = nil;

		// Test the initial condition
		if(self.isFinal(currentState)){
			finalIndex = input.startIndex;
		}

		// If we reach the end or nil, then there can be no more final states.
		for currentIndex in input.indices {
			let symbol = input[currentIndex];
			let nextState = self.nextStates(states: currentState, symbol: symbol)
			if nextState.isEmpty == false {
				currentState = nextState;
			} else {
				break;
			}
//			assert(currentState < self.states.count);
			if(self.isFinal(currentState)){
				finalIndex = input.index(after: currentIndex)
			}
		}

		guard let finalIndex else { return nil; }
		assert(finalIndex >= input.startIndex, "Index is too low");
		assert(finalIndex <= input.endIndex, "Index is too high");

		return (input[input.startIndex..<finalIndex], input[finalIndex...])
	}

	/// Get the ID of the state machine without any input
	public struct ID {
		public typealias OuterNFA = SymbolClassNFA<Alphabet>
		public let fsm: OuterNFA
		public let states: States

		public var isFinal: Bool {
			fsm.isFinal(states)
		}

		public subscript(symbol: Symbol) -> ID {
			let nextStates = self.fsm.nextStates(states: self.states, symbol: symbol)
			return ID(fsm: self.fsm, states: nextStates)
		}
	}

	/// Get the ID of the state machine at a specific state
	subscript(state: StateNo) -> Self.ID {
		return Self.ID(fsm: self, states: [state])
	}

	/// Get the ID of the state machine evaluating a set of states
	subscript(state: States) -> Self.ID {
		return Self.ID(fsm: self, states: state)
	}

	/// Get a list of states after following epsilon transitions,
	/// i.e. get a list of all the states equivalent to any of the given
	func followε(states: States) -> States {
		var expanded = states;
		var list = Array(states);
		// Iterate over every state in states
		var i = 0;
		while i < list.count {
			let state = list[i];
			let transitions = self.epsilon[state];
			for next in transitions {
				if(!expanded.contains(next)){
					expanded.insert(next);
					list.append(next);
				}
			}
			i += 1;
		}
		return expanded;
	}

	public static func parallel(fsms: [Self], merge: ([Bool]) -> Bool) -> Self {
		var newStates = Array<Alphabet.NFATable>();
		var newFinals = Set<Int>();
		var forward = Dictionary<Array<States>, Int>();
		var backward = Array<Array<States>>();

		func forwardStateId(inStates: Array<States>) -> Int {
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
		let initialStates = fsms.map { $0.followε(states: $0.initials) }
		let newInitialState = forwardStateId(inStates: initialStates);
		assert(newInitialState == 0);
		assert(backward.count == 1);

		var newStateId = 0;
		while(newStateId < backward.count){
			var newStateTransitions = Alphabet.NFATable();
			let inStates = backward[newStateId];
			var alphabets = Set<SymbolClass>();
			// enumerate over inStates and get the index
			for (fsm, states) in zip(fsms, inStates) {
				for state in states {
					alphabets.formUnion(fsm.statesSet[state].alphabet);
				}
			}
			// For each of the symbols in the alphabet, get the next state following the current one
			for range in alphabets {
				let nextStates = zip(fsms, inStates).map { (fsm, state) in fsm.nextStates(states: state, range: range) }
				newStateTransitions[range] = [forwardStateId(inStates: nextStates)]
			}

			newStates.insert(newStateTransitions, at: newStateId);
			if(merge(zip(fsms, inStates).map { (fsm, state) in fsm.finals.intersection(state).count > 0 })) {
				newFinals.insert(newStateId)
			}

			newStateId += 1;
		}

		return Self.init(states: newStates, epsilon: Array(repeating: [], count: newStates.count), initial: newInitialState, finals: newFinals);
	}

	public func contains(_ input: some Sequence<Symbol>) -> Bool {
		let final = self.nextStates(states: self.initials, string: input)
		return self.isFinal(final)
	}

	public func contains(_ input: Array<Symbol>) -> Bool {
		let final = self.nextStates(states: self.initials, string: input)
		return self.isFinal(final)
	}

	public func derive(_ input: any Sequence<Symbol>) -> Self
	{
		var currentState = self.initials;

		for symbol in input {
			let nextState = self.nextStates(states: currentState, symbol: symbol)
			if(nextState.count == 0){
				return SymbolClassNFA(states: [[:]], initial: 0, finals: []);
			}
			currentState = nextState
		}

		return Self.init(states: self.statesSet, epsilon: self.epsilon, initials: currentState, finals: self.finals);
	}

	public func union(_ other: __owned Self) -> Self {
//		return Self.parallel(dfas: [self, other], merge: { $0[0] || $0[1] });
		let offset = self.statesSet.count;
		let newStates = other.statesSet.map { Alphabet.NFATable(uniqueKeysWithValues: $0.map { ($0.0, Set($0.1.map { $0  + offset })) }) }
		let newEpsilon = other.epsilon.map { Set($0.map { $0  + offset }) }
		let newInitials = other.initials.map { $0  + offset }
		let newFinals = other.finals.map { $0  + offset }
		return Self(
			states: self.statesSet + newStates,
			epsilon: self.epsilon + newEpsilon,
			initials: self.initials.union(newInitials),
			finals: self.finals.union(newFinals)
		)
	}

	public func intersection(_ other: Self) -> Self {
		return Self.parallel(fsms: [self, other], merge: { $0[0] && $0[1] });
	}

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
		// In this case just reduce over the union,
		// that should be about as performant as looping over all of them,
		// and slightly simpler to reason about.
		return languages[1...].reduce(languages[0], { $0.union($1) })
	}

	/// Finds the language of all the the ways to join a string from the first language with strings in the second language
	public static func concatenate(_ languages: Array<Self>) -> Self {
		if(languages.count == 0){
			// Concatenation identity is epsilon
			return Self(states: [[:]], epsilon: [[]], initials: [0], finals: [0]);
		} else if(languages.count == 1) {
			return languages[0];
		}
		return languages[1...].reduce(languages[0], {
			previous, other in
			let offset = previous.statesSet.count;
			// Remap all of the state IDs
			let newStates = other.statesSet.map { Alphabet.NFATable(uniqueKeysWithValues: $0.map { ($0.0, Set($0.1.map { $0  + offset })) }) }
			let newEpsilon = other.epsilon.map { Set($0.map { $0  + offset }) };
			let newInitials = Set(other.initials.map { $0  + offset });
			let newFinals = Set(other.finals.map { $0  + offset });

			// Remap all of the state IDs, adding an epsilon transition from the previous final states to the current initial states
			let combinedEpsilon = previous.epsilon.enumerated().map {
				stateNo, set in
				return previous.finals.contains(stateNo) ? set.union(newInitials) : set;
			};
			return Self(
				states: previous.statesSet + newStates,
				epsilon: combinedEpsilon + newEpsilon,
				initials: previous.initials,
				finals: newFinals
			);
		});
	}

	public func concatenate(_ other: Self) -> Self {
		return Self.concatenate([self, other]);
	}

	public static func symbol(_ element: Symbol) -> Self {
		return Self(
			states: [[Alphabet.range(element): [1]], [:]],
			epsilon: [[], []],
			initials: [ 0 ],
			finals: [ 1 ]
		)
	}

	/// Adds the empty string to the set of accepted elements
	public func optional() -> Self {
		// Append a single state that is both a start and final state.
		// It has no transitions, so it won't match any other input.
		let lastNo = self.statesSet.count;
		return Self.init(
			states: self.statesSet + [[:]],
			epsilon: self.epsilon + [[]],
			initials: self.initials.union([lastNo]),
			finals: self.finals.union([lastNo])
		);
	}

	public func plus() -> Self {
		Self.init(
			states: self.statesSet,
			// Add an epsilon transition from the final states to the initial states
			epsilon: self.statesSet.enumerated().map { stateNo, _ in self.finals.contains(stateNo) ? self.initials : [] },
			initials: self.initials,
			finals: self.finals
		);
	}

	public func star() -> Self {
		return self.plus().optional();
	}

	public func repeating(_ count: Int) -> Self {
		precondition(count >= 0)
		return Self.concatenate(Array(repeating: self, count: count))
	}

	public func repeating(_ range: ClosedRange<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return Self.concatenate(Array(repeating: self, count: range.lowerBound) + Array(repeating: self.optional(), count: Int(range.upperBound-range.lowerBound)));
	}

	public func repeating(_ range: PartialRangeFrom<Int>) -> Self {
		precondition(range.lowerBound >= 0)
		return Self.concatenate(Array(repeating: self, count: range.lowerBound) + [self.star()])
	}

	public func homomorphism<Target: AlphabetProtocol>(mapping: [(some Collection<SymbolClass>, some Collection<Target.SymbolClass>)]) -> SymbolClassNFA<Target> where Target: Hashable {
		var newStates: [Target.NFATable] = self.statesSet.map { _ in [:] }
		var newEpsilon: [States] = self.statesSet.map { _ in [] }

		func addTransition( _ states: inout [Target.NFATable], _ from: Int, _ element: Target.SymbolClass, _ to: Int) {
			if from >= states.count {
				states.insert([:], at: from);
			}
			if states[from][element] == nil {
				states[from][element] = [];
			}
			states[from][element]!.insert(to)
		}

		for source in 0..<self.statesSet.count {
			for (sourceSymbols, targetSymbols) in mapping {
				var targetStates = Set([source])
				let sourceSymbolsArray = Array(sourceSymbols)
				let targetSymbolsArray = Array(targetSymbols)

				for sourceSymbol in sourceSymbolsArray {
					targetStates = self.nextStates(states: targetStates, range: sourceSymbol)
				}

				for target in targetStates {
					if targetSymbolsArray.isEmpty {
						// Add an epsilon-transition between source and target
						newEpsilon[source].insert(target);
					} else {
						var intermediate = source
						for i in 0..<targetSymbolsArray.count - 1 {
							let current = newStates.count
							newStates.append([:])
							newEpsilon.append([])
							addTransition(&newStates, intermediate, targetSymbolsArray[i], current)
							intermediate = current
						}
						addTransition(&newStates, intermediate, targetSymbolsArray.last!, target)
					}
				}
			}
		}

		return SymbolClassNFA<Target>(
			states: newStates,
			epsilon: newEpsilon,
			initials: self.initials,
			finals: self.finals
		)
	}

	/// Convert one NFA to another by translating a FSM to an FSM
//	public func homomorphism<Target: AlphabetProtocol>(mapping: [(DFA<SymbolClass>, DFA<Target.SymbolClass>)]) -> SymbolClassNFA<Target.SymbolClass> {
//		return SymbolClassNFA<Target>();
//	}

//	public func toPattern<PatternType: RegularPatternBuilder>(as: PatternType.Type? = nil) -> PatternType where PatternType.SymbolClass == SymbolClass {
//		// Can this be optimized?
//		DFA<Symbol>(nfa: self).toPattern(as: PatternType.self)
//	}

	public mutating func insert(_ newMember: __owned Element) -> (inserted: Bool, memberAfterInsert: Element) {
		if(contains(newMember)) {
			return (false, newMember)
		}
		self = self.union(Self.init(verbatim: newMember));
		return (true, newMember)
	}

	public mutating func remove(_ member: Element) -> (Element)? {
		self.formSymmetricDifference(Self.init(verbatim: member));
		return member;
	}

	public mutating func update(with newMember: __owned Element) -> (Element)? {
		return insert(newMember).1
	}
}

// Conditional protocol compliance
extension SymbolClassNFA: Sendable where SymbolClass: Sendable {}

extension SymbolClassNFA where Symbol == Character {
//	typealias Element = String
	init (_ val: Array<String>) {
		self.init(val.map{ Array($0) })
	}
}

public typealias NFA<Symbol: Hashable> = SymbolClassNFA<SymbolAlphabet<Symbol>>

