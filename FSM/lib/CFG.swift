/// A struct that represents a Context-Free Grammar
public protocol CFGProtocol: GrammarProtocol where Production: CFGProductionProtocol {
}

/// A CFG production must have exactly one variable on the left-hand side
public protocol CFGProductionProtocol: GrammarProductionProtocol {
	var name: Variable {get};
	var body: Array<BodyElement> {get};
	init(name: Variable, body: Array<BodyElement>);
}

public typealias CFG<Alphabet: AlphabetProtocol> = CFGNamed<String, Alphabet>;

public struct CFGNamed<Variable: Hashable, Alphabet: AlphabetProtocol & Hashable>: CFGProtocol, Hashable, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral {
	public typealias Alphabet = Alphabet
	public typealias Symbol = Alphabet.Symbol
	public typealias SymbolClass = Alphabet.SymbolClass

	public typealias Variable = Variable;
	public typealias BodyElement = GrammarProductionBodyElement<SymbolClass, Variable>;
	/// A sequence of body elements, concatenated together
	public typealias Alternative = Array<BodyElement>;
	/// A rule in the Context-Free Grammar. Multiple rules with the same name
	public struct Production: CFGProductionProtocol, Hashable {
		// TODO: name can be anything as long as it's Equatable and Hashable (usable as a Dictionary key)
		// This would be useful for using Int or tuples as production names, for example, representing parse forests.
		public let name: Variable;
		public let body: Alternative;

		// Generates the equivalent context-sensitive grammar
		public var lhs: Alternative { [.nonterminal(name)] }
		public var rhs: Alternative { body }

		public init(name: Variable, body: Alternative) {
			self.name = name
			self.body = body
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
		public func reversed() -> Self {
			Self(name: name, body: body.reversed())
		}
	}

	public var start: Array<Variable>
	public var productions: Array<Production>

	public var dictionary: Dictionary<Variable, Array<Production>> {
		return Dictionary(grouping: self.productions, by: \.name);
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

	/// Get the list of used rule names in breadth-first order from the start symbol
	public var ruleNamesDepthFirst: Array<Variable> {
		let rules = self.dictionary;
		var visited = Set<Variable>()
		var stack = Array(start.reversed())   // LIFO stack; reverse so first start symbol is processed first
		var referencedNames = [Variable]()
		while let current = stack.popLast() {
			if visited.contains(current) { continue }
			visited.insert(current)
			referencedNames.append(current)
			if let rulesForCurrent = rules[current] {
				// Push in reverse so the leftmost child is popped next (pre-order DFS)
				for rule in rulesForCurrent.reversed() {
					for symbol in rule.body.reversed() {
						if case .nonterminal(let name) = symbol {
							if !visited.contains(name) && !stack.contains(name) {
								stack.append(name);
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
		self.productions = []
	}

	/// Createa a context-free grammar with the given rules and starting rule
	public init(start: Variable, productions: [Production]) {
		self.start = [start]
		self.productions = productions
		// For the sake of bug catching, we usually want the starting rule to have at least one production when using this constructor.
		// FIXME: actually maybe this is too aggressive, lots of code likes creating empty languages for some reason
		//assert(rules.contains(where: { $0.name == start }))
	}

	/// Createa a context-free grammar with the given rules and starting rules
	public init(startSet: [Variable], productions: [Production]) {
		self.start = startSet;
		self.productions = productions;
	}

	public typealias Key = Variable
	public typealias Value = Array<Array<BodyElement>>
	public init(dictionaryLiteral elements: (Variable, Array<Array<BodyElement>>)...) {
		if elements.isEmpty { self.start = []; self.productions = []; return; }
		self.start = [elements.first!.0];
		self.productions = elements.flatMap { (name, productions) in productions.map { .init(name: name, body: $0) } };
	}

	public typealias ArrayLiteralElement = Production
	public init(arrayLiteral elements: Production...) {
		if elements.isEmpty { self.start = []; self.productions = []; return; }
		self.start = [elements.first!.name];
		self.productions = elements;

	}

	/// Recognise (accept or reject) the given string as being in the grammar
	public func contains(_ string: Array<Alphabet.Symbol>) -> Bool {
		Parser(grammar: self, string: string).isCompleted;
	}

	public func parse(_ string: Array<Alphabet.Symbol>) -> Parser {
		Parser(grammar: self, string: string)
	}

	/// A streaming parser
	///
	/// In a more prefect world, this could just be a subclass of CFG (where the properties of CFG are copied to CFG.Parser)
	public struct Parser {
		let grammar: CFGNamed<Variable, Alphabet>;
		let start: Array<Variable>;
		var len: Int
		var i: Int = 0
		var dict: Dictionary<Variable, Array<Production>>
		var expectedVariables: Array<Array<ParseStateItem>>
		var expectedVariablesDict: Array<Dictionary<Variable, Array<ParseStateItem>>>
		var expectedSymbols: Array<Array<ParseStateItem>>
		var completed: Array<Array<ParseStateItem>>

		public struct ParseStateItem: Hashable, CustomStringConvertible {
			public let production: Production
			/// How many body elements have been parsed (zero through the element count inclusive)
			public let progress: Int
			/// The offset of this production's first symbol from the string's first symbol
			public let offset: Int
			// TODO: Add an `end` property that stores the end position that this item matches, which would replace the `i` argument in Parser.addChart
			// Computed properties
			public var isComplete: Bool { progress == production.body.count }
			public var expecting: Production.BodyElement? { progress < production.body.count ? production.body[progress] : nil }
			func next() -> Self { ParseStateItem(production: production, progress: progress + 1, offset: offset) }
			public var description: String {
				"\(self.production.name) @\(offset) →" + self.production.rhs.enumerated().map { (element_i, element) in
					let c = (self.progress == element_i ? "● " : "")
					let x = switch element {
					case .nonterminal(let x): String(describing: x);
					case .terminal(let x): String(describing: x);
					};
					return  " \(c)\(x)";
				}.joined(separator: "") + (isComplete ? " ■" : "")
			}
		}

		/// Create a parser for an empty language and empty string
		init() {
			grammar = .init();
			len = 0;
			expectedVariables = [];
			expectedVariablesDict = [];
			expectedSymbols = [];
			completed = [];
			dict = [:];
			start = [];
		}

		/// Create a parser for the given grammar parsing the empty string
		init(grammar: CFGNamed) {
			self.grammar = grammar;
			dict = grammar.dictionary;
			start = grammar.start;
			len = 0;
			expectedVariables = Array(repeating: [], count: len + 1);
			expectedVariablesDict = Array(repeating: [:], count: len + 1);
			expectedSymbols = Array(repeating: [], count: len + 1);
			completed = Array(repeating: [], count: len + 1);
			// Seed chart[0] with all productions for the start symbol (dot at 0, origin 0)
			for prod in (grammar.start.flatMap{ dict[$0] ?? [] }) {
				// Can ignore the return result of this, the completer will get re-run at least once
				addChart(i: 0, item: ParseStateItem(production: prod, progress: 0, offset: 0));
			}
		}

		/// Create a parser for the given grammar, parsing a string of the given length.
		///
		/// The string can be provided by calling ``parseSymbol(_:)`` and signaling EOF with `parseSymbol(nil)`
		init(grammar: CFGNamed, len: Int) {
			self.grammar = grammar;
			dict = grammar.dictionary;
			start = grammar.start;
			self.len = len;
			expectedVariables = Array(repeating: [], count: len + 1);
			expectedVariablesDict = Array(repeating: [:], count: len + 1);
			expectedSymbols = Array(repeating: [], count: len + 1);
			completed = Array(repeating: [], count: len + 1);
			// Seed chart[0] with all productions for the start symbol (dot at 0, origin 0)
			for prod in (grammar.start.flatMap{ dict[$0] ?? [] }) {
				// Can ignore the return result of this, the completer will get re-run at least once
				addChart(i: 0, item: ParseStateItem(production: prod, progress: 0, offset: 0));
			}
		}

		/// Create a parser for the given grammar and parse the given string
		init(grammar: CFGNamed, string: Array<Symbol>) {
			self.init(grammar: grammar, len: string.count);
			for chr in string {
				parseSymbol(chr);
			}
			// Run the completer after the final symbol has been consumed
			parseSymbol(nil);
		}

		@discardableResult
		mutating func addChart(i: Int, item: ParseStateItem) -> Bool {
			switch item.expecting {
			case .nonterminal(let variable):
				if !expectedVariables[i].contains(item) {
					expectedVariables[i].append(item);
					expectedVariablesDict[i][variable, default: []].append(item);
					return true;
				}
			case .terminal:
				if !expectedSymbols[i].contains(item) {
					expectedSymbols[i].append(item);
					return true;
				}
			case nil:
				if !completed[i].contains(item) {
					completed[i].append(item);
					return true;
				}
			}
			return false;
		}

		mutating func parseSymbol(_ currentSymbol: Symbol?) {
			var added = true;
			var j = 0;
			while added {
				added = false;

				// Predictor
				// Ensure that all variables expected by incomplete items are also added as items.
				j = 0;
				while j < expectedVariables[i].count {
					let item = expectedVariables[i][j];
					guard let expecting = item.expecting, case .nonterminal(let name) = expecting else { fatalError() }
					for prod in dict[name, default: []] {
						let predicted = ParseStateItem(production: prod, progress: 0, offset: i);
						if addChart(i: i, item: predicted) { added = true; }
					}
					j += 1;
				}

				// Completer
				// If any items were advanced to their final position, that item is complete.
				// Check if that completes any other items, and advance those too.
				// This always includes epsilon items, items with no symbols, those complete immediately.
				j = 0;
				while j < completed[i].count {
					let item = completed[i][j];
					assert(item.isComplete);
					let nt = item.production.name;
					for prevItem in expectedVariablesDict[item.offset][nt, default: []] {
						if let exp = prevItem.expecting,
							case .nonterminal(let name) = exp,
							name == nt {
							let advanced = prevItem.next();
							if addChart(i: i, item: advanced) { added = true; }
						}
					}
					j += 1;
				}

				// Scanner
				// Read the next symbol from the input, and advance any items depending on it.
				// After reading the last symbol in the input, the predictor and completer stage needs to be run one last time,
				// so skip this step in that case.
				if let currentSymbol {
					for item in expectedSymbols[i] {
						if let expecting = item.expecting, case .terminal(let symClass) = expecting {
							if Alphabet.contains(symClass, currentSymbol) {
								let advanced = item.next();
								if addChart(i: i+1, item: advanced) { added = true; }
							}
						}
					}
				}
			}
			i += 1;
		}

		public var isCompleted: Bool {
			// Accept if any completed start item spans the entire input from origin 0
			completed.last!.contains { start.contains($0.production.name) && $0.isComplete && $0.offset == 0 }
		}

		/// Get all of the rules that matches an input to a start symbol
		var rootItems: Array<ParseStateItem> {
			// Accept if any completed start item spans the entire input from origin 0
			completed.last!.filter { start.contains($0.production.name) && $0.isComplete && $0.offset == 0 }
		}

		/// Get the first (highest priority) rule that matches an input to a start symbol
		var rootItem: ParseStateItem? {
			// Accept if any completed start item spans the entire input from origin 0
			completed.last!.first(where: { start.contains($0.production.name) && $0.isComplete && $0.offset == 0 })
		}

		public var allItems: Array<Array<ParseStateItem>> {
			(0...len).map { completed[$0] + expectedVariables[$0] + expectedSymbols[$0] }
		}

		/// Get a grammar that describes exactly the input, in every possible way that the grammar can process the input.
		/// If any rule has multiple alternatives, then the parse is ambiguous.
		public var parseForest: ParseTree {
			let forestStart = start
				.map { ParseTree.Variable(name: $0, offset: 0, length: len) }
				.filter { vari in rootItems.contains(where: { vari.name == $0.production.name }) };
			let items = completed.last!.filter { start.contains($0.production.name) && $0.isComplete && $0.offset == 0 };

			// The list of completed items that we need to generate a parse forest for
			// Initially, add rules matching start variables
			var queue: Array<(ParseStateItem, Int)> = items.map { ($0, len) };

			// The generated parse forest
			var forest: Array<ParseTree.Production> = [];

			var i = 0;
			while i < queue.count {
				let (item, item_end) = queue[i];
				i += 1;
				// Search for all completed items matching the given completed item

				// Iterate through the rules in forestRoot and add the rules that complete it
				// Start at the completed items from the end and work backwards to the start
				// There may be multiple such completions
				var currentItems: Array<(Int, Array<ParseTree.BodyElement>, Array<(ParseStateItem, Int)>)> = [ (item_end, [], []) ];
				while !currentItems.isEmpty {
					let (inputOffset, sequence, newQueue) = currentItems.removeFirst();
					let j = item.production.body.count - 1 - sequence.count;

					if j < 0 {
						// Only add this if the beginning reaches to the start of the completed sequence being matched
						if inputOffset == item.offset {
							let newProduction = ParseTree.Production(name: ParseTree.Variable(name: item.production.name, offset: item.offset, length: item_end-item.offset), body: sequence);
							if !forest.contains(newProduction) {
								forest.append(newProduction);
							}
							newQueue.forEach { tuple in
								if !queue.contains(where: { $0 == tuple }) {
									queue.append(tuple);
								}
							}
						}
						continue;
					}
					let element = item.production.body[j];
					switch element {
					case .terminal(let symbol):
						let terminal = expectedSymbols[inputOffset-1].first(where: { $0.production == item.production && $0.progress == j });
						if let terminal {
							currentItems.append( (inputOffset-1, [.terminal(symbol)]+sequence, newQueue) );
						}
					case .nonterminal(let name):
						// Look for a completed rule by the same name as currentItem
						let previousMatches = completed[inputOffset].filter { $0.production.name == name }
						previousMatches.forEach { previous in
							let length = inputOffset - previous.offset;
							let tuple: (ParseStateItem, Int) = (previous, inputOffset);
							currentItems.append( (previous.offset, [.nonterminal(.init(name: name, offset: previous.offset, length: length))]+sequence, [tuple]+newQueue) );
						}
					}
				}
			}
			// TODO: Ensure that the rules are listed in the same order as the original
			return ParseTree(startSet: forestStart, productions: forest);
		}

		/// List the symbols
		/// The partitions of the alphabet represent the different branches that the input will send the parser
		public var nextSymbols: Alphabet {
			let symbols: Array<SymbolClass> = expectedSymbols.last!.map {
				guard case .terminal(let symbolClass) = $0.expecting else { fatalError(); }
				return symbolClass;
			}
			return Alphabet(partitions: symbols);
		}

		// TODO: Add a function for getting a tree of the next symbols
	}

	/// A representation of a parse tree for the current CFG.
	public typealias ParseTree = CFGNamed<ParseTreeKey, Alphabet>;

	///The production name in a ParseTree is the name of the production combined with substring slice information
	public struct ParseTreeKey: Hashable, CustomStringConvertible {
		public let name: Variable;
		public let offset: Int;
		public let length: Int;
		public var description: String {
			"\(name)@\(offset)-\(offset+length)"
		}
	}

	/// Get the language where each string is reversed, back-to-front and front-to-back
	///
	/// Keep in mind this will also change left tail recursion to the right, etc
	public func reversed() -> Self {
		Self(startSet: start, productions: productions.map { $0.reversed() })
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
		let rules = self.dictionary;
		var visited = Set<Variable>()
		var queue = start;
		while let current = queue.first {
			queue.removeFirst()
			if visited.contains(current) { continue }
			visited.insert(current)
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
		return Self(startSet: start, productions: self.productions.filter { visited.contains($0.name) });
	}

	/// This will return an equivalent CFG except for the production of the empty string, if it did before
	public func eliminateEpsilon() -> Self {
		var epsilonRulesQueue: Array<Variable> = [];
		var epsilonRules: Set<Variable> = [];
		var newProductions: [Production] = self.productions;
		newProductions.forEach { if $0.body.isEmpty && epsilonRules.insert($0.name).inserted { epsilonRulesQueue.append($0.name); } }
		while let epsilonRule = epsilonRulesQueue.popLast() {
			// Remove epsilon productions for this rule
			newProductions = newProductions.filter { $0.name != epsilonRule || !$0.body.isEmpty }
			newProductions = newProductions.flatMap {
				var list = [$0];
				for i in (0..<$0.body.count).reversed() {
					if $0.body[i] == .nonterminal(epsilonRule) {
						list.forEach { production in
							// Make a copy of the production without the ith element
							list.append( Production(name: production.name, body: Array(production.body[0..<i]) + Array(production.body[(i+1)...])) );
							// TODO: Does this preserve the disambiguition priority? Consider flipping list[j] and list.last as needed
						}
					}
				}
				// By the end there should be 2^i productions
				return list;
			}
			// Queue any epsilon rules that were newly created as a side effect
			newProductions.forEach { if $0.body.isEmpty && epsilonRules.insert($0.name).inserted { epsilonRulesQueue.append($0.name); } }
		}
		return Self(startSet: start, productions: newProductions);
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
