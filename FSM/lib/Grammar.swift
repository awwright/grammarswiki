/// Defines how to read a grammar
public protocol GrammarProtocol {
	/// The type for symbols in the strings of the language of the grammar
	associatedtype Alphabet: AlphabetProtocol;
	/// The type for non-terminals
	associatedtype Variable;

	/// A type (usually an enum) that can store either a Symbol or a Variable
	associatedtype BodyElement: GrammarProductionBodyElementProtocol where BodyElement.Terminal == Alphabet.SymbolClass, BodyElement.Nonterminal == Variable;

	/// An array of Terms
	associatedtype Production: GrammarProductionProtocol where Production.BodyElement == BodyElement;

	var start: Variable { get }
	var rules: [Production] { get }
	// Alternatively
	//var initials: Array<Array<Symbol>> { get }

	init()
	init(start: Variable, rules: [Production])
}

/// Production for unrestricted grammars
public protocol GrammarProductionProtocol {
	associatedtype SymbolClass;
	associatedtype Variable;
	associatedtype BodyElement: GrammarProductionBodyElementProtocol where BodyElement.Terminal == SymbolClass, BodyElement.Nonterminal == Variable;

	/// The left-hand side of the production (the "in" side)
	var lhs: [BodyElement] { get };

	/// The right-hand side of the production (the "out" side)
	var rhs: [BodyElement] { get };

	init(lhs: [BodyElement], rhs: [BodyElement])
}

extension GrammarProductionProtocol {
	init(name: Variable, production: [BodyElement]) {
		self.init(lhs: [BodyElement.nonterminal(name)], rhs: production);
	}
}

public protocol GrammarProductionBodyElementProtocol {
	associatedtype Terminal;
	associatedtype Nonterminal;
	static func terminal(_ s: Terminal) -> Self;
	static func nonterminal(_ v: Nonterminal) -> Self;
	var asTerminal: Terminal? { get }
	var asNonterminal: Nonterminal? { get }
}

public enum GrammarProductionBodyElement<Terminal: Hashable, Nonterminal: Hashable>: GrammarProductionBodyElementProtocol, Hashable {
	public typealias Terminal = Terminal;
	public typealias Nonterminal = Nonterminal;
	case terminal(Terminal)
	case nonterminal(Nonterminal)

	public var asTerminal: Terminal? { switch self { case .terminal(let s): s; default: Terminal?.none } }
	public var asNonterminal: Nonterminal? { switch self { case .nonterminal(let s): s; default: Nonterminal?.none } }
}
