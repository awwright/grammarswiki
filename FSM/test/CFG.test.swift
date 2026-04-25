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
			let cfg1 = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: []);
			let cfg2 = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: []);
			let cfg3 = CFG<ClosedRangeAlphabet<UInt8>>(start: "A", rules: []);
			#expect(cfg1 == cfg2)
			#expect(cfg1 != cfg3)
			// Test Hashable
			var set: Set<CFG<ClosedRangeAlphabet<UInt8>>> = [];
			set.insert(cfg1);
			set.insert(cfg2);
			#expect(set.count == 1)
		}
	}
}
