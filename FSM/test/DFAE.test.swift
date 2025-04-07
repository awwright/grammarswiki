@testable import FSM
import Testing

@Suite("DFAE Tests") struct DFAETests {
	@Test("Empty DFAE")
	func testEmptyDFAEString() {
		let map: Dictionary<String, DFA<String>> = [:];
		let dfa = DFAE<String, String>(partitions: map)
		#expect(dfa[""] == nil)
		#expect(dfa["01"] == nil)
	}

	@Test("Filled DFAE")
	func testFilledDFAEString() {
		let parts = [
			"binary": DFA<String>(["0", "1"]).star(),
			"alpha": DFA<String>(["a"]).plus(),
			"bravo": DFA<String>(["b"]).plus(),
		];
		let dfa = DFAE<String, String>(partitions: parts)
		#expect(dfa[""] == "binary")
		#expect(dfa["01"] == "binary")
		#expect(dfa["a"] == "alpha")
		#expect(dfa["b"] == "bravo")
		#expect(dfa["ab"] == nil)
	}
}
