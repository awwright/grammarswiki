
/// An optimized form of NFA where each state has exactly one "next" state.
/// States are represented by an Int, or nil, the oblivion state.
/// A DFA is essentially a special case of an NFA where a state can transition into at most one state, instead of any number of states.
public struct DFA<Element: Hashable & Sequence & EmptyInitial & Comparable>: SetAlgebra, Sequence, NFAProtocol where Element.Element: Hashable & Comparable {
	public typealias Symbol = Element.Element where Element.Element: Hashable;
	public typealias StateNo = Int;
	public typealias States = StateNo?;

	public let states: Array<Dictionary<Symbol, StateNo>>;
	public let initial: StateNo;
	public let finals: Set<StateNo>;

	public init() {
		self.states = [ [:] ];
		self.initial = 0;
		self.finals = [];
	}

	public init(
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

	public init(verbatim: Element){
		let states = verbatim.enumerated().map { [ $1: $0 + 1 ] } + [[:]]
		self.init(
			states: states,
			initial: 0,
			finals: [ states.count-1 ]
		)
	}

	public init(range: Range<Symbol>) where Symbol: Strideable, Symbol.Stride: SignedInteger {
		// Map each element in verbatim to a key in a new dictionary with value 1
		let table: Dictionary<Symbol, StateNo> = range.reduce(into: [:]) { result, key in
			result[key] = 1
		}
		self.init(
			states: [ table, [:] ],
			initial: 0,
			finals: [ 1 ]
		)
	}

	public init(range: ClosedRange<Symbol>) where Symbol: Strideable, Symbol.Stride: SignedInteger {
		// Map each element in verbatim to a key in a new dictionary with value 1
		var table: Dictionary<Symbol, StateNo> = [:];
		for char in range {
			table[char] = 1;
		}
		self.init(
			states: [ table, [:] ],
			initial: 0,
			finals: [ 1 ]
		)
	}

	public init(nfa: NFA<Element>){
		let translation = NFA<Element>.parallel(fsms: [nfa], merge: { $0[0] });
		// Sanity check
		translation.states.forEach { $0.forEach { assert($0.value.count == 1); } }
		self.states = translation.states.map { $0.mapValues { $0.first! } }
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

	public var alphabet: Set<Symbol> {
        Set(self.states.flatMap(\.keys))
    }

	public func toViz() -> String {
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

	public func nextState(state: StateNo, symbol: Symbol) -> States {
		assert(state >= 0)
		assert(state < self.states.count)
		return self.states[state][symbol];
	}

	public func nextState(state: StateNo, input: Element) -> States {
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

	/// Tries to match as many characters from input as possible, returning the last final state
	public func match<T>(_ input: T) -> (T.SubSequence, T.SubSequence)? where T: Collection<Element.Element> {
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
		assert(finalIndex >= input.startIndex, "Index is too low");
		assert(finalIndex <= input.endIndex, "Index is too high");

		return (input[input.startIndex..<finalIndex], input[finalIndex...])
	}

	/// Instant Description (ID), describes a FSM and its specific state during execution
	public struct ID {
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

	/// Get the ID of the state machine without any input
	var initialDescription: ID {
		return ID(fsm: self, state: initial);
	}

	/// Get the ID of the state machine at a specific state
	subscript(state: StateNo) -> Self.ID {
		return Self.ID(fsm: self, state: state)
	}

	/// Derive a new FSM by crawling all the different possible combinations of states that can be reached from every possible input.
	/// - Parameter dfas: The DFAs to merge together.
	///
	/// - Parameter merge: Given an array of the states for the respective FSMs, return if this is a final state.
	/// 	To find a union, return true if any is true. To find the intersection, return true only when all are true.
	///
	public static func parallel(fsms: [Self], merge: ([Bool]) -> Bool) -> Self {
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

	/// Return an equivalent DFA, remapping the symbols at each transition
	public func mapTransitions<Target>(_ transform: (Element.Element) -> Target.Element) -> DFA<Target> {
		let newStates = states.map {
			// Map the key of the dictionary using `transform`
			Dictionary(uniqueKeysWithValues: $0.map { (key, value) in
				(transform(key), value)
			})
		}
		return DFA<Target>(
			states: newStates,
			initial: self.initial,
			finals: self.finals
		)
	}

	public func contains(_ input: Element) -> Bool {
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
	public func union(_ other: __owned DFA<Element>) -> DFA<Element> {
		return Self.parallel(fsms: [self, other], merge: { $0[0] || $0[1] });
	}

	public func intersection(_ other: DFA<Element>) -> DFA<Element> {
		return Self.parallel(fsms: [self, other], merge: { $0[0] && $0[1] });
	}

	public func symmetricDifference(_ other: __owned DFA<Element>) -> DFA<Element> {
		return Self.parallel(fsms: [self, other], merge: { $0[0] != $0[1] });
	}

	// Also provide a static implementation of union since it applies to any number of inputs
	public static func union(_ languages: Array<DFA<Element>>) -> DFA<Element> {
		if(languages.count == 0){
			return DFA<Element>();
		} else if(languages.count == 1) {
			return languages[0];
		}
		return Self.parallel(fsms: languages, merge: { $0.contains(where: { $0 }) });
	}

	/// Finds the language of all the the ways to join a string from the first language with strings in the second language
	public static func concatenate(_ languages: Array<DFA<Element>>) -> DFA<Element> {
		if(languages.count == 0){
			return DFA<Element>();
		} else if(languages.count == 1) {
			return languages[0];
		}
		let nfa = NFA<Element>.concatenate(languages.map { NFA<Element>(dfa: $0) });
		return DFA(nfa: nfa);
	}

	public func concatenate(_ other: DFA<Element>) -> DFA<Element> {
		return Self.concatenate([self, other]);
	}

	/// Adds the empty string to the set of accepted elements
	public func optional() -> DFA<Element> {
		return Self(
			states: self.states,
			initial: self.initial,
			finals: self.finals.union([self.initial])
		);
	}

	public func plus() -> DFA<Element> {
		let nfa = NFA<Element>(
			states: self.states.map { $0.mapValues { Set([$0]) } },
			// Add an epsilon transition from the final states to the initial state
			epsilon: self.states.enumerated().map { stateNo, _ in self.finals.contains(stateNo) ? [self.initial] : [] },
			initial: self.initial,
			finals: self.finals
		);
		return DFA(nfa: nfa);
	}

	public func star() -> DFA<Element> {
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

	public func repeating(_ count: Int) -> DFA<Element> {
		precondition(count >= 0)
		return DFA.concatenate(Array(repeating: self, count: count))
	}

	public func repeating(_ range: ClosedRange<Int>) -> DFA<Element> {
		precondition(range.lowerBound >= 0)
		return DFA.concatenate(Array(repeating: self, count: range.lowerBound) + Array(repeating: self.optional(), count: Int(range.upperBound-range.lowerBound)));
	}

	public func repeating(_ range: PartialRangeFrom<Int>) -> DFA<Element> {
		precondition(range.lowerBound >= 0)
		return DFA.concatenate(Array(repeating: self, count: range.lowerBound) + [self.star()])
	}

//	func derive(_ input: Element) -> Self
//	{
////		let nextStates = self.next(initial: self.initial, )
////		return Self.init(states: self.states, initial: currentState, finals: self.finals);
//	}

	public func makeIterator() -> Iterator {
		return Iterator(self);
	}

	// TODO: Implement sort order
	/// A simple way to create a view on a struct to change how it is iterated or enumerated
	public struct IteratorFactory<T>: Sequence where T: IteratorProtocol {
		let dfa: DFA<Element>;
		let constructor: (DFA<Element>) -> T;
		init(_ dfa: DFA<Element>, constructor: @escaping (DFA<Element>) -> T) {
			self.dfa = dfa;
			self.constructor = constructor;
		}
		public func makeIterator() -> T {
			return constructor(dfa)
		}
	}

	// A sequence that walks over all of the different paths
	public var paths: IteratorFactory<PathIterator> {
		return IteratorFactory(self) {
			PathIterator($0)
		}
	};

	/// Returns an iterator that walks over all of the possible of the paths in the state graph.
	/// - Parameter filter: A function that decides if the paths in the given state should be walked. This is for filtering out paths that have already been visited or otherwise don't mean anything.
	public func pathIterator(filter: @escaping (PathIterator, PathIterator.Path) -> Bool) -> IteratorFactory<PathIterator> {
		return IteratorFactory(self) {
			PathIterator($0, filter: filter);
		};
	}

	/// An iterator that can iterate over all of the elements of the FSM.
	/// Indefinitely, if need be.
	public struct PathIterator: IteratorProtocol {
		public struct Segment: Equatable {
			var source: StateNo
			var index: Int
			var symbol: Element.Element
			var target: StateNo
		};
		public typealias Path = Array<Segment>;
		let fsm: DFA<Element>;
		let states: Array<Array<(symbol: Element.Element, toState: StateNo)>>
		let filter: (Self, Path) -> Bool;

		var stack: Path;
		var visited: Set<StateNo>?;
		var started = false;

		init(_ fsm: DFA<Element>, filter: @escaping (Self, Path) -> Bool) {
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

		init(_ fsm: DFA<Element>) {
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

	public struct Iterator: IteratorProtocol {
		let fsm: DFA<Element>;
		var iterator: PathIterator;

		init(_ fsm: DFA<Element>) {
			// let fsm = options.fsm;
			self.fsm = fsm;
			self.iterator = PathIterator(fsm);
		}

		public mutating func next() -> Element? {
			repeat {
				// TODO: if repeats == .Skip then keep iterating this until we have a value that's not used by an ancestor
				if let stack = iterator.next() {
					let state = stack.isEmpty ? fsm.initial : stack.last!.target;
					if fsm.finals.contains(state) {
						return stack.reduce(Element.empty, { $0.appending(iterator.states[$1.source][$1.index].symbol) });
					}
				} else {
					return nil;
				}
			} while true;
		}
	}

	// Now we're really getting into alchemy land
	/// This follows all the paths walked by a set of strings provided as another DFA
	/// It takes a state and follows all the states from `state` according to the input FSM and returns the ones that are marked final according to that input FSM
	public func nextStates(initial: StateNo, input: DFA<Element>) -> Set<StateNo> {
		var finalStates: Set<StateNo> = [];
		//var derivative = DFA<Element>(
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
			print(path);
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

	public func homomorphism<Target>(mapping: [(Element, Target)]) -> DFA<Target> where Target: Hashable & Sequence, Target.Element: Hashable {
		let nfa: NFA<Target> = NFA<Element>(dfa: self).homomorphism(mapping: mapping);
		return DFA<Target>(nfa: nfa)
	}

	public func homomorphism<Target>(mapping: [(DFA<Element>, DFA<Target>)]) -> DFA<Target> where Target: Hashable & Sequence, Target.Element: Hashable {
		let nfa: NFA<Target> = NFA<Element>(dfa: self).homomorphism(mapping: mapping);
		return DFA<Target>(nfa: nfa)
	}

	public mutating func insert(_ newMember: __owned Element) -> (inserted: Bool, memberAfterInsert: Element) {
		if(contains(newMember)) {
			return (false, newMember)
		}
		self = self.union(DFA(verbatim: newMember));
		return (true, newMember)
	}

	public mutating func remove(_ member: Element) -> (Element)? {
		self.formSymmetricDifference(DFA(verbatim: member));
		return member;
	}

	public mutating func update(with newMember: __owned Element) -> (Element)? {
		return insert(newMember).1
	}

	public mutating func formUnion(_ other: __owned DFA<Element>) {
		self = self.union(other);
	}

	public mutating func formIntersection(_ other: DFA<Element>) {
		self = self.intersection(other);
	}

	public mutating func formSymmetricDifference(_ other: __owned DFA<Element>) {
		self = self.symmetricDifference(other);
	}

	// Operator shortcuts
	/// Concatenation operator
	// The selection of symbol for operator is fraught because most of these symbols have been used for most different things
	// String concatenation is slightly different than language concatenation,
	// I want to suggest the string concatenation of the cross product of any string from ordered pair languages
	public static func ++ (lhs: Self, rhs: Self) -> Self {
		return DFA<Element>.concatenate([lhs, rhs]);
	}
	/// Union/alternation
	// This is another case where the operator is confusing.
	// SQL uses || for string concatenation, but in C it would suggest union.
	// You could also use + to suggest union, but many languages including Swift use it for string concatenation.
	public static func | (lhs: Self, rhs: Self) -> Self {
		return DFA<Element>.parallel(fsms: [lhs, rhs], merge: { $0[0] || $0[1] });
	}
	/// Subtract/difference
	/// Returns a version of `lhs` but removing any elements in `rhs`
	// I think (-) is pretty unambiguous here, but some math notation uses \ for this operation.
	public static func - (lhs: Self, rhs: Self) -> Self {
		return DFA<Element>.parallel(fsms: [lhs, rhs], merge: { $0[0] && !$0[1] });
	}
}

infix operator ++: AdditionPrecedence;

// Conditional protocol compliance
extension DFA: Sendable where Symbol: Sendable {}
extension DFA: Hashable where Element: Hashable {}
