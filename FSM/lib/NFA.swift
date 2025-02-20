
// TODO: LosslessStringConvertible

protocol NFAProtocol {
	associatedtype Element;
	associatedtype Symbol;
	associatedtype StateNo;
	associatedtype States;

//	var alphabet: Set<Symbol> { get };

	init();
	init(verbatim: Element);
}

struct NFA<Element: Hashable & Sequence & EmptyInitial & Comparable>: SetAlgebra, NFAProtocol where Element.Element: Hashable & Comparable {
	typealias Symbol = Element.Element where Element.Element: Hashable;
	typealias StateNo = Int;
	typealias States = Set<StateNo>;

	let states: Array<Dictionary<Symbol, Set<Int>>>;
	let epsilon: Array<Set<Int>>;
	// I allow initials to be a set of states so that the result of following from the initial state can be a closed operation
	let initials: Set<Int>;
	let finals: Set<Int>;

	struct ID {
		let fsm: NFA<Element>
		let states: States

		subscript(symbol: Symbol) -> ID {
			let nextStates = self.fsm.nextStates(states: self.states, symbol: symbol)
			return ID(fsm: self.fsm, states: nextStates)
		}
	}

	init(
		states: Array<Dictionary<Symbol, States>> = [ [:] ],
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

		// Include all the epsilon transitions on the initial set
		var expanded = initials;
		var expandedList = Array(initials);
		// Iterate over every state in states
		for state in expandedList {
			for next in epsilon[state] {
				if(!expanded.contains(next)){
					expanded.insert(next);
					expandedList.append(next);
				}
			}
		}

		self.states = states;
		self.epsilon = epsilon;
		self.initials = expanded;
		self.finals = finals;
	}

	// Empty set constructor, with one initial state and no final states
	init() {
		self.init(states: [[:]], epsilon: [[]], initials: [0], finals: []);
	}

	// Variation with single initial state
	init(
		states: Array<Dictionary<Symbol, States>> = [],
		epsilon: Array<States> = [],
		initial: StateNo = 0,
		finals: Set<StateNo> = []
	) {
		self.init(states: states, epsilon: epsilon, initials: [initial], finals: finals)
	}

	init(verbatim: Element){
		// Generate one state per symbol in Element, plus a final state
		let states = verbatim.enumerated().map { [ $1: Set([$0 + 1]) ] } + [[:]]
		self.init(
			states: states,
			epsilon: Array(repeating: [], count: states.count),
			initials: [0],
			finals: [states.count-1]
		);
	}

	init(dfa: DFA<Element>) {
		self.init(
			states: dfa.states.map { $0.mapValues { [$0] } },
			epsilon: Array(repeating: [], count: dfa.states.count),
			initials: [dfa.initial],
			finals: dfa.finals
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


	func toViz() -> String {
		var viz = "";
		viz += "digraph G {\n";
		viz += "\t_initial [shape=point];\n";
		for i in initials {
			viz += "\t_initial -> \(i);\n";
		}
		for (i, transitions) in states.enumerated() {
			let shape = finals.contains(i) ? "doublecircle" : "circle";
			viz += "\t\(i) [label=\"\(i)\", shape=\"\(shape)\"];\n";
			for (symbol, states) in transitions {
//				viz += "\t\(symbol) \(states)\n";
				for target in states {
					viz += "\t\(i) -> \(target) [label=\"\(symbol)\"];\n";
				}
			}
		}
		viz += "}\n";
		return viz;
	}

	lazy var alphabet: Set<Symbol> = {
		Set(self.states.flatMap(\.keys))
	}()

	func nextStates(state: StateNo, symbol: Symbol) -> States {
		return self.nextStates(states: [state], symbol: symbol);
	}

	func nextStates(state: StateNo, string: Element) -> States {
		return self.nextStates(states: [state], string: string);
	}

	func nextStates(states: States, symbol: Symbol) -> States {
		// Map each element in `states` to the next symbol in states[state][symbol], if it exists
		return Set(states.flatMap { self.states[$0][symbol] ?? [] })
	}

	func nextStates(states: States, string: Element) -> States {
		var currentState = states;
		for symbol in string {
			currentState = self.nextStates(states: currentState, symbol: symbol)
		}
		return currentState;
	}

	/// Get a list of states after following epsilon transitions,
	/// i.e. get a list of all the states equivalent to any of the given
	func all(states: States) -> States{
		var expanded = states;
		var list = Array(states);
		// Iterate over every state in states
		for state in states {
			let transitions = self.epsilon[state];
			for next in transitions {
				if(!expanded.contains(next)){
					expanded.insert(next);
					list.append(next);
				}
			}
		}
		return expanded;
	}

	static func parallel(fsms: [Self], merge: ([Bool]) -> Bool) -> Self {
		var newStates = Array<Dictionary<Symbol, States>>();
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
		let initialStates = fsms.map { $0.initials }
		let newInitialState = forwardStateId(inStates: initialStates);
		assert(newInitialState == 0);
		assert(backward.count == 1);

		var newStateId = 0;
		while(newStateId < backward.count){
			var newStateTransitions = Dictionary<Symbol, States>();
			let inStates = backward[newStateId];
			var alphabets = Set<Symbol>();
			// enumerate over inStates and get the index
			for (fsm, states) in zip(fsms, inStates) {
				for state in states {
					alphabets.formUnion(fsm.states[state].keys);
				}
			}
			// For each of the symbols in the alphabet, get the next state following the current one
			for symbol in alphabets {
				let nextStates = zip(fsms, inStates).map { (fsm, state) in fsm.nextStates(states: state, symbol: symbol) }
				newStateTransitions[symbol] = [forwardStateId(inStates: nextStates)]
			}

			newStates.insert(newStateTransitions, at: newStateId);
			if(merge(zip(fsms, inStates).map { (fsm, state) in fsm.finals.intersection(state).count > 0 })) {
				newFinals.insert(newStateId)
			}

			newStateId += 1;
		}

		return Self.init(states: newStates, epsilon: Array(repeating: [], count: newStates.count), initial: newInitialState, finals: newFinals);
	}

	func contains(_ input: Element) -> Bool {
		let final = self.nextStates(states: self.initials, string: input)
		return (final.intersection(self.finals).count) > 0
	}

	func derive(_ input: Element) -> Self
	{
		var currentState = self.initials;

		for symbol in input {
			let nextState = self.nextStates(states: currentState, symbol: symbol)
			if(nextState.count == 0){
				return NFA(states: [[:]], initial: 0, finals: []);
			}
			currentState = nextState
		}

		return Self.init(states: self.states, epsilon: self.epsilon, initials: currentState, finals: self.finals);
	}

	func union(_ other: __owned Self) -> Self {
//		return Self.parallel(dfas: [self, other], merge: { $0[0] || $0[1] });
		let offset = self.states.count;
		let newStates = other.states.map { $0.mapValues { Set($0.map { $0  + offset }) } }
		let newEpsilon = other.epsilon.map { Set($0.map { $0  + offset }) }
		let newInitials = other.initials.map { $0  + offset }
		let newFinals = other.finals.map { $0  + offset }
		return Self(
			states: self.states + newStates,
			epsilon: self.epsilon + newEpsilon,
			initials: self.initials.union(newInitials),
			finals: self.finals.union(newFinals)
		)
	}

	func intersection(_ other: Self) -> Self {
		return Self.parallel(fsms: [self, other], merge: { $0[0] && $0[1] });
	}

	func symmetricDifference(_ other: __owned Self) -> Self {
		return Self.parallel(fsms: [self, other], merge: { $0[0] != $0[1] });
	}

	func homomorphism<Target>(mapping: [(Element, Target)]) -> NFA<Target> where Target: Hashable & Sequence, Target.Element: Hashable {
		typealias TargetSymbol = Target.Element;
		var newStates: [[TargetSymbol: Set<Int>]] = self.states.map { _ in [:] }
		var newEpsilon: [States] = self.states.map { _ in [] }

		func addTransition( _ states: inout [[TargetSymbol: Set<Int>]], _ from: Int, _ element: TargetSymbol, _ to: Int) {
			if from >= states.count {
				states.insert([:], at: from);
			}
			if states[from][element] == nil {
				states[from][element] = [];
			}
			states[from][element]!.insert(to)
		}

		for source in 0..<self.states.count {
			for (sourceSymbols, targetSymbols) in mapping {
				var targetStates = Set([source])
				let sourceSymbolsArray = Array(sourceSymbols)
				let targetSymbolsArray = Array(targetSymbols)

				for sourceSymbol in sourceSymbolsArray {
					targetStates = self.nextStates(states: targetStates, symbol: sourceSymbol)
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

		return NFA<Target>(
			states: newStates,
			epsilon: newEpsilon,
			initials: self.initials,
			finals: self.finals
		)
	}

	/// Convert one NFA to another by translating a FSM to an FSM
//	func homomorphism<Target>(mapping: [(DFA<Element>, DFA<Target>)]) -> NFA<Target> where Target: Hashable & Sequence, Target.Element: Hashable {
//	}

	mutating func insert(_ newMember: __owned Element) -> (inserted: Bool, memberAfterInsert: Element) {
		if(contains(newMember)) {
			return (false, newMember)
		}
		self = self.union(Self.init(verbatim: newMember));
		return (true, newMember)
	}

	mutating func remove(_ member: Element) -> (Element)? {
		self.formSymmetricDifference(Self.init(verbatim: member));
		return member;
	}

	mutating func update(with newMember: __owned Element) -> (Element)? {
		return insert(newMember).1
	}

	mutating func formUnion(_ other: __owned Self) {
		self = self.union(other);
	}

	mutating func formIntersection(_ other: Self) {
		self = self.intersection(other);
	}

	mutating func formSymmetricDifference(_ other: __owned Self) {
		self = self.symmetricDifference(other);
	}

}
