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
// TODO: Conformance with PartitionedSetProtocol so this can be used as the transition table for non-deterministic finite automata
public struct DFT<Symbol: Comparable & Hashable>: Hashable {
	/// Default element type produced reading this as a Sequence
	public typealias Element = Array<Symbol>
	/// Default type that inputs are mapped to (to label a partition)
	public typealias Output = Array<Symbol>
	/// The type used to index states.
	public typealias StateNo = Int
	/// The type of a set of states, optional to include the oblivion state (`nil`).
	public typealias States = StateNo?

	public static var empty: Self {
		Self(states: [[:]], initial: 0, finals: [:])
	}

	public static var epsilon: Self {
		Self(states: [[:]], initial: 0, finals: [0: []])
	}

	/// The transition table, mapping each state to a dictionary of input symbol to (next state, output sequence) pairs.
	public let states: Array<Dictionary<Symbol, StateNo>>
	/// The output produced at each transition
	public let output: Array<Dictionary<Symbol, Output>>
	/// The initial state of the DFT.
	public let initial: StateNo
	/// The set of accepting (final) states and associated final output
	public let finals: Dictionary<StateNo, Output>

	/// Creates an empty DFT that accepts no sequences and produces no output.
	public init() {
		self.states = [[:]]
		self.output = [[:]]
		self.initial = 0
		self.finals = [:]
	}

	/// Creates a DFT with specified states, initial state, and final states.
	///
	/// - Parameters:
	///   - states: The transition table; defaults to an empty state if not provided.
	///   - initial: The starting state; must be within `states` bounds.
	///   - finals: The set of accepting states; all must be within `states` bounds.
	public init(
		states: Array<Dictionary<Symbol, StateNo>> = [[:]],
		output: Array<Dictionary<Symbol, Output>> = [[:]],
		initial: StateNo = 0,
		finals: Dictionary<StateNo, Output> = [:]
	) {
		for transitions in states {
			for (_, next) in transitions {
				assert(next >= 0)
				assert(next < states.count)
			}
		}
		assert(initial >= 0)
		assert(initial < states.count)
		for (state, _) in finals {
			assert(state >= 0)
			assert(state < states.count)
		}

		self.states = states
		self.output = output
		self.initial = initial
		self.finals = finals
	}

	/// Generate a DFT equivalence with a single partition
	/// i.e. all values are equivalent
	public init(top: DFA<Symbol>) {
		self.states = top.states
		self.output = top.states.map { $0.mapValues { _ in [] } }
		self.initial = top.initial
		self.finals = Dictionary(uniqueKeysWithValues: top.finals.map { ($0, []) })
	}
	/// Generate a DFT equivalence with individual partitions per input
	/// i.e. all values are different, no values are equivalent
	public init(bottom: DFA<Symbol>) {
		self.states = bottom.states
		self.output = bottom.states.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.key, [$0.key]) }) }
		self.initial = bottom.initial
		self.finals = Dictionary(uniqueKeysWithValues: bottom.finals.map { ($0, []) })
	}

	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.states == rhs.states &&
		lhs.initial == rhs.initial &&
		lhs.finals == rhs.finals
	}

	public var alphabet: Set<Symbol> {
		Set(states.flatMap(\.keys))
	}

	//	public var outputAlphabet: Set<Symbol> {
	//		Set(output.flatMap { $0.values.flatMap { $0.output } })
	//	}

	/// Transitions from a state on a given input symbol, returning the next state and output.
	public func nextState(state: StateNo, symbol: Symbol) -> StateNo? {
		assert(state >= 0)
		assert(state < self.states.count)
		if let transition = self.states[state][symbol] {
			return transition
		}
		return nil
	}

	/// Checks if a state is accepting.
	public func isFinal(_ state: States) -> Bool {
		guard let state else { return false }
		return self.finals[state] != nil
	}

	/// Determines if two inputs are equivalent according to the DFT (maps to the same output)
	/// This will decide even on inputs that are not accepting because this will come to a decision
	/// before it ever reaches the end of the input.
	public func isEquivalent(_ lhs: some Sequence<Symbol>, _ rhs: some Sequence<Symbol>) -> Bool {
		return mappedSequence(lhs.makeIterator()).elementsEqual(mappedSequence(rhs.makeIterator()))
	}

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

		return self.finals[currentState] != nil
	}

	/// Checks if the DFT accepts a given input sequence and returns the output if accepted.
	public func map(_ input: some Sequence<Symbol>) -> Output? {
		var output: Output = []
		var state = self.initial
		for s in input {
			let table = self.states[state]
			guard let transition = table[s] else { return nil }
			state = transition
			if let o = self.output[state][s] {
				output += o
			}
		}
		if let final = self.finals[state] {
			return output + final
		} else {
			return nil
		}
	}

	/// Return a DFA that also accepts the empty sequence
	/// i.e. adds the initial state to the set of final states
	public func optional() -> Self {
		var newFinals = self.finals;
		if(newFinals[initial] == nil) {
			newFinals[initial] = []
		}
		return Self(
			states: self.states,
			initial: self.initial,
			finals: newFinals
		);
	}

	/// Maps input symbols to output symbols one at a time
	public func mappedSequence<It: IteratorProtocol>(_ input: It) -> AnyIterator<Symbol> where It.Element == Symbol {
		var currentState = initial
		var inputIterator = input
		var currentOutput: [Symbol] = []
		var outputIndex = 0

		return AnyIterator {
			// Keep going until we have a symbol to return
			while true {
				// If we have symbols in currentOutput to yield
				if outputIndex < currentOutput.count {
					let symbol = currentOutput[outputIndex]
					outputIndex += 1
					return symbol
				}

				// If we've exhausted current output, check if we're done
				if let symbol = inputIterator.next() {
					// Process next input symbol
					guard currentState < states.count,
							let nextState = states[currentState][symbol],
							let transitionOutput = output[currentState][symbol] else {
						fatalError("Invalid transition for symbol \(symbol) from state \(currentState)")
					}

					currentOutput = transitionOutput
					outputIndex = 0
					currentState = nextState
				} else {
					// No more input, check final state and yield final output
					guard let finalOutput = finals[currentState] else {
						fatalError("Input sequence ended in non-final state \(currentState)")
					}

					if finalOutput.isEmpty {
						return nil // Done
					}

					currentOutput = finalOutput
					outputIndex = 0
				}
			}
		}
	}
}
