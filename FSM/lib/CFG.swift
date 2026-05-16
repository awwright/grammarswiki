/// A struct that represents a Context-Free Grammar
public protocol CFGProtocol: GrammarProtocol where Production: CFGProductionProtocol {
}

/// A CFG production must have exactly one variable on the left-hand side
public protocol CFGProductionProtocol: GrammarProductionProtocol {
	var name: Variable {get};
	var body: Array<BodyElement> {get};
}

public typealias CFG<Alphabet: AlphabetProtocol> = CFGNamed<String, Alphabet>;

public struct CFGNamed<Variable: Hashable, Alphabet: AlphabetProtocol & Hashable>: CFGProtocol, Hashable {
	public typealias Alphabet = Alphabet
	public typealias Symbol = Alphabet.Symbol
	public typealias SymbolClass = Alphabet.SymbolClass

	public typealias Variable = Variable;
	public typealias BodyElement = GrammarProductionBodyElement<SymbolClass, Variable>;
	/// A rule in the Context-Free Grammar. Multiple rules with the same name
	public struct Production: CFGProductionProtocol, Hashable {
		// TODO: name can be anything as long as it's Equatable and Hashable (usable as a Dictionary key)
		// This would be useful for using Int or tuples as production names, for example, representing parse forests.
		public let name: Variable;
		public let body: Array<BodyElement>;

		// Generates the equivalent context-sensitive grammar
		public var lhs: Array<BodyElement> { [.nonterminal(name)] }
		public var rhs: Array<BodyElement> { body }

		public init(name: Variable, production: Array<BodyElement>) {
			self.name = name
			self.body = production
		}
		public init(lhs: [BodyElement], rhs: [BodyElement]) {
			precondition(lhs.count == 1)
			self.name = lhs[0].asNonterminal!
			self.body = rhs
		}
		public init<T: GrammarProductionProtocol>(_ from: T) throws where T.Variable == Variable, T.BodyElement == BodyElement {
			precondition(from.lhs.count == 1)
			self.name = from.lhs[0].asNonterminal!
			self.body = from.rhs
		}
	}

	public var start: Array<Variable>
	public var rules: Array<Production>

	public var dictionary: Dictionary<Variable, Array<Production>> {
		return Dictionary(grouping: self.rules, by: \.name);
	}

	/// Get the list of used rule names in breadth-first order from the start symbol
	public var ruleNames: Array<Variable> {
		let rules = self.dictionary;
		var visited = Set<Variable>()
		var queue = start;
		var referencedNames = [Variable]()
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
		self.start = [];
		self.rules = []
	}

	/// Createa a context-free grammar with the given rules and starting rule
	public init(start: Variable, rules: [Production]) {
		self.start = [start]
		self.rules = rules
		// For the sake of bug catching, we usually want the starting rule to have at least one production when using this constructor.
		// FIXME: actually maybe this is too aggressive, lots of code likes creating empty languages for some reason
		//assert(rules.contains(where: { $0.name == start }))
	}

	/// Createa a context-free grammar with the given rules and starting rules
	public init(startSet: [Variable], rules: [Production]) {
		self.start = startSet;
		self.rules = rules;
	}

	private struct ParseStateItem: Hashable {
		let production: Production
		/// How many body elements have been parsed (zero through the element count inclusive)
		let progress: Int
		/// The offset of this production's first symbol from the string's first symbol
		let offset: Int
		// Computed properties
		var isComplete: Bool { progress == production.body.count }
		var expecting: Production.BodyElement? { progress < production.body.count ? production.body[progress] : nil }
		func next() -> Self { ParseStateItem(production: production, progress: progress + 1, offset: offset) }
	}

	/// Recognise (accept or reject) the given string as being in the grammar
	public func contains(_ string: Array<Alphabet.Symbol>) -> Bool {
		let chart = parse(string);
		// Accept if any completed start item spans the entire input from origin 0
		return chart.last!.contains { start.contains($0.production.name) && $0.isComplete && $0.offset == 0 };
	}

	/// Recognise (accept or reject) the given string as being in the grammar
	private func parse(_ string: Array<Alphabet.Symbol>) -> Array<Array<ParseStateItem>> {
		// TODO: Add a filter for which rule names will be saved and returned (and when non-matching attempts can be released).
		// For example, only save the rules that match an actual ABNF production, or a regular expression capturing group, and not the intermediate matches.
		let dict = self.dictionary;
		let len = string.count;

		// Chart: one set of items per input position (0..n)
		var chart: Array<Array<ParseStateItem>> = Array(repeating: [], count: len + 1);
		var currentSet: Set<ParseStateItem> = [];

		// Seed chart[0] with all productions for the start symbol (dot at 0, origin 0)
		for prod in (start.flatMap{ dict[$0] ?? [] }) {
			var startRule = ParseStateItem(production: prod, progress: 0, offset: 0);
			if currentSet.insert(startRule).inserted { chart[0].append(startRule); }
		}

		// Process each chart position
		for i in 0...len {
			var j = 0;
			while j < chart[i].count {
				let item = chart[i][j];
				if item.isComplete {
					// Completer
					let nt = item.production.name;
					for prevItem in chart[item.offset] {
						if let expecting = prevItem.expecting, case .nonterminal(let name) = expecting, name == nt {
							let advanced = prevItem.next();
							if currentSet.insert(advanced).inserted { chart[i].append(advanced) }
						}
					}
				} else if let expecting = item.expecting, case .nonterminal(let name) = expecting {
					// Predictor
					if let prods = dict[name] {
						for prod in prods {
							let predicted = ParseStateItem(production: prod, progress: 0, offset: i);
							if currentSet.insert(predicted).inserted { chart[i].append(predicted) }
						}
					}
				}
				j += 1;
			}
			currentSet = [];

			// Scanner: advance items expecting the current terminal (if i < n)
			if i < len {
				let currentSymbol = string[i];
				for item in chart[i] {
					if let expecting = item.expecting, case .terminal(let symClass) = expecting {
						// TODO: Use a dedicated SymbolClass.contains function
						if Alphabet.contains(symClass, currentSymbol) {
							let advanced = item.next();
							if currentSet.insert(advanced).inserted { chart[i + 1].append(advanced); }
						}
					}
				}
				currentSet = [];
			}
		}
		return chart;
	}

	/// A representation of a parse tree for the current CFG.
	public typealias ParseTree = CFGNamed<ParseTreeKey, Alphabet>;

	///The production name in a ParseTree is the name of the production combined with substring slice information
	public struct ParseTreeKey: Hashable {
		public let name: Variable;
		public let offset: Int;
		public let length: Int;
	}

	/// Parse the given string as being in the grammar
	///
	/// This will return a new CFG, with at most one production per rule.
	public func parseTree(_ string: Array<Alphabet.Symbol>) -> ParseTree {
		let chart = parse(string);
		let len = string.count;

		// Construct the parse tree as a CFGNamed<TreeKey, Alphabet> with exactly one production per TreeKey
		guard let rootItem = chart[len].first(where: { start.contains($0.production.name) && $0.isComplete && $0.offset == 0 }) else {
			return ParseTree(); // empty language if no parse
		}

		var treeProductions: [ParseTree.Production] = [];
		var seenKeys = Set<ParseTreeKey>();
		// rootItem is going to be one of the matches for a start symbol that spans the entire input
		//
		return ParseTree(start: build(item: rootItem, end: len), rules: treeProductions);

		func build(item: ParseStateItem, end: Int) -> ParseTreeKey {
			let key = ParseTreeKey(name: item.production.name, offset: item.offset, length: end - item.offset);
			if seenKeys.contains(key) { return key; }
			seenKeys.insert(key);

			// Reconstruct body by walking the advances for this item
			var body: [GrammarProductionBodyElement<SymbolClass, ParseTreeKey>] = [];
			var pos = item.offset;
			var prog = 0;
			while prog < item.production.body.count {
				let elem = item.production.body[prog];
				switch elem {
					case .terminal(let symClass):
						// Must be a scanner advance of exactly one symbol
						if pos < end {
							let sym = string[pos];
							// Verify it belongs to the class (as done in scanner)
							if Alphabet.contains(symClass, sym) {
								body.append(.terminal(symClass));
								pos += 1;
								prog += 1;
							} else {
								// fallback (should not happen on a valid parse)
								break;
							}
						}
					case .nonterminal(let childName):
						// Find a completed child item that advanced this step
						// Search chart for a completer that produced an item expecting this nonterminal at pos
						var foundChild: ParseStateItem? = nil;
						var childEnd = pos;
						for j in (pos...end).reversed() {
							for prev in chart[pos] {
								if let exp = prev.expecting,
									case .nonterminal(let nm) = exp,
									nm == childName,
									let completed = chart[j].first(where: { $0.production.name == childName && $0.isComplete && $0.offset == pos })
								{
									foundChild = completed;
									childEnd = j;
									break;
								}
							}
							if foundChild != nil { break; }
						}
						if let child = foundChild {
							let childKey = build(item: child, end: childEnd);
							body.append(.nonterminal(childKey));
							pos = childEnd;
							prog += 1;
						} else {
							// fallback
							break;
						}
				}
			}

			let treeProd = ParseTree.Production(name: key, production: body);
			treeProductions.append(treeProd);
			return key;
		}
	}

	// TODO: Implement a simple forest parser (returns a parse forest)

	/// Computes an upper bound on the possible cardinality of the language
	///
	/// Returns `nil` if the cardinality is infinite.
	/// It may double-count some strings in the language, but reliably determines if a finite cardinality is in fact finite.
	public func maxCardinality() -> Int? {
		// TODO: Add this feature to DFA and RE
		let dict = self.dictionary

		// Build dependency ordering (like toPattern); detect cycles during computation
		var ordering = start;
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
		var intermediate: [Variable: Int] = [:];
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
		return start.reduce(0) { $0 + (intermediate[$1] ?? 0) };
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
		var all = Set(self.start);
		var queue = self.start;
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
