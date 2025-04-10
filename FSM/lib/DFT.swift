// Deterministic Finite Transducer

/// A Deterministic Finite State Transducer (DFT) that recognizes a set of input sequences over a given input alphabet
/// and produces corresponding output sequences over an output alphabet.
/// This library mostly uses it to define partitioning schemes, so that inputs which map to the same output are part of the same partition.
/// Inputs that land on non-final states are not part of the set, and the output is not meaningful.
/// It extends a DFA by associating an output sequence with each transition.
/// Like a DFA, it represents a set of strings describable with a finite state machine, but it also transforms them.
///
/// It produces a limit of one output symbol per input symbol. This is sufficient to describe any possible partitioning scheme.
///
/// - Type Parameters:
///   - `InputSymbol`: The type of input symbols (e.g., `Character`), must conform to `Comparable` and `Hashable`.
///   - `OutputSymbol`: The type of output symbols (e.g., `String`), must conform to `Comparable` and `Hashable`.
public struct DFT<I: Comparable & Hashable, O: Comparable & Hashable>: Hashable {
	/// Default element type produced reading this as a Sequence
	public typealias Element = Array<I>
	/// Default type that inputs are mapped to (to label a partition)
	public typealias Output = Array<O>
	/// The type used to index states.
	public typealias StateNo = Int
	/// The type of a set of states, optional to include the oblivion state (`nil`).
	public typealias States = StateNo?

	public static var empty: Self {
		Self(states: [[:]], initial: 0, finals: [])
	}

	public static var epsilon: Self {
		Self(states: [[:]], initial: 0, finals: [0])
	}

	/// The transition table, mapping each state to a dictionary of input symbol to (next state, output sequence) pairs.
	public let states: Array<Dictionary<I, TO<StateNo, O>>>
	/// The initial state of the DFT.
	public let initial: StateNo
	/// The set of accepting (final) states.
	public let finals: Set<StateNo>

	/// Creates an empty DFT that accepts no sequences and produces no output.
	public init() {
		self.states = [[:]]
		self.initial = 0
		self.finals = []
	}

	/// Creates a DFT with specified states, initial state, and final states.
	///
	/// - Parameters:
	///   - states: The transition table; defaults to an empty state if not provided.
	///   - initial: The starting state; must be within `states` bounds.
	///   - finals: The set of accepting states; all must be within `states` bounds.
	public init(
		states: Array<Dictionary<I, TO<StateNo, O>>> = [[:]],
		initial: StateNo = 0,
		finals: Set<StateNo> = []
	) {
		for transitions in states {
			for (_, next) in transitions {
				assert(next.t >= 0)
				assert(next.t < states.count)
			}
		}
		assert(initial >= 0)
		assert(initial < states.count)
		for state in finals {
			assert(state >= 0)
			assert(state < states.count)
		}

		self.states = states
		self.initial = initial
		self.finals = finals
	}

//	static top(
//		states: Array<Dictionary<I, (StateNo, O)>> = [[:]],
//		initial: StateNo = 0,
//		finals: Set<StateNo> = []
//	) {
//		self.init(states: states.map { $0.mapValues { TO(t: $0.0, o: $0.1) } }, initial: initial, finals: finals)
//	}

	/// Generate a DFT equivalence with a single partition
	/// i.e. all values are equivalent
	init(top: DFA<I>) {
		self.states = top.states.map { $0.mapValues { TO<StateNo, O>(t: $0, o: nil) } }
		self.initial = top.initial
		self.finals = top.finals
	}

	/// Creates a DFST that accepts exactly the given input sequence and produces a specified output sequence.
//	public init(verbatim input: some Collection<I>, output: some Collection<O>) {
//		let inputArray = Array(input)
//		let outputArray = Array(output)
//		assert(inputArray.count == outputArray.count, "Input and output sequences must have the same length")
//		let states = inputArray.enumerated().map { [inputArray[$0.offset]: (next: $0.offset + 1, output: [outputArray[$0.offset]])] } + [[:]]
//		self.init(
//			states: states,
//			initial: 0,
//			finals: [states.count - 1]
//		)
//	}

	/// Creates a DFT from a DFA, producing an empty output for each transition.
	public init(dfa: DFA<I>) {
		self.states = dfa.states.map { $0.mapValues { TO(t: $0, o: nil) } }
		self.initial = dfa.initial
		self.finals = dfa.finals
	}

	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.states == rhs.states &&
		lhs.initial == rhs.initial &&
		lhs.finals == rhs.finals
	}

	public var alphabet: Set<I> {
		Set(states.flatMap(\.keys))
	}

//	public var outputAlphabet: Set<O> {
//		Set(states.flatMap { $0.values.flatMap { $0.output } })
//	}

	/// Transitions from a state on a given input symbol, returning the next state and output.
	public func nextState(state: StateNo, symbol: I) -> StateNo? {
		assert(state >= 0)
		assert(state < self.states.count)
		if let transition = self.states[state][symbol] {
			return transition.t
		}
		return nil
	}

	/// Checks if a state is accepting.
	public func isFinal(_ state: States) -> Bool {
		guard let state else { return false }
		return self.finals.contains(state)
	}

	/// Determines if two inputs are equivalent according to the DFT (maps to the same output)
	/// This will decide even on inputs that are not accepting because this will come to a decision
	/// before it ever reaches the end of the input.
	public func isEquivalent(_ lhs: some Sequence<I>, _ rhs: some Sequence<I>) -> Bool {
		var lhsState: States = self.initial
		var rhsState: States = self.initial
		var lhsIt = lhs.makeIterator()
		var rhsIt = rhs.makeIterator()

		func nextSymbol<T: IteratorProtocol>(it: inout T, state: inout States) -> I? where T.Element == I {
			while true {
				let input = it.next()
				guard let input else { return nil }
				let nextState = states[state!][input]
				guard let nextState else { state = nil; return nil }
				state = nextState.t
				if(nextState.o != nil) {
					return input
				}
			}
		}

		while true {
			// Iterate until the next symbol
			let lhsOutput = nextSymbol(it: &lhsIt, state: &lhsState)
			let rhsOutput = nextSymbol(it: &rhsIt, state: &rhsState)
			// If either state reached oblivion, that's bad
			if lhsState == nil || rhsState == nil {
				return false
			}
			// Both sides reached the end
			if lhsOutput == nil && rhsOutput == nil {
				break
			}
			// If the outputs are unequal, or one side reached the end
			if lhsOutput != rhsOutput {
				return false
			}
		}
		return true
	}

	public func contains(_ input: some Sequence<I>) -> Bool {
		var currentState = self.initial;

		for symbol in input {
			guard currentState < self.states.count,
					let nextState = self.states[currentState][symbol]
			else {
				return false
			}
			currentState = nextState.t
		}

		return self.finals.contains(currentState)
	}

	/// Checks if the DFT accepts a given input sequence and returns the output if accepted.
	public func map(_ input: some Sequence<I>) -> Output? {
		var output: Output = []
		var state = self.initial
		for s in input {
			let table = self.states[state]
			guard let transition = table[s] else { return nil }
			state = transition.t
			if let o = transition.o {
				output.append(o)
			}
		}
		return isFinal(state) ? output : nil
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
}

/// a transition/output pair
public struct TO<T: Hashable, O: Hashable>: Hashable {
	public let t: T
	public let o: O?
}

/// an Input/Output pair
public struct IO<I: Hashable, O: Hashable>: Hashable {
	public let i: I
	public let o: O?
}

extension DFT where I == O {
	/// Generate a DFT equivalence with individual partitions per input
	/// i.e. all values are different, no values are equivalent
	init(bottom: DFA<I>) {
		self.states = bottom.states.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.key, TO(t: $0.value, o: $0.key)) }) }
		self.initial = bottom.initial
		self.finals = bottom.finals
	}
}

/// Extension to convert a DFA to a DFT with a default output mapping.
extension DFA {
	func toDFT() -> DFT<Symbol, Symbol> {
		let newStates = states.map { table in Dictionary(uniqueKeysWithValues: table.map { ($0.key, TO(t: $0.value, o: $0.key)) }) }
		return DFT(states: newStates, initial: initial, finals: finals)
	}
}
