/// A Context-Free Grammar whose variables are opaque indexes into an array of rules.
///
/// This is the same language representation as ``CFGNamed``, except nonterminal symbols are
/// stored the way ``DFA``/``NFA`` store states: each variable is an `Int` index into ``rules``.
/// `rules[v]` is the list of alternatives for variable `v`.
public struct CFGArray<Alphabet: AlphabetProtocol & Hashable>: CFGProtocol, Hashable, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral {
	public typealias Alphabet = Alphabet
	public typealias Symbol = Alphabet.Symbol
	public typealias SymbolClass = Alphabet.SymbolClass

	/// An opaque index into ``rules``. The integer has no meaning except as an array index.
	public typealias Variable = Int
	public typealias BodyElement = GrammarProductionBodyElement<SymbolClass, Variable>
	/// A sequence of body elements, concatenated togetherGrammarProtocol
	public typealias Alternative = Array<BodyElement>
	/// All alternatives of a single variable. The variable's index is the index into ``rules``.
	public typealias Rule = Array<Alternative>

	/// A rule in the Context-Free Grammar. Multiple rules may share the same name/index.
	public struct Production: CFGProductionProtocol, Hashable {
		public let name: Variable
		public let body: Alternative

		// Generates the equivalent context-sensitive grammar
		public var lhs: Alternative { [.nonterminal(name)] }
		public var rhs: Alternative { body }

		public init(name: Variable, body: Alternative) {
			self.name = name;
			self.body = body;
		}
		public init(lhs: [BodyElement], rhs: [BodyElement]) {
			precondition(lhs.count == 1)
			self.name = lhs[0].asNonterminal!;
			self.body = rhs;
		}
		public init<T: GrammarProductionProtocol>(_ from: T) throws where T.Variable == Variable, T.BodyElement == BodyElement {
			precondition(from.lhs.count == 1);
			self.name = from.lhs[0].asNonterminal!;
			self.body = from.rhs;
		}
		public func reversed() -> Self {
			Self(name: name, body: body.reversed())
		}
		public func mapVariableName<Target: Hashable>(_ transform: ((Variable) -> Target)) -> CFGNamed<Target, Alphabet>.Production {
			CFGNamed<Target, Alphabet>.Production(name: transform(name), body: body.map { switch $0 { case .nonterminal(let name): return .nonterminal(transform(name)); case .terminal(let symbol): return .terminal(symbol); } })
		}
	}

	public var start: Array<Variable>
	/// Alternatives for each variable, indexed by ``Variable``.
	public var rules: Array<Rule>

	public var productions: Array<Production> {
		get {
			rules.enumerated().flatMap { (name, alts) in alts.map { Production(name: name, body: $0) } }
		}
		set {
			self.rules = Self.makeRules(start: start, productions: newValue);
		}
	}

	public var dictionary: Dictionary<Variable, Array<Production>> {
		Dictionary(uniqueKeysWithValues: rules.enumerated().compactMap { (name, alts) in
			alts.isEmpty ? nil : (name, alts.map { Production(name: name, body: $0) })
		})
	}

	/// Get the list of used rule names in breadth-first order from the start symbol
	public var ruleNames: Array<Variable> {
		var visited = Set<Variable>();
		var queue = start;
		var referencedNames = [Variable]();
		while let current = queue.first {
			queue.removeFirst();
			if visited.contains(current) { continue }
			visited.insert(current);
			referencedNames.append(current);
			if current < rules.count {
				for rule in rules[current] {
					for symbol in rule {
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
		return dictionary.keys.sorted { (ordering[$0] ?? Int.max) < (ordering[$1] ?? Int.max) }
	}

	/// Get the list of used rule names in depth-first order from the start symbol
	public var ruleNamesDepthFirst: Array<Variable> {
		var visited = Set<Variable>();
		var stack = Array(start.reversed());
		var referencedNames = [Variable]();
		while let current = stack.popLast() {
			if visited.contains(current) { continue }
			visited.insert(current);
			referencedNames.append(current);
			if current < rules.count {
				for rule in rules[current].reversed() {
					for symbol in rule.reversed() {
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
		return dictionary.keys.sorted { (ordering[$0] ?? Int.max) < (ordering[$1] ?? Int.max) }
	}

	/// Produce the empty language
	public init() {
		// If no rule exists for the starting nonterminal, that's not an error, that just means the language is the empty set.
		self.start = [];
		self.rules = [];
	}

	/// Create a context-free grammar with the given rules and starting rule
	public init(start: Variable, rules: Array<Rule>) {
		self.init(startSet: [start], rules: rules);
	}

	/// Create a context-free grammar with the given rules and starting rules
	public init(startSet: [Variable], rules: Array<Rule>) {
		var maxV = Swift.max(rules.count - 1, startSet.max() ?? -1)
		for alts in rules {
			for alt in alts {
				for e in alt {
					if let v = e.asNonterminal {
						assert(v >= 0);
						maxV = Swift.max(maxV, v);
					}
				}
			}
		}
		for v in startSet {
			assert(v >= 0);
		}
		var padded = rules
		if maxV >= padded.count {
			padded.append(contentsOf: Array(repeating: [], count: maxV - padded.count + 1));
		}
		self.start = startSet;
		self.rules = padded;
	}

	/// Create a context-free grammar with the given productions and starting rule
	public init(start: Variable, productions: [Production]) {
		self.init(startSet: [start], productions: productions);
	}

	/// Create a context-free grammar with the given productions and starting rules
	public init(startSet: [Variable], productions: [Production]) {
		self.start = startSet;
		self.rules = Self.makeRules(start: startSet, productions: productions);
	}

	public typealias Key = Variable
	public typealias Value = Array<Array<BodyElement>>
	public init(dictionaryLiteral elements: (Variable, Array<Array<BodyElement>>)...) {
		if elements.isEmpty { self.start = []; self.rules = []; return }
		self.start = [elements.first!.0];
		self.rules = Self.makeRules(start: self.start, productions: elements.flatMap { (name, productions) in productions.map { .init(name: name, body: $0) } });
	}

	public typealias ArrayLiteralElement = Production
	public init(arrayLiteral elements: Production...) {
		if elements.isEmpty { self.start = []; self.rules = []; return }
		self.start = [elements.first!.name];
		self.rules = Self.makeRules(start: self.start, productions: elements);
	}

	/// Copy any CFG into an array-indexed representation, assigning dense indexes in discovery order.
	public init<From: CFGProtocol>(_ other: From)
	where From.Variable: Hashable, From.Alphabet == Alphabet
	{
		// Collect all variables in a stable order (starts first, then discovery order of LHS + RHS nonterminals)
		var allVars: [From.Variable] = [];
		var seen: Set<From.Variable> = [];

		for v in other.start {
			if seen.insert(v).inserted {
				allVars.append(v);
			}
		}

		for prod in other.productions {
			if seen.insert(prod.name).inserted {
				allVars.append(prod.name);
			}
			for elem in prod.body {
				if let nt = elem.asNonterminal, seen.insert(nt).inserted {
					allVars.append(nt);
				}
			}
		}

		// Dense mapping from source variable to Int index
		let varToInt: [From.Variable: Int] = Dictionary(
			uniqueKeysWithValues: allVars.enumerated().map { ($1, $0) }
		)

		let count = allVars.count;
		var newRules: [Rule] = Array(repeating: [], count: count);

		for prod in other.productions {
			guard let lhs = varToInt[prod.name] else { continue }

			let newBody: Alternative = prod.body.map { elem in
				if let t = elem.asTerminal {
					return .terminal(t);
				} else if let v = elem.asNonterminal {
					let newV = varToInt[v] ?? -1;
					return .nonterminal(newV);
				} else {
					fatalError("BodyElement must be either terminal or nonterminal");
				}
			}

			newRules[lhs].append(newBody);
		}

		self.start = other.start.compactMap { varToInt[$0] };
		self.rules = newRules;
	}

	private static func makeRules(start: [Variable], productions: [Production]) -> [Rule] {
		var maxV = start.max() ?? -1;
		for p in productions {
			assert(p.name >= 0);
			maxV = Swift.max(maxV, p.name);
			for e in p.body {
				if let v = e.asNonterminal {
					assert(v >= 0);
					maxV = Swift.max(maxV, v);
				}
			}
		}
		if maxV < 0 { return [] }
		var rules: [Rule] = Array(repeating: [], count: maxV + 1)
		for p in productions {
			rules[p.name].append(p.body);
		}
		return rules;
	}

	private func alternatives(for name: Variable) -> [Alternative] {
		(name >= 0 && name < rules.count) ? rules[name] : []
	}

	// Union
	public func union(_ other: Self) -> Self {
		fatalError("Unimplemented")
	}

	// Intersection
	public func intersection(_ other: Self) -> Self? {
		fatalError("Unimplemented")
	}

	// Concatenation
	public func concatenate(_ other: Self) -> Self {
		fatalError("Unimplemented")
	}

	// Kleene Star
	public func star() -> Self {
		fatalError("Unimplemented")
	}

	/// Get the language where each string is reversed, back-to-front and front-to-back
	///
	/// Keep in mind this will also change left tail recursion to the right, etc
	public func reversed() -> Self {
		Self(startSet: start, rules: rules.map { alts in alts.map { $0.reversed() } })
	}

	/// Computes an upper bound on the possible cardinality of the language
	///
	/// Returns `nil` if the cardinality is infinite.
	/// It may double-count some strings in the language, but reliably determines if a finite cardinality is in fact finite.
	public func maxCardinality() -> Int? {
		// Build dependency ordering (like toPattern); detect cycles during computation
		var ordering = start
		var i = 0
		while i < ordering.count {
			let current = ordering[i]
			let prods = alternatives(for: current)
			if prods.isEmpty {
				i += 1
				continue
			}
			for prod in prods {
				for sym in prod {
					if case .nonterminal(let name) = sym, !ordering.contains(name) {
						ordering.append(name)
					}
				}
			}
			i += 1
		}

		// Compute cardinalities bottom-up
		var intermediate: [Variable: Int] = [:]
		for name in ordering.reversed() {
			let prods = alternatives(for: name)
			if prods.isEmpty {
				intermediate[name] = 0
				continue
			}
			var total = 0
			for prod in prods {
				// Start with the multiplicative identity
				var prodCard = 1
				for elem in prod {
					switch elem {
					case .nonterminal(let nt):
						guard let p = intermediate[nt] else {
							return nil // cycle
						}
						prodCard *= p
						if p == 0 { break }
					case .terminal(let t):
						let c = Alphabet.cardinality(t)!
						prodCard *= c
						if c == 0 { break }
					}
					if prodCard == 0 { break }
				}
				total += prodCard
			}
			intermediate[name] = total
		}
		return start.reduce(0) { $0 + (intermediate[$1] ?? 0) }
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
		var all = Set(self.start);
		var queue = self.start;
		// FIXME: Need to detect and eliminate epsilon-productions and unit productions, which will false-negative a finite grammar
		while let current = queue.popLast() {
			let previous_seen = all;
			for prod in alternatives(for: current) {
				for sym in prod {
					if case .nonterminal(let name) = sym {
						if previous_seen.contains(name) {
							return 2;
						} else {
							queue.append(name);
							all.insert(name);
						}
					}
				}
			}
		}
		return 4
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
		var visited = Set<Variable>()
		var queue = start
		while let current = queue.first {
			queue.removeFirst()
			if visited.contains(current) { continue }
			visited.insert(current)
			if current < rules.count {
				let rulesForCurrent = rules[current]
				for rule in rulesForCurrent {
					for symbol in rule {
						if case .nonterminal(let name) = symbol {
							if !visited.contains(name) && !queue.contains(name) {
								queue.append(name);
							}
						}
					}
				}
			}
		}
		let allVars = Set(start).union(visited);
		let maxV = allVars.max() ?? -1;
		if maxV < 0 {
			return Self();
		}
		var newRules: [Rule] = Array(repeating: [], count: maxV + 1);
		for v in 0..<rules.count {
			if visited.contains(v) {
				newRules[v] = rules[v];
			}
		}
		let newStart = start.filter { visited.contains($0) };
		return Self(startSet: newStart, rules: newRules);
	}

	/// This will return an equivalent CFG except for the production of the empty string, if it did before
	public func eliminateEpsilon() -> Self {
		var maxV = rules.count - 1;
		for v in start { maxV = Swift.max(maxV, v) }
		for alts in rules {
			for alt in alts {
				for e in alt {
					if case .nonterminal(let v) = e {
						maxV = Swift.max(maxV, v);
					}
				}
			}
		}
		if maxV < 0 {
			return Self();
		}
		var newRules: [Rule] = Array(repeating: [], count: maxV + 1);
		for i in 0..<rules.count {
			newRules[i] = rules[i].map { Array($0) };
		}

		var epsilonRulesQueue: Array<Variable> = [];
		var epsilonRules: Set<Variable> = [];
		for v in 0...maxV {
			if v < newRules.count && newRules[v].contains(where: { $0.isEmpty }) {
				if epsilonRules.insert(v).inserted {
					epsilonRulesQueue.append(v);
				}
			}
		}
		while let epsilonRule = epsilonRulesQueue.popLast() {
			if epsilonRule < newRules.count {
				newRules[epsilonRule] = newRules[epsilonRule].filter { !$0.isEmpty };
			}
			for lhs in 0..<newRules.count {
				let oldAlts = newRules[lhs];
				var generated: [Alternative] = [];
				for orig in oldAlts {
					var list: [Alternative] = [orig];
					for i in (0..<orig.count).reversed() {
						if orig[i] == .nonterminal(epsilonRule) {
							list.forEach { prod in
								let reduced = Array(prod[0..<i]) + Array(prod[(i+1)...]);
								list.append(reduced);
							}
						}
					}
					generated.append(contentsOf: list);
				}
				newRules[lhs] = generated;
			}
			for v in 0..<newRules.count {
				if newRules[v].contains(where: { $0.isEmpty }) && epsilonRules.insert(v).inserted {
					epsilonRulesQueue.append(v);
				}
			}
		}
		for lhs in 0..<newRules.count {
			newRules[lhs].removeAll { $0.isEmpty };
		}
		return Self(startSet: start, rules: newRules);
	}

	/// Substitute productions that are just aliases for another production
	/// This may not work reliably if epsilon productions have not been eliminated!
	public func eliminateUnitProduction() -> Self {
		var variableOrder: [Variable] = [];
		var seen: Set<Variable> = [];
		for v in start {
			if seen.insert(v).inserted { variableOrder.append(v) }
		}
		for v in 0..<rules.count {
			if seen.insert(v).inserted {
				variableOrder.append(v);
			}
			for alt in rules[v] {
				for elem in alt {
					if let nt = elem.asNonterminal, seen.insert(nt).inserted {
						variableOrder.append(nt);
					}
				}
			}
		}

		func productionsFor(_ name: Variable) -> [Alternative] {
			(name < rules.count) ? rules[name] : []
		}

		func orderedReachable(_ name: Variable) -> [Variable] {
			var ordered: [Variable] = [];
			var visited: Set<Variable> = [];
			var queue: [Variable] = [name];
			var queued: Set<Variable> = [name];
			while let current = queue.first {
				queue.removeFirst();
				queued.remove(current);
				if visited.contains(current) { continue }
				visited.insert(current);
				ordered.append(current);
				for p in productionsFor(current) {
					if p.count == 1, let nt = p[0].asNonterminal {
						if !visited.contains(nt) && !queued.contains(nt) {
							queue.append(nt);
							queued.insert(nt);
						}
					}
				}
			}
			return ordered;
		}

		let maxVar = variableOrder.max() ?? -1
		var newRules: [Rule] = (maxVar >= 0) ? Array(repeating: [], count: maxVar + 1) : []
		for name in variableOrder {
			if name >= newRules.count {
				newRules.append(contentsOf: Array(repeating: [], count: name - newRules.count + 1))
			}
			let reachables = orderedReachable(name);
			var seenAlts = Set<Alternative>();
			var altsForThis: [Alternative] = [];
			for target in reachables {
				for prodBody in productionsFor(target) {
					if prodBody.count == 1, prodBody[0].asNonterminal != nil {
						continue
					}
					if seenAlts.insert(prodBody).inserted {
						altsForThis.append(prodBody)
					}
				}
			}
			newRules[name] = altsForThis
		}

		return Self(startSet: start, rules: newRules)
	}

	public func chomskyNormalForm() -> Self {
		fatalError()
	}

	public func greibachNormalForm() -> Self {
		fatalError()
	}

	public func mapVariableName<Target: Hashable>(_ transform: (Variable) -> Target) -> CFGNamed<Target, Alphabet> {
		CFGNamed<Target, Alphabet>(startSet: start.map(transform), productions: productions.map { $0.mapVariableName(transform) })
	}
}
