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
		// TODO: name can be anything as long as it's Equatable and Hashable (usable as a Dictionary key)
		// This would be useful for using Int or tuples as production names, for example, representing parse forests.
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

	/// Produce the empty language
	public init() {
		// If no rule exists for the starting nonterminal, that's not an error, that just means the language is the empty set.
		self.start = ""
		self.rules = []
	}

	/// Createa a context-free grammar with the given rules and starting rule
	///
	/// This checks that the grammar will produce at least one string; if this is undesired, use ``init()``
	public init(start: String, rules: [Production]) {
		self.start = start
		self.rules = rules
		// For the sake of bug catching, we usually want the starting rule to have at least one production when using this constructor.
		assert(rules.contains(where: { $0.name == start }))
	}

	/// Compute the complexity of the automaton
	///
	/// This will return a number representing the complexity class:
	/// - 0: Constant
	/// - 1: Log
	/// - 2: Linear
	/// - 3: Log-linear
	/// - 4: Quadratic
	/// - 5: Cubic
	public func memoryRequirements() -> Int {
		// TODO: Fill out several tests here that test if the grammar is constant-space, etc, and return the

		// Failing any of the above tests, there is no known way to reduce the memory complexity below cubic
		return 5;
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
