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
		// FIXME: actually maybe this is too aggressive, lots of code likes creating empty languages for some reason
		//assert(rules.contains(where: { $0.name == start }))
	}

	/// Computes an upper bound on the possible cardinality of the language
	///
	/// Returns `nil` if the cardinality is infinite.
	/// It may double-count some strings in the language, but reliably determines if a finite cardinality is in fact finite.
	public func maxCardinality() -> Int? {
		// TODO: Add this feature to DFA and RE
		let dict = self.dictionary

		// Build dependency ordering (like toPattern); detect cycles during computation
		var ordering = [start]
		var i = 0
		while i < ordering.count {
			let current = ordering[i];
			guard let prods = dict[current], !prods.isEmpty else {
				i += 1;
				continue;
			}
			for prod in prods {
				for sym in prod.body {
					if case .nonterminal(let name) = sym, !ordering.contains(name) {
						ordering.append(name);
					}
				}
			}
			i += 1;
		}

		// Compute cardinalities bottom-up
		var intermediate: [String: Int] = [:];
		let definitions = dict;
		for name in ordering.reversed() {
			guard let prods = definitions[name], !prods.isEmpty else {
				intermediate[name] = 0;
				continue;
			}
			var total = 0;
			for prod in prods {
				// Start with the multiplicative identity
				var prodCard = 1;
				for elem in prod.body {
					switch elem {
					case .nonterminal(let nt):
						guard let p = intermediate[nt] else {
							return nil; // cycle
						}
						prodCard *= p;
						if p == 0 { break; }
					case .terminal(let t):
						let c = Alphabet.cardinality(t)!
						prodCard *= c;
						if c == 0 { break; }
					}
					if prodCard == 0 { break }
				}
				total += prodCard;
			}
			intermediate[name] = total;
		}
		return intermediate[start] ?? 0
	}

	/// Compute the complexity class of the automaton, measuring the restrictions placed relative to an unrestricted grammar
	///
	/// This will return a number representing the complexity class:
	/// - 0: Unrestricted (Turing-complete)
	/// - 1: Context-sensitive (Linear bounded Turing machine)
	/// - 2: Context-free
	/// - 3: Regular
	/// - 4: Finite
	public func chomskyClass() -> Int {
		// If the CFG has no cycles, then it is finite
		let dict = self.dictionary;
		var all = Set([self.start]);
		var queue = [self.start];
		// FIXME: Need to detect and eliminate epsilon-productions and unit productions, which will false-negative a finite grammar
		while let current = queue.popLast() {
			let previous_seen = all;
			if let prods = dict[current] {
				for prod in prods {
					for sym in prod.body {
						if case .nonterminal(let name) = sym {
							if previous_seen.contains(name) {
								return 2;
							} else {
								queue.append(name)
								all.insert(name)
							}
						}
					}
				}
			}
		}
		return 4;
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
