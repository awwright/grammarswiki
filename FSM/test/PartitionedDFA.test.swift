@testable import FSM
import Testing

@Suite("PartitionedDFA Tests") struct PartitionedDFATests {
	@Test("Empty PartitionedDFA")
	func testEmptyPartitionedSet() {
		let dfa = PartitionedDFA<Character>(partitions: [])
		#expect(dfa[ [] ] == nil)
		#expect(dfa[ ["0", "1"] ] == nil)
	}

	@Test("Filled PartitionedDFA")
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

	@Test("Filled PartitionedDFA")
	func testFilledPartitionedSet() {
		let parts = [
			DFA<Character>(["0", "1"]).star(),
			DFA<Character>(["a"]).plus(),
			DFA<Character>(["b"]).plus(),
		];
		let dfa = PartitionedDFA<Character>(partitions: parts)
		#expect(dfa[ [] ] == dfa[ ["0", "1"] ])
		#expect(dfa[ ["0"] ] == dfa[ ["0", "1"] ])
		#expect(dfa[ ["a"] ] == dfa[ ["a", "a"] ])
		#expect(dfa[ ["b"] ] == dfa[ ["b", "b"] ])
		#expect(dfa[ ["a", "b"] ] == nil)
	}

	@Test("Filled PartitionedDFA")
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

	@Test("conjunction")
	func test_PartitionedDFA_conjunction() {
		let part_2 = DFA<Character>(["0", "1"]).star();
		let part_4 = DFA<Character>(["0", "1", "2", "3"]).star();
		let part_6 = DFA<Character>(["0", "1", "2", "3", "4", "5"]).star();
		let part_8 = DFA<Character>(["0", "1", "2", "3", "4", "5", "6", "7"]).star();
		let dfa0: PartitionedDFA<Character> = [ part_2, part_6 ];
		let dfa1: PartitionedDFA<Character> = [ part_4, part_8 ];
		// Test that the partitions are mutually exclusive
		#expect(dfa0.siblings(of: Array("01")) == part_2)
		#expect(dfa0.siblings(of: Array("012345")) == part_6.subtracting(part_2))
		#expect(dfa1.siblings(of: Array("01")) == part_4)
		#expect(dfa1.siblings(of: Array("012345")) == part_8.subtracting(part_4))
		let pdfa = dfa0.conjunction(dfa1);
		// Test that the partitions are mutually exclusive
		#expect(pdfa.siblings(of: Array("01")) == part_2)
		#expect(pdfa.siblings(of: Array("0123")) == part_4.subtracting(part_2))
		//for part in pdfa { print(part.minimized().toViz()) }
	}
}
