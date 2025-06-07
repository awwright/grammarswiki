@testable import FSM
import Testing

@Suite("DFAE Tests") struct DFAETests {
	@Test("Empty DFAE")
	func testEmptyDFAEString() {
		let map: Dictionary<String, DFA<Character>> = [:];
		let dfa = DFAE<Character, String>(partitions: map)
		#expect(dfa[""] == nil)
		#expect(dfa["01"] == nil)
	}

	@Test("Filled DFAE")
	func testFilledDFAEString() {
		let parts = [
			"binary": DFA<Character>(["0", "1"]).star(),
			"alpha": DFA<Character>(["a"]).plus(),
			"bravo": DFA<Character>(["b"]).plus(),
		];
		let dfa = DFAE<Character, String>(partitions: parts)
		#expect(dfa[""] == "binary")
		#expect(dfa["01"] == "binary")
		#expect(dfa["a"] == "alpha")
		#expect(dfa["b"] == "bravo")
		#expect(dfa["ab"] == nil)
	}
}
