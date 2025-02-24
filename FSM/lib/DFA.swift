
/// An optimized form of NFA where each state has exactly one "next" state.
/// States are represented by an Int, or nil, the oblivion state.
infix operator ++: AdditionPrecedence;

struct DFA<Element: Hashable & Sequence & EmptyInitial & Comparable>: SetAlgebra, Sequence, NFAProtocol where Element.Element: Hashable & Comparable {
	typealias Symbol = Element.Element where Element.Element: Hashable;
	typealias StateNo = Int;
	typealias States = StateNo?;

	let states: Array<Dictionary<Symbol, StateNo>>;
	let initial: StateNo;
	let finals: Set<StateNo>;

	struct ID {
		let fsm: DFA<Element>
		let state: StateNo

		subscript(symbol: Symbol) -> Self? {
			let state = self.fsm.states[self.state][symbol];
			if let state {
				return Self.init(fsm: self.fsm, state: state)
			}else{
				return nil;
			}
		}
	}

	init() {
		self.states = [ [:] ];
		self.initial = 0;
		self.finals = [];
	}

	init(
		states: Array<Dictionary<Symbol, StateNo>> = [],
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

	init(verbatim: Element){
		let states = verbatim.enumerated().map { [ $1: $0 + 1 ] } + [[:]]
		self.init(
			states: states,
			initial: 0,
			finals: [ states.count-1 ]
		)
	}

	init(range: Range<Symbol>) where Symbol: Strideable, Symbol.Stride: SignedInteger {
		// Map each element in verbatim to a key in a new dictionary with value 1
		let table: Dictionary<Symbol, StateNo> = range.reduce(into: [:]) { result, key in
			result[key] = 1
		}
		let states = range.enumerated().map { [ $1: $0 + 1 ] } + [[:]]
		self.init(
			states: [ table, [:] ],
			initial: 0,
			finals: [ 1 ]
		)
	}

	init(range: ClosedRange<Symbol>) where Symbol: Strideable, Symbol.Stride: SignedInteger {
		// Map each element in verbatim to a key in a new dictionary with value 1
		var table: Dictionary<Symbol, StateNo> = [:];
		for char in range {
			table[char] = 1;
		}
		let states = range.enumerated().map { [ $1: $0 + 1 ] } + [[:]]
		self.init(
			states: [ table, [:] ],
			initial: 0,
			finals: [ 1 ]
		)
	}

	init(nfa: NFA<Element>){
		let translation = NFA<Element>.parallel(fsms: [nfa], merge: { $0[0] });
		// Sanity check
		translation.states.forEach { $0.forEach { assert($0.value.count == 1); } }
		self.states = translation.states.map { $0.mapValues { $0.first! } }
		self.initial = translation.initials.first!;
		self.finals = translation.finals;
	}

	static func == (lhs: Self, rhs: Self) -> Bool {
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

    var alphabet: Set<Symbol> {
        Set(self.states.flatMap(\.keys))
    }

	func toViz() -> String {
		var viz = "";
		viz += "digraph G {\n";
		viz += "\t_initial [shape=point];\n";
		viz += "\t_initial -> \(initial);\n";
		for (i, transitions) in states.enumerated() {
			let shape = finals.contains(i) ? "doublecircle" : "circle";
			viz += "\t\(i) [label=\"\(i)\", shape=\"\(shape)\"];\n";
			for (symbol, target) in transitions {
				viz += "\t\(i) -> \(target) [label=\"\(symbol)\"];\n";
			}
		}
		viz += "}\n";
		return viz;
	}

	func nextState(state: StateNo, symbol: Symbol) -> States {
		return self.states[state][symbol];
	}

	func nextState(state: StateNo, input: Element) -> States {
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

	/// Tries to match as many characters from input as possible, returning the last final state
	func match<T>(_ input: T) -> (T.SubSequence, T.SubSequence)? where T: Collection<Element.Element> {
		var currentState = self.initial;
		var finalIndex: T.Index? = nil;

		// Test the initial condition
		if(self.finals.contains(currentState)){
			finalIndex = input.startIndex;
		}

		// If we reach the end or nil, then there can be no more final states.
		for currentIndex in input.indices {
			let symbol = input[currentIndex];
			if let nextState = self.states[currentState][symbol] {
				currentState = nextState;
			} else {
				break;
			}
			assert(currentState < self.states.count);
			if(self.finals.contains(currentState)){
				finalIndex = input.index(after: currentIndex)
			}
		}

		guard let finalIndex else { return nil; }
		precondition(finalIndex >= input.startIndex, "Index is too low");
		precondition(finalIndex <= input.endIndex, "Index is too high");

		return (input[input.startIndex..<finalIndex], input[finalIndex...])
	}

	/// Derive a new FSM by crawling all the different possible combinations of states that can be reached from every possible input.
	/// - Parameter dfas: The DFAs to merge together.
	///
	/// - Parameter merge: Given an array of the states for the respective FSMs, return if this is a final state.
	/// 	To find a union, return true if any is true. To find the intersection, return true only when all are true.
	///
	static func parallel(fsms: [Self], merge: ([Bool]) -> Bool) -> Self {
		var newStates = Array<Dictionary<Symbol, StateNo>>();
		var newFinals = Set<StateNo>();
		var forward = Dictionary<Array<States>, StateNo>();
		var backward = Array<Array<States>>();

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
			var newStateTransitions = Dictionary<Symbol, StateNo>();
			let inStates = backward[newStateId];
			var alphabets = Set<Symbol>();
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

	func contains(_ input: Element) -> Bool {
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

    // SetAlgebra implementation
	func union(_ other: __owned DFA<Element>) -> DFA<Element> {
		return Self.parallel(fsms: [self, other], merge: { $0[0] || $0[1] });
	}

	func intersection(_ other: DFA<Element>) -> DFA<Element> {
		return Self.parallel(fsms: [self, other], merge: { $0[0] && $0[1] });
	}

	func symmetricDifference(_ other: __owned DFA<Element>) -> DFA<Element> {
		return Self.parallel(fsms: [self, other], merge: { $0[0] != $0[1] });
	}

	// Also provide a static implementation of union since it applies to any number of inputs
	static func union(_ languages: Array<DFA<Element>>) -> DFA<Element> {
		if(languages.count == 0){
			return DFA<Element>();
		} else if(languages.count == 1) {
			return languages[0];
		}
		return Self.parallel(fsms: languages, merge: { $0.contains(where: { $0 }) });
	}

	/// Finds the language of all the the ways to join a string from the first language with strings in the second language
	static func concatenate(_ languages: Array<DFA<Element>>) -> DFA<Element> {
		if(languages.count == 0){
			return DFA<Element>();
		} else if(languages.count == 1) {
			return languages[0];
		}
		let nfa = NFA<Element>.concatenate(languages.map { NFA<Element>(dfa: $0) });
		return DFA(nfa: nfa);
	}

	func concatenate(_ other: DFA<Element>) -> DFA<Element> {
		return Self.concatenate([self, other]);
	}

	/// Adds the empty string to the set of accepted elements
	func optional() -> DFA<Element> {
		return Self(
			states: self.states,
			initial: self.initial,
			finals: self.finals.union([self.initial])
		);
	}

	func plus() -> DFA<Element> {
		let nfa = NFA<Element>(
			states: self.states.map { $0.mapValues { Set([$0]) } },
			// Add an epsilon transition from the final states to the initial state
			epsilon: self.states.enumerated().map { stateNo, _ in self.finals.contains(stateNo) ? [self.initial] : [] },
			initial: self.initial,
			finals: self.finals
		);
		return DFA(nfa: nfa);
	}

	func star() -> DFA<Element> {
		return self.plus().optional();
		// Should be equal to:
		//let nfa = NFA<Element>(
		//	states: self.states.map { $0.mapValues { Set([$0]) } },
		//	// Add an epsilon transition from the final states to the initial state
		//	epsilon: self.states.enumerated().map { stateNo, _ in self.finals.contains(stateNo) ? [self.initial] : [] },
		//	initial: self.initial,
		//	finals: self.finals.union([self.initial])
		//);
		//return DFA(nfa: nfa);
	}

	/// Now we're getting into alchemy land
	/// This function takes a state and follows all the states from `state` according to the input FSM and returns the ones that are marked final according to that input FSM
//	func nextStates(state: StateNo, input: DFA<Element>) -> Set<StateNo> {
//		var currentState: Set = [state];
//		var finalStates: Set<StateNo> = [];
//
//		let enumerated = input.states.map { $0.map { (symbol: $0.key, toState: $0.value) }.sorted { $0.0 < $1.0 } };
//
//
//		// Basis
//		if(input.finals.contains(input.initial)){
//			finalStates.insert(input.initial);
//		}
//		let stack: Array<(Int, Int)> = [];
//
//		repeat {
//			let previous = stack.last;
//			if let previous {
//				let currentState = states[previous.state][previous.index].toState;
//				if states[currentState].count > 0 {
//					// Follow the first state from the current state, if there is one
//					stack.append((currentState, 0));
//				} else {
//					// Prepare to increment the index by one, carrying down if necessary
//					// Remove final elements that are on the last index
//					while(stack.last!.index >= states[stack.last!.state].count - 1){
//						stack.removeLast();
//						if(stack.count == 0){
//							return nil;
//						}
//					}
//					stack[stack.count-1].index += 1;
//				}
//			}else{
//				if states[fsm.initial].count > 0 {
//					// Follow the first state from the current state, if there is one
//					stack.append((fsm.initial, 0));
//				}else{
//					return finalStates;
//				}
//			}
//		} while true;
//	}

	func state(_ state: StateNo) -> Self.ID {
		return Self.ID(fsm: self, state: state)
	}

//	func derive(_ input: Element) -> Self
//	{
////		let nextStates = self.next(initial: self.initial, )
////		return Self.init(states: self.states, initial: currentState, finals: self.finals);
//	}

	func makeIterator() -> Iterator {
		return Iterator(self);
	}

	// TODO: Implement sort order
	// TODO: Implement state/stack filtering

	/// An iterator that can iterate over all of the elements of the FSM.
	/// Indefinitely, if need be.
	struct StateIterator: IteratorProtocol {
		let fsm: DFA<Element>;
		let states: Array<Array<(symbol: Element.Element, toState: StateNo)>>

		var stack: Array<(state: StateNo, index: Int)>;
		var visited: Set<StateNo>?;
		var started = false;

		init(_ fsm: DFA<Element>) {
			//			let fsm = options.fsm;
			self.fsm = fsm;

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

		// This needs a `filter` function to determine if we descend into the current state or not.
		// A `false` might be used to prevent loops, or to zskip over entire trees of uninteresting values.
		mutating func next() -> Array<(state: Int, index: Int)>? {
			if started == false {
				started = true;
				return [];
			}
			let previous = stack.last;
			guard let previous else {
				// There's nothing on the stack, so we're currently on the initial state,
				// and need to begin iterating over its transitions.
				if states[fsm.initial].count > 0 {
					// Follow the first state from the current state, if there is one
					stack.append((fsm.initial, 0));
					return stack;
				}else{
					// The unlikely case where the initial state is the only state
					return nil;
				}
			}
			let currentState = states[previous.state][previous.index].toState;
			if states[currentState].count > 0 {
				// Follow the first state from the current state, if there is one
				stack.append((currentState, 0));
			} else {
				repeat {
					// Prepare to increment the index by one, carrying down if necessary
					// Remove final elements that are on the last index
					while(stack.last!.index >= states[stack.last!.state].count - 1){
						stack.removeLast();
						if(stack.count == 0){
							return nil;
						}
					}
					stack[stack.count-1].index += 1;
					// TODO: test if this state should be skipped, repeat this loop if so
				} while(stack.count > 0 && false);
			}
			return stack;
		}
	}

	struct Iterator: IteratorProtocol {
		let fsm: DFA<Element>;
		var iterator: StateIterator;

		init(_ fsm: DFA<Element>) {
			// let fsm = options.fsm;
			self.fsm = fsm;
			self.iterator = StateIterator(fsm);
		}

		mutating func next() -> Element? {
			repeat {
				// TODO: if repeats == .Skip then keep iterating this until we have a value that's not used by an ancestor
				if let stack = iterator.next() {
					let state = stack.isEmpty ? fsm.initial : iterator.states[stack.last!.state][stack.last!.index].toState;
					if fsm.finals.contains(state) {
						return stack.reduce(Element.empty, { $0.appendElement(iterator.states[$1.state][$1.index].symbol) });
					}
				} else {
					return nil;
				}
			} while true;
		}
	}

	func homomorphism<Target>(mapping: [(Element, Target)]) -> DFA<Target> where Target: Hashable & Sequence, Target.Element: Hashable {
		let nfa: NFA<Target> = NFA<Element>(dfa: self).homomorphism(mapping: mapping);
		return DFA<Target>(nfa: nfa)
	}

//	func homomorphism<Target>(mapping: [(DFA<Element>, DFA<Target>)]) -> DFA<Target> where Target: Hashable & Sequence, Target.Element: Hashable {
//		let nfa: NFA<Target> = NFA<Element>(dfa: self).homomorphism(mapping: mapping);
//		return DFA<Target>(nfa: nfa)
//	}

	mutating func insert(_ newMember: __owned Element) -> (inserted: Bool, memberAfterInsert: Element) {
		if(contains(newMember)) {
			return (false, newMember)
		}
		self = self.union(DFA(verbatim: newMember));
		return (true, newMember)
	}

	mutating func remove(_ member: Element) -> (Element)? {
		self.formSymmetricDifference(DFA(verbatim: member));
		return member;
	}

	mutating func update(with newMember: __owned Element) -> (Element)? {
		return insert(newMember).1
	}

	mutating func formUnion(_ other: __owned DFA<Element>) {
		self = self.union(other);
	}

	mutating func formIntersection(_ other: DFA<Element>) {
		self = self.intersection(other);
	}

	mutating func formSymmetricDifference(_ other: __owned DFA<Element>) {
		self = self.symmetricDifference(other);
	}

	// Operator shortcuts
	// Concatenation
	static func ++ (lhs: Self, rhs: Self) -> Self {
		return DFA<Element>.concatenate([lhs, rhs]);
	}
	// Union/alternation
	static func | (lhs: Self, rhs: Self) -> Self {
		return DFA<Element>.parallel(fsms: [lhs, rhs], merge: { $0[0] || $0[1] });
	}
	// Subtract
	static func - (lhs: Self, rhs: Self) -> Self {
		return DFA<Element>.parallel(fsms: [lhs, rhs], merge: { $0[0] && !$0[1] });
	}
}

// Conditional protocol compliance
extension DFA: Sendable where Symbol: Sendable {}
