/// A struct that represents a Context-Free Grammar
public protocol CFGProtocol {
	associatedtype Symbol;
}

/// A superset of Symbol that can also refer to another production (nonterminal), recursively
public enum CFGSymbol<Symbol: Hashable>: Hashable {
	case terminal(Symbol)
	case rule(String)
}

/// A rule in the Context-Free Grammar. Multiple rules with the same name
public struct CFGRule<Symbol: Hashable>: Hashable {
	public let name: String;
	public let production: Array<CFGSymbol<Symbol>>;
}

	public struct SymbolCFG<Symbol: Hashable>: CFGProtocol {
		public typealias Symbol = Symbol;
		public var rules: [CFGRule<Symbol>]
		public var start: String

		public init(rules: [CFGRule<Symbol>], start: String? = nil) {
			self.rules = rules
			self.start = start ?? rules.first?.name ?? ""
		}

	/// Eliminate rules that are never used
	public func eliminateUseless() -> Self {
		fatalError()
	}

	/// This will return an equivalent CFG except for the production of the empty string, if it did before
	public func eliminateEpsilon() -> Self {
		fatalError()
	}

	public func eliminateUnitProduction() -> Self {
		fatalError()
	}

	public func chomskyNormalForm() -> Self {
		fatalError()
	}

	public func greibachNormalForm() -> Self {
		fatalError()
	}

	//public func toPDA() -> SymbolPDA<Symbol> {
	//	fatalError()
	//}
}
