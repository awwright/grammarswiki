/// A protocol for any PDA and its subsets including DPDA and finite automata
protocol PDAProtocol<Symbol> {
	associatedtype Symbol: Hashable;
	associatedtype Key: Hashable;
	associatedtype State: Hashable;
	associatedtype TransitionTarget: Hashable;

	// A PDA has:
	// - A set of states (tracked as Int)
	// - A set of input symbols (tracked as Alphabet)
	// - A set of stack symbols (tracked as Int)
	// - A transition function, tracked as a set of Transitions
	/// A definition for the transition function
	var transitionsSet: Dictionary<Key, Set<Dictionary<Symbol, TransitionTarget>>> {get};
	/// Epsilon transitions that must be performed after an input symbol is consumed
	var transitionsEpsilon: Dictionary<Key, Set<TransitionTarget>> {get};
	// - A start state & stack symbol
	var initialStack: Set<State> {get};
	// - A set of accepting states
	var finals: Set<Int> {get};


	//var transitionsSet: Set<Transition> { get }
	func getAll(states: Set<Int>, symbol: Symbol) -> Set<Symbol>;
	func getAll(states: Set<Int>, string: any Sequence<Symbol>) -> Set<Symbol>;
}

/// A representation of a pushdown automata.
///
/// Equivalency of two PDAs is incomplete: there might be multiple PDAs that represent the same language, but that are not merged into the same equivalency partition because the equivalence is cannot be proven.
struct PDA<Symbol: Hashable>: PDAProtocol {
	typealias Symbol = Symbol;

	public struct Key: Hashable {
		let state: Int
		let stack: Int
	}
	public struct State: Hashable {
		let state: Int
		let stack: [Int]
	}
	public struct TransitionTarget: Hashable {
		let toState: Int
		let pushStack: [Int]
	}

	// A PDA has:
	// - A set of states (tracked as Int)
	// - A set of input symbols (tracked as Alphabet)
	// - A set of stack symbols (tracked as Int)
	// - A transition function, tracked as a set of Transitions
	/// A definition for the transition function
	public let transitionsSet: Dictionary<Key, Set<Dictionary<Symbol, TransitionTarget>>>;
	/// Epsilon transitions that must be performed after an input symbol is consumed
	public let transitionsEpsilon: Dictionary<Key, Set<TransitionTarget>>;
	// - A start state & stack symbol
	/// The initial set of states (including stack symbols)
	/// This must include all epsilon transitions, since they are only recomputed when consuming a symbol
	public let initialStack: Set<State>;
	// - A set of accepting states
	/// States (from the common state) that signals acceptance
	public let finals: Set<Int>;

	public func contains(_ input: some Sequence<Symbol>) -> Bool {
		var currentState = initialStack;
		for symbol in input {
			let next = currentState.flatMap {
				let state = $0;
				let top = Key(state: $0.state, stack: $0.stack.last!);
				let table = self.transitionsSet[top] ?? [];
				return table.flatMap {
					let v = $0[symbol];
					if let v, state.stack.count > 0 {
						let nextState = State(state: v.toState, stack: Array(state.stack[0..<state.stack.count-1]) + v.pushStack)
						return [nextState]
					} else {
						return []
					}
				}
			};
			currentState = self.followε(states: Set(next))
		}

		return currentState.contains(where: { self.finals.contains($0.state) });
	}

	/// Get a list of states after following epsilon transitions,
	/// i.e. get a list of all the states equivalent to any of the given
	func followε(states: Set<State>) -> Set<State> {
		var expanded = states;
		var list = Array(states);
		// Iterate over every state in states
		var i = 0;
		while i < list.count {
			let state = list[i];
			let transitions = self.transitionsEpsilon[Key(state: state.state, stack: state.stack.last!)] ?? [];
			for next in transitions {
				let nextState = State(state: next.toState, stack: Array(state.stack[0..<state.stack.count-1]) + next.pushStack)
				if(!expanded.contains(nextState)){
					expanded.insert(nextState);
					list.append(nextState);
				}
			}
			i += 1;
		}
		return expanded;
	}

	func get(states: Set<Int>, symbol: Symbol) -> [Symbol] {
		// Placeholder implementation: return empty array
		return []
	}

	func getAll(states: Set<Int>, symbol: Symbol) -> Set<Symbol> {
		return Set<Symbol>(self.get(states: states, symbol: symbol));
	}
	func getAll(states: Set<Int>, string: any Sequence<Symbol>) -> Set<Symbol> {
		// Placeholder implementation: return empty set
		return Set<Symbol>()
	}

	// If the PDA cannot be represented as a pattern, then this will throw
	func toPattern<PatternType: SymbolClassPatternBuilder>() throws -> PatternType where PatternType.Symbol == Symbol {
		// Placeholder implementation: throw an error
		throw ABNFExportError(message: "PDA to pattern conversion not implemented")
	}
}
