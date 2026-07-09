import Testing
@testable import FSM

@Suite("CFG Tests") struct CFGTests {
	static var empty: CFG<SymbolAlphabet<UInt8>> = .init();
	static var epsilon: CFG<SymbolAlphabet<UInt8>> = .init(start: "S", productions: [
		.init(name: "S", body: []),
	]);
	static var character: CFG<SymbolAlphabet<UInt8>> = .init(start: "S", productions: [
		.init(name: "S", body: [.terminal(1)]),
	]);
	static var parens: CFG<SymbolAlphabet<UInt8>> = [
		"S": [ [], [.nonterminal("S"), .nonterminal("S")], [.terminal(0x5B), .nonterminal("S"), .terminal(0x5D)] ],
	];
	static var lwsp: CFG<SymbolAlphabet<UInt8>> = [
		.init(name: "LWSP", body: []),
		.init(name: "LWSP", body: [.nonterminal("element"), .nonterminal("LWSP")]),
		.init(name: "element", body: [.nonterminal("WSP")]),
		.init(name: "element", body: [.nonterminal("CRLF"), .nonterminal("WSP")]),
		.init(name: "CRLF", body: [.nonterminal("CR"), .nonterminal("LF")]),
		.init(name: "WSP", body: [.nonterminal("SP")]),
		.init(name: "WSP", body: [.nonterminal("HTAB")]),
		.init(name: "HTAB", body: [.terminal(0x09)]),
		.init(name: "CR", body: [.terminal(0x0D)]),
		.init(name: "LF", body: [.terminal(0x0A)]),
		.init(name: "SP", body: [.terminal(0x20)]),
	];
	static var positveNumber: CFG<SymbolAlphabet<UInt8>> = [
		"S": [ [.nonterminal("1"), .nonterminal("N")] ],
		"1": [ [.terminal(0x31)], [.terminal(0x32)], [.terminal(0x33)], [.terminal(0x34)], [.terminal(0x35)], [.terminal(0x36)], [.terminal(0x37)], [.terminal(0x38)], [.terminal(0x39)] ],
		"N": [ [], [ .nonterminal("0"), .nonterminal("N") ] ],
		"0": [ [.terminal(0x30)], [.terminal(0x31)], [.terminal(0x32)], [.terminal(0x33)], [.terminal(0x34)], [.terminal(0x35)], [.terminal(0x36)], [.terminal(0x37)], [.terminal(0x38)], [.terminal(0x39)] ],
	];

	@Suite("Interface") struct CFGTests_init {
		@Test("empty")
		func test_init_empty() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>()
			#expect(cfg.start == [])
			#expect(cfg.productions.isEmpty)
			#expect(cfg.dictionary.isEmpty)
		}

		@Test("initializer")
		func test_init() async throws {
			let productions: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", body: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x61...0x7A))]),
				.init(name: "A", body: [.nonterminal("S")])
			];
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: productions);
			#expect(cfg.start == ["S"])
			#expect(cfg.productions.count == 2)
			#expect(cfg.dictionary.keys.sorted() == ["A", "S"])
		}

		@Test("Equatable")
		func test_equatable() async throws {
			let cfg1 = CFG<ClosedRangeAlphabet<UInt8>>();
			let cfg2 = CFG<ClosedRangeAlphabet<UInt8>>(start: "A", productions: [ .init(name: "A", body: []) ]);
			let cfg3 = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: [ .init(name: "S", body: []) ]);
			let cfg4 = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: [ .init(name: "S", body: []) ]);
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
			let productions: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", body: [.nonterminal("A")]),
				.init(name: "A", body: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x41...0x5A))]),
				.init(name: "S", body: [.nonterminal("B")])
			]
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: productions)
			let dict = cfg.dictionary
			#expect(dict["S"]?.count == 2)
			#expect(dict["A"]?.count == 1)
			#expect(dict["B"] == nil)
		}

		@Test("ruleNames")
		func test_ruleNames() async throws {
			let productions: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", body: [.nonterminal("A")]),
				.init(name: "A", body: [.nonterminal("B")]),
				.init(name: "B", body: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x41...0x5A))])
			]
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: productions)
			let names = cfg.ruleNames
			#expect(names == ["S", "A", "B"])
		}

		@Test("ruleNames with multiple rules per name")
		func test_ruleNames_alternates() async throws {
			let productions: [CFG<ClosedRangeAlphabet<UInt8>>.Production] = [
				.init(name: "S", body: [.nonterminal("A")]),
				.init(name: "S", body: [.nonterminal("B")]),
				.init(name: "A", body: []),
				.init(name: "B", body: [])
			]
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: productions)
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
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "ep", productions: [
				.init(name: "ep", body: []),
			])
			#expect(cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(!cfg.contains([1]))
		}

		@Test("single space")
		func test_sp() async throws {
			let cfg: ABNFRulelist<UInt8>.CFG = try! ABNFRulelist.builtins.toCFG(rulename: "sp")
			#expect(!cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(cfg.contains([0x20]))
		}

		@Test("single space 2")
		func test_sp2() async throws {
			let cfg: CFG<SymbolAlphabet<UInt8>> = .init(start: "S", productions: [
				.init(name: "S", body: [.nonterminal("X"), .nonterminal("X"), .terminal(0x20)]),
				.init(name: "X", body: []),
			]);
			#expect(!cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(cfg.contains([0x20]))
			#expect(!cfg.contains([0x20, 0x20]))
		}

		@Test("left-recursive space")
		func test_sp3() async throws {
			let cfg: CFG<SymbolAlphabet<UInt8>> = .init(start: "S", productions: [
				.init(name: "S", body: [.nonterminal("S"), .terminal(0x20)]),
				.init(name: "S", body: []),
			]);
			#expect(cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(cfg.contains([0x20]))
			#expect(cfg.contains([0x20, 0x20]))
			#expect(!cfg.contains([0x20, 0]))
			#expect(cfg.contains([0x20, 0x20, 0x20, 0x20, 0x20, 0x20]))
		}

		@Test("right-recursive space")
		func test_sp4() async throws {
			let cfg: CFG<SymbolAlphabet<UInt8>> = .init(start: "S", productions: [
				.init(name: "S", body: [.terminal(0x20), .nonterminal("S")]),
				.init(name: "S", body: []),
			]);
			#expect(cfg.contains([]))
			#expect(!cfg.contains([0]))
			#expect(cfg.contains([0x20]))
			#expect(cfg.contains([0x20, 0x20]))
			#expect(!cfg.contains([0x20, 0]))
			#expect(cfg.contains([0x20, 0x20, 0x20, 0x20, 0x20, 0x20]))
		}

		@Test("LWSP")
		func test_lwsp() async throws {
			let cfg: ABNFRulelist<UInt8>.CFG = try! ABNFRulelist.builtins.toCFG(rulename: "lwsp")
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

		@Test("star / repetition with epsilon")
		func test_star_epsilon() async throws {
			// Equivalent to a simple "a*" grammar as emitted by ABNFRulelist.toCFG
			let cfg = CFG<SymbolAlphabet<UInt8>>(start: "S", productions: [
				.init(name: "S", body: [.nonterminal("star")]),
				.init(name: "star", body: []), // epsilon
				.init(name: "star", body: [.nonterminal("A"), .nonterminal("star")]),
				.init(name: "A", body: [.terminal(0x61)]), // "a"
			])

			#expect(cfg.contains([]))
			#expect(cfg.contains([0x61]))
			#expect(cfg.contains([0x61, 0x61]))
			#expect(cfg.contains([0x61, 0x61, 0x61]))
			#expect(!cfg.contains([0x62]))
			#expect(!cfg.contains([0x61, 0x62]))
		}
	}

	@Suite("reversed") struct CFGTests_reversed {
		@Test("empty language")
		func test_empty() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>().reversed();
			#expect(cfg.maxCardinality() == 0)
			#expect(!cfg.contains([]));
		}

		@Test("balanced parens language")
		func test_parens() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>().reversed();
			#expect(cfg.maxCardinality() == 0)
			// Turns out it's mostly the same
			#expect(!cfg.contains([]));
		}

		@Test("balanced parens language")
		func test_number() async throws {
			let cfg: CFG<SymbolAlphabet<UInt8>> = .init(start: "S", productions: [
				.init(name: "S", body: [.terminal(0x31), .terminal(0x32), .terminal(0x33)]),
				.init(name: "S", body: [.terminal(0x32), .terminal(0x33), .terminal(0x34)]),
			]).reversed();
			#expect(cfg.maxCardinality() == 2)
			#expect(cfg.contains([0x33, 0x32, 0x31]));
			#expect(cfg.contains([0x34, 0x33, 0x32]));
			#expect(!cfg.contains([0x31, 0x32, 0x33]));
			#expect(!cfg.contains([0x32, 0x33, 0x34]));
		}
	}

	@Suite("eliminateUnitProduction") struct CFGTests_eliminateUnitProduction {
		@Test func basicUnitChain() throws {
			let g: CFG<SymbolAlphabet<Character>> = [
				"S": [[.nonterminal("A")]],
				"A": [[.terminal("x")], [.nonterminal("B")]],
				"B": [[.terminal("y")]],
			];
			let cleaned = g.eliminateUnitProduction();
			#expect(cleaned.productions[0] == .init(name: "S", body: [.terminal("x")]))
			#expect(cleaned.productions[1] == .init(name: "S", body: [.terminal("y")]))
			#expect(cleaned.productions[2] == .init(name: "A", body: [.terminal("x")]))
			#expect(cleaned.productions[3] == .init(name: "A", body: [.terminal("y")]))
			#expect(cleaned.productions[4] == .init(name: "B", body: [.terminal("y")]))
			// No units remain
			#expect(cleaned.productions.count == 5)
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
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: [
				.init(name: "S", body: []),
				.init(name: "S", body: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x41...0x5A))]),
			]);
			#expect(cfg.maxCardinality() == 27) // 26 lowercase letters and epsilon
			#expect(cfg.chomskyClass() == 4)
		}

		@Test("non-productive grammar", .disabled("not implemented"))
		func test_nonproductive() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: [
				.init(name: "S", body: [.nonterminal("A"), .nonterminal("B")]),
				.init(name: "A", body: [.nonterminal("B")]),
				.init(name: "B", body: [.nonterminal("A")]),
			]);
			#expect(cfg.chomskyClass() == 4)
		}

		@Test("self-referential start symbol")
		func test_strings() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: [
				.init(name: "S", body: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x61...0x7A))]),
				.init(name: "S", body: [.terminal(ClosedRangeAlphabet.symbolClass(range: 0x30...0x39)), .nonterminal("S")]),
			]);
			// FIXME: Maybe it's possible to detect non-productive unit productions and count those as zero... but currently it doesn't
			//#expect(cfg.maxCardinality() == 0)
			#expect(cfg.chomskyClass() == 2);
		}

		@Test("linear whitespace")
		func test_lwsp() async throws {
			let cfg = CFGTests.lwsp;
			#expect(cfg.maxCardinality() == nil)
			#expect(cfg.chomskyClass() == 2);
		}

		@Test("balanced parenthesies")
		func test_parens() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", productions: [
				.init(name: "S", body: []),
				.init(name: "S", body: [.nonterminal("S"), .nonterminal("S")]),
				.init(name: "S", body: [.terminal([0x5B...0x5B]), .nonterminal("S"), .terminal([0x5D...0x5D])]),
			]);
			#expect(cfg.chomskyClass() == 2)
		}

		@Test("positive number")
		func test_number() async throws {
			let cfg = CFGTests.positveNumber;
			#expect(!cfg.contains(Array("".utf8)))
			#expect(!cfg.contains(Array("0".utf8)))
			#expect(cfg.contains(Array("1".utf8)))
			#expect(cfg.contains(Array("12".utf8)))
			#expect(cfg.contains(Array("123".utf8)))
		}
	}
}
