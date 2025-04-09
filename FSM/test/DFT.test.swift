@testable import FSM
import Testing

@Suite("DFT Tests") struct DFTTests {
	@Test("Empty DFT")
	func testEmptySet() async throws {
		let dft = DFT<Character, Character>(
			states: [[:]],
			initial: 0,
			finals: []
		)
		#expect(dft.map("") == nil)
		#expect(dft.map("1") == nil)
	}

	@Test("Epsilon DFT")
	func testEpsilon() async throws {
		let dft = DFT<Character, Character>(
			states: [[:]],
			initial: 0,
			finals: [0]
		)
		#expect(dft.map("") == [])
		#expect(dft.map("1") == nil)
	}

	@Test("Top (single) partition")
	func test_top() async throws {
		// This DFT always outputs epsilon
		let dft = DFT<Character, Character>(top: DFA<Character>(["", "0", "1", "2"]).star())
		#expect(dft.map("") == [])
		#expect(dft.map("1") == [])
		#expect(dft.map("x") == nil)
		#expect(dft.isEquivalent("00", "00") == true)
		#expect(dft.isEquivalent("00", "012") == true)
		#expect(dft.isEquivalent("00", "0123") == false) // outside set
		#expect(dft.isEquivalent("00", "x") == false) // outside set
	}

	@Test("Bottom (identity) partition")
	func test_bottom() async throws {
		// This DFT always outputs the input
		let dft = DFT<Character, Character>(bottom: DFA<Character>(["", "0", "1", "2"]).star())
		#expect(dft.map("") == [])
		#expect(dft.map("1") == ["1"])
		#expect(dft.map("x") == nil)
		#expect(dft.isEquivalent("00", "00") == true)
		#expect(dft.isEquivalent("00", "012") == false)
		#expect(dft.isEquivalent("00", "0123") == false) // outside set
		#expect(dft.isEquivalent("00", "x") == false) // outside set
	}

	@Test("contains")
	func test_contains() async throws {
		let dft = DFT<Character, Character>(top: DFA<Character>(["", "0", "1", "2"]).star())
		#expect(dft.contains("") == true)
		#expect(dft.contains("1") == true)
		#expect(dft.contains("x") == false)
	}
}
