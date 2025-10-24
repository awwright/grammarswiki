/// Defines how to read a grammar
public protocol GrammarProtocol {
	/// The type for symbols in the strings of the language of the grammar
	associatedtype Symbol;
	/// The type for non-terminals
	associatedtype Variable;

	/// A type (usually an enum) that can store either a Symbol or a Variable
	associatedtype Term: GrammarTermProtocol where Term.Symbol == Symbol, Term.Variable == Variable;

	/// An array of Terms
	associatedtype Production: GrammarProductionProtocol where Production.Term == Term;

	var rules: [Production] { get }
	var start: Variable { get }
	// Alternatively
	//var initials: Array<Array<Symbol>> { get }

	init()
	init(rules: [Production], start: Variable)
}

/// Production for unrestricted grammars
public protocol GrammarProductionProtocol {
	associatedtype Symbol;
	associatedtype Variable;
	associatedtype Term: GrammarTermProtocol where Term.Symbol == Symbol, Term.Variable == Variable;

	/// The left-hand side of the production (the "in" side)
	var lhs: [Term] { get };

	/// The right-hand side of the production (the "out" side)
	var rhs: [Term] { get };

	init(lhs: [Term], rhs: [Term])
}

extension GrammarProductionProtocol {
	init(name: Variable, production: [Term]) {
		self.init(lhs: [Term.variable(name)], rhs: production);
	}
}

public protocol GrammarTermProtocol {
	associatedtype Symbol;
	associatedtype Variable;
	static func symbol(_ s: Symbol) -> Self;
	static func variable(_ v: Variable) -> Self;
	var asSymbol: Symbol? { get }
	var asVariable: Variable? { get }
}

public enum GrammarTerm<Symbol: Hashable, Variable: Hashable>: GrammarTermProtocol, Hashable {
	public typealias Symbol = Symbol;
	public typealias Variable = Variable;
	case symbol(Symbol)
	case variable(Variable)

	public var asSymbol: Symbol? { switch self { case .symbol(let s): s; default: Symbol?.none } }
	public var asVariable: Variable? { switch self { case .variable(let s): s; default: Variable?.none } }
}
