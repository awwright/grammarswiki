import Testing
@testable import FSM

@Suite("CFG Tests") struct CFGTests {
	@Suite("Interface") struct CFGTests_init {
		@Test("empty")
		func test_init_empty() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>()
			#expect(cfg.start == [])
			#expect(cfg.rules.isEmpty)
			#expect(cfg.dictionary.isEmpty)
		}

		@Test("initializer")
		func test_init() async throws {
			let rules: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", production: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x61...0x7A))]),
				.init(name: "A", production: [.nonterminal("S")])
			];
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: rules);
			#expect(cfg.start == ["S"])
			#expect(cfg.rules.count == 2)
			#expect(cfg.dictionary.keys.sorted() == ["A", "S"])
		}

		@Test("Equatable")
		func test_equatable() async throws {
			let cfg1 = CFG<ClosedRangeAlphabet<UInt8>>();
			let cfg2 = CFG<ClosedRangeAlphabet<UInt8>>(start: "A", rules: [ .init(name: "A", production: []) ]);
			let cfg3 = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: [ .init(name: "S", production: []) ]);
			let cfg4 = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: [ .init(name: "S", production: []) ]);
			#expect(cfg1 != cfg2)
			#expect(cfg2 != cfg3)
			#expect(cfg3 == cfg4)
			// Test Hashable
			var set: Set<CFG<ClosedRangeAlphabet<UInt8>>> = [];
			set.insert(cfg1);
			set.insert(cfg2);
			set.insert(cfg3);
			set.insert(cfg4);
			// Since 3 and 4 are the same, 4 won't change the set
			#expect(set.count == 3)
		}
	}

	@Suite("dictionary and ruleNames") struct CFGTests_dictionary {
		@Test("dictionary groups by name")
		func test_dictionary() async throws {
			let rules: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", production: [.nonterminal("A")]),
				.init(name: "A", production: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x41...0x5A))]),
				.init(name: "S", production: [.nonterminal("B")])
			]
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: rules)
			let dict = cfg.dictionary
			#expect(dict["S"]?.count == 2)
			#expect(dict["A"]?.count == 1)
			#expect(dict["B"] == nil)
		}

		@Test("ruleNames")
		func test_ruleNames() async throws {
			let rules: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", production: [.nonterminal("A")]),
				.init(name: "A", production: [.nonterminal("B")]),
				.init(name: "B", production: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x41...0x5A))])
			]
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: rules)
			let names = cfg.ruleNames
			#expect(names == ["S", "A", "B"])
		}

		@Test("ruleNames with multiple rules per name")
		func test_ruleNames_alternates() async throws {
			let rules: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", production: [.nonterminal("A")]),
				.init(name: "S", production: [.nonterminal("B")]),
				.init(name: "A", production: []),
				.init(name: "B", production: [])
			]
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: rules)
			let names = cfg.ruleNames
			#expect(names == ["S", "A", "B"])
		}
	}

	@Suite("contains") struct CFGTests_contains {
		@Test("empty language")
		func test_empty() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>()
			#expect(!cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(!cfg.contains([1]))
		}

		@Test("epsilon language")
		func test_epsilon() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "ep", rules: [
				.init(name: "ep", production: []),
			])
			#expect(cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(!cfg.contains([1]))
		}

		@Test("single space")
		func test_sp() async throws {
			let cfg: CFG<ClosedRangeAlphabet<UInt8>> = try! ABNFRulelist.builtins.toCFG(rulename: "sp")
			#expect(!cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(cfg.contains([0x20]))
		}

		@Test("LWSP")
		func test_lwsp() async throws {
			let cfg: CFG<ClosedRangeAlphabet<UInt8>> = try! ABNFRulelist.builtins.toCFG(rulename: "lwsp")
			// TODO: Only up to one character of recognition is implemented
			#expect(cfg.contains([]));
			#expect(!cfg.contains([0]));
			#expect(cfg.contains([0x09]));
			#expect(cfg.contains([0x20]));
			#expect(cfg.contains([0x09, 0x09, 0x09]));
			#expect(cfg.contains([0x20, 0x20, 0x20]));
			#expect(!cfg.contains([0x20, 0x0D]));
			#expect(!cfg.contains([0x20, 0x0A]));
			#expect(!cfg.contains([0x20, 0x0D, 0x0A]));
			#expect(!cfg.contains([0x20, 0x0D, 0x09]));
			#expect(!cfg.contains([0x20, 0x0A, 0x09]));
			#expect(cfg.contains([0x20, 0x0D, 0x0A, 0x09]));
		}
	}

	@Suite("chomskyClass") struct CFGTests_chomskyClass {
		@Test("empty language -> finite")
		func test_empty() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>()
			#expect(cfg.maxCardinality() == 0)
			#expect(cfg.chomskyClass() == 4)
		}

		@Test("set of empty string -> finite")
		func test_epsilon_finite() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: [
				.init(name: "S", production: []),
				.init(name: "S", production: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x41...0x5A))]),
			]);
			#expect(cfg.maxCardinality() == 27) // 26 lowercase letters and epsilon
			#expect(cfg.chomskyClass() == 4)
		}

		@Test("non-productive grammar", .disabled("not implemented"))
		func test_nonproductive() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: [
				.init(name: "S", production: [.nonterminal("A"), .nonterminal("B")]),
				.init(name: "A", production: [.nonterminal("B")]),
				.init(name: "B", production: [.nonterminal("A")]),
			]);
			#expect(cfg.chomskyClass() == 4)
		}

		@Test("self-referential start symbol")
		func test_strings() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: [
				.init(name: "S", production: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x61...0x7A))]),
				.init(name: "S", production: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x30...0x39)), .nonterminal("S")]),
			]);
			// FIXME: Maybe it's possible to detect non-productive unit productions and count those as zero... but currently it doesn't
			//#expect(cfg.maxCardinality() == 0)
			#expect(cfg.chomskyClass() == 2);
		}

		@Test("linear whitespace")
		func test_lwsp() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "LWSP", rules: [
				.init(name: "LWSP", production: []),
				.init(name: "LWSP", production: [.nonterminal("element"), .nonterminal("LWSP")]),
				.init(name: "element", production: [.nonterminal("WSP")]),
				.init(name: "element", production: [.nonterminal("CRLF"), .nonterminal("WSP")]),
				.init(name: "CRLF", production: [.nonterminal("CR"), .nonterminal("LF")]),
				.init(name: "WSP", production: [.nonterminal("SP")]),
				.init(name: "WSP", production: [.nonterminal("HTAB")]),
				.init(name: "HTAB", production: [.terminal([0x09...0x09])]),
				.init(name: "CR", production: [.terminal([0x0D...0x0D])]),
				.init(name: "LF", production: [.terminal([0x0A...0x0A])]),
				.init(name: "SP", production: [.terminal([0x20...0x20])]),
			]);
			#expect(cfg.maxCardinality() == nil)
			#expect(cfg.chomskyClass() == 2);
		}

		@Test("balanced parenthesies")
		func test_parens() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: [
				.init(name: "S", production: []),
				.init(name: "S", production: [.nonterminal("S"), .nonterminal("S")]),
				.init(name: "S", production: [.terminal([0x5B...0x5B]), .nonterminal("S"), .terminal([0x5D...0x5D])]),
			]);
			#expect(cfg.chomskyClass() == 2)
		}
	}
}
