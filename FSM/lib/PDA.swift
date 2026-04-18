/// A protocol for any PDA and its subsets including DPDA and finite automata
protocol PDAProtocol<Symbol> {
	associatedtype Symbol: Hashable;
	associatedtype TransitionKey: Hashable;
	associatedtype TransitionEpsilon: Hashable;
	associatedtype TransitionTarget: Hashable;

	// A PDA has:
	// - A set of states (tracked as Int)
	// - A set of input symbols (tracked as Alphabet)
	// - A set of stack symbols (tracked as Int)
	// - A transition function, tracked as a set of Transitions
	/// A definition for the transition function
	var transitionsSet: Dictionary<TransitionKey, Set<TransitionTarget>> {get};
	/// Epsilon transitions that must be performed after an input symbol is consumed
	var transitionsEpsilon: Dictionary<TransitionEpsilon, Set<TransitionTarget>> {get};
	// - A start state
	var initials: Set<Int> {get};
	// - A start stack symbol
	var initialStack: Set<Int> {get};
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

	public struct TransitionKey: Hashable {
		let state: Int
		let stack: Int
		let input: Symbol
	}
	public struct TransitionEpsilon: Hashable {
		let state: Int
		let stack: Symbol
	}
	public struct TransitionTarget: Hashable {
		let toState: Int
		let pushSymbols: [Symbol]
	}

	// A PDA has:
	// - A set of states (tracked as Int)
	// - A set of input symbols (tracked as Alphabet)
	// - A set of stack symbols (tracked as Int)
	// - A transition function, tracked as a set of Transitions
	/// A definition for the transition function
	public let transitionsSet: Dictionary<TransitionKey, Set<TransitionTarget>>;
	/// Epsilon transitions that must be performed after an input symbol is consumed
	public let transitionsEpsilon: Dictionary<TransitionEpsilon, Set<TransitionTarget>>;
	// - A start state
	public let initials: Set<Int>;
	// - A start stack symbol
	public let initialStack: Set<Int>;
	// - A set of accepting states
	public let finals: Set<Int>;

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
