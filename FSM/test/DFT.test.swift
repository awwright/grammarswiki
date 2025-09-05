@testable import FSM
import Testing

@Suite("DFT Tests") struct DFTTests {
	@Test("Empty DFT")
	func testEmptySet() async throws {
		let dft = DFT<Character>(
			states: [[:]],
			initial: 0,
			finals: [:]
		)
		#expect(dft.map("") == nil)
		#expect(dft.map("1") == nil)
	}

	@Test("Epsilon DFT")
	func testEpsilon() async throws {
		let dft = DFT<Character>(
			states: [[:]],
			initial: 0,
			finals: [0: []]
		)
		#expect(dft.map("") == [])
		#expect(dft.map("1") == nil)
	}

	@Test("Top (single) partition")
	func test_top() async throws {
		// This DFT always outputs epsilon
		let dft = DFT<Character>(top: SymbolDFA<Character>(["", "0", "1", "2"]).star())
		#expect(dft.map("") == [])
		#expect(dft.map("1") == [])
		#expect(dft.map("x") == nil)
		#expect(dft.isEquivalent("00", "00") == true)
		#expect(dft.isEquivalent("00", "012") == true)
	}

	@Test("Bottom (identity) partition")
	func test_bottom() async throws {
		// This DFT always outputs the input
		let dft = DFT<Character>(bottom: SymbolDFA<Character>(["", "0", "1", "2"]).star())
		#expect(dft.map("") == [])
		#expect(dft.map("1") == ["1"])
		#expect(dft.map("x") == nil)
		#expect(dft.isEquivalent("00", "00") == true)
		#expect(dft.isEquivalent("00", "012") == false)
	}

	@Test("contains")
	func test_contains() async throws {
		let dft = DFT<Character>(top: SymbolDFA<Character>(["", "0", "1", "2"]).star())
		#expect(dft.contains("") == true)
		#expect(dft.contains("1") == true)
		#expect(dft.contains("x") == false)
	}

	@Test("optional")
	func test_optional() {
		let dfa1 = DFT(top: SymbolDFA<Character>(["a", "b"]))
		#expect(!dfa1.contains(""))
		let optional = dfa1.optional();
		#expect(optional.contains(""))
		#expect(optional.contains("a"))
		#expect(optional.contains("b"))
		#expect(!optional.contains("ab"))
		//let array = Array(optional);
		//#expect(array.count == 3)
	}
}
