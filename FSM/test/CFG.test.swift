import Testing
@testable import FSM

@Suite("CFG Tests") struct CFGTests {
	@Suite("Interface") struct CFGTests_init {
		@Test("empty")
		func test_init_empty() async throws {
			let cfg = CFG<ClosedRangeAlphabet<UInt8>>()
			#expect(cfg.start == "")
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
			#expect(cfg.start == "S")
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
}
