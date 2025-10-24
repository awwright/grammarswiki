/// A struct that represents a Context-Free Grammar
public protocol CFGProtocol: GrammarProtocol {
	associatedtype Symbol;
}

public struct SymbolCFG<Symbol: Hashable>: CFGProtocol, Hashable {
	public typealias Symbol = Symbol;
	public typealias Variable = String;
	public typealias Term = GrammarTerm<Symbol, Variable>;
	/// A rule in the Context-Free Grammar. Multiple rules with the same name
	public struct Production: GrammarProductionProtocol, Hashable {
		public typealias Symbol = SymbolCFG.Symbol;
		public typealias Variable = SymbolCFG.Variable;

		public let name: String;
		public let production: Array<Term>;
		public var lhs: Array<Term> { [Term.variable(name)] }
		public var rhs: Array<Term> { production }

		public init(name: String, production: Array<Term>) {
			self.name = name
			self.production = production
		}
		public init(lhs: [Term], rhs: [Term]) {
			precondition(lhs.count == 1)
			self.name = lhs[0].asVariable!
			self.production = rhs
		}
	}

	public var rules: Array<Production>
	public var start: Variable

	public var dictionary: Dictionary<String, Array<Production>> {
		return Dictionary(grouping: self.rules, by: \.name);
	}

	/// Get the list of used rule names in breadth-first order from the start symbol
	public var ruleNames: Array<String> {
		let rules = self.dictionary;
		var visited = Set<String>()
		var queue = [start]
		var referencedNames = [String]()
		while let current = queue.first {
			queue.removeFirst()
			if visited.contains(current) { continue }
			visited.insert(current)
			referencedNames.append(current)
			if let rulesForCurrent = rules[current] {
				for rule in rulesForCurrent {
					for symbol in rule.production {
						if case .variable(let name) = symbol {
							if !visited.contains(name) && !queue.contains(name) {
								queue.append(name);
							}
						}
					}
				}
			}
		}
		let ordering = Dictionary(uniqueKeysWithValues: referencedNames.enumerated().map { ($1, $0) })
		return rules.keys.sorted { (ordering[$0] ?? Int.max) < (ordering[$1] ?? Int.max) }
	}

	public init() {
		self.rules = []
		self.start = ""
	}
	public init(rules: [Production], start: String) {
		self.rules = rules
		self.start = start
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
