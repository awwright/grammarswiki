/// A struct that represents a Context-Free Grammar
public protocol CFGProtocol: GrammarProtocol {
}

public struct CFG<Alphabet: AlphabetProtocol & Hashable>: CFGProtocol, Hashable {
	public typealias Alphabet = Alphabet
	public typealias Symbol = Alphabet.Symbol
	public typealias SymbolClass = Alphabet.SymbolClass

	public typealias Variable = String;
	public typealias BodyElement = GrammarProductionBodyElement<SymbolClass, Variable>;
	/// A rule in the Context-Free Grammar. Multiple rules with the same name
	public struct Production: GrammarProductionProtocol, Hashable {
		public let name: String;
		public let body: Array<BodyElement>;

		// Generates the equivalent context-sensitive grammar
		public var lhs: Array<BodyElement> { [.nonterminal(name)] }
		public var rhs: Array<BodyElement> { body }

		public init(name: String, production: Array<BodyElement>) {
			self.name = name
			self.body = production
		}
		public init(lhs: [BodyElement], rhs: [BodyElement]) {
			precondition(lhs.count == 1)
			self.name = lhs[0].asNonterminal!
			self.body = rhs
		}
	}

	public var start: Variable
	public var rules: Array<Production>

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
					for symbol in rule.body {
						if case .nonterminal(let name) = symbol {
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
	public init(start: String, rules: [Production]) {
		self.start = start
		self.rules = rules
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
