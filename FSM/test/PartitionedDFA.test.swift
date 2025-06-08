@testable import FSM
import Testing

@Suite("PartitionedDFA Tests") struct PartitionedDFATests {
	@Test("Empty DFAE")
	func testEmptyPartitionedSet() {
		let dfa = PartitionedDFA<Character>(partitions: [])
		#expect(dfa[ [] ] == nil)
		#expect(dfa[ ["0", "1"] ] == nil)
	}

	@Test("Filled DFAE")
	func testEmptyPartitionedMap() {
		var set = PartitionedDFA<Character>.Table<String>()
		let dfa0 = DFA<Character>(["0", "1"]).star()
		let dfa1 = DFA<Character>(["a", "b"]).star()
		set[ dfa0 ] = "digits"
		set[ dfa1 ] = "alphabet"
		#expect(set[ symbol: [] ] == "alphabet") // later assignment overrides earlier
		#expect(set[ symbol: ["0", "1"] ] == "digits")
		#expect(set[ symbol: ["a", "b"] ] == "alphabet")
		#expect(set[ symbol: ["a", "1"] ] == nil)
	}

	@Test("Filled DFAE")
	func testFilledPartitionedSet() {
		let parts = [
			DFA<Character>(["0", "1"]).star(),
			DFA<Character>(["a"]).plus(),
			DFA<Character>(["b"]).plus(),
		];
		let dfa = PartitionedDFA<Character>(partitions: parts)
		#expect(dfa[ [] ] == nil)
		#expect(dfa[ ["0", "1"] ] == nil)
		#expect(dfa[ ["a"] ] == nil)
		#expect(dfa[ ["b"] ] == nil)
		#expect(dfa[ ["a", "b"] ] == nil)
	}

	@Test("Filled DFAE")
	func testFilledPartitionedMap() {
		let parts = [
			"binary": DFA<Character>(["0", "1"]).star(),
			"alpha": DFA<Character>(["a"]).plus(),
			"bravo": DFA<Character>(["b"]).plus(),
		];
		let dfa = PartitionedDFA<Character>.Table<String>(uniqueKeysWithValues: parts.map { ($0.1, $0.0) })
		#expect(dfa[symbol: [] ] == "binary")
		#expect(dfa[symbol: ["0", "1"] ] == "binary")
		#expect(dfa[symbol: ["a"] ] == 	"alpha")
		#expect(dfa[symbol: ["b"] ] == "bravo")
		#expect(dfa[symbol: ["a", "b"] ] == nil)
	}
}
