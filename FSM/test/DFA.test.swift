@testable import FSM
import Testing

@Suite("DFA Tests") struct DFATests {

	@Test("Empty DFA should not contain any input")
	func testEmptyDFA() {
		let dfa = DFA<String>()
		#expect(!dfa.contains("a"))
		#expect(!dfa.contains(""))
	}

	@Test("DFA from verbatim should recognize the input")
	func testDFAFromVerbatim() {
		let dfa = DFA<String>(verbatim: "abc")
		#expect(dfa.contains("abc"))
		#expect(!dfa.contains("ab"))
		#expect(!dfa.contains("abcd"))
	}

	@Test("Character range")
	func test_from_ClosedRange() {
		let dfa = DFA<String>(range: "a"..."f")
		#expect(!dfa.contains(""))
		#expect(dfa.contains("a"))
		#expect(dfa.contains("f"))
		#expect(!dfa.contains("g"))
		#expect(!dfa.contains("aa"))
	}

	@Test("Import from NFA")
	func testDFAFromNFA() {
		let nfa = NFA<String>(["a", "abc", "abcde", "123456"])
//		print(nfa.toViz());
		let dfa = DFA(nfa: nfa)
//		print(dfa.toViz());
		#expect(dfa.contains("abc"))
		#expect(!dfa.contains("ab"))
		#expect(!dfa.contains("abcd"))
	}

	@Test("Greedy match")
	func test_match() {
		let dfa = DFA<String>(["a", "aa", "bb"])
		#expect(dfa.match("xxx") == nil)
		#expect(dfa.match("") == nil)
		#expect(dfa.match("a") == 0)
		#expect(dfa.match("aa") == 1)
		#expect(dfa.match("aaa") == 1)
		#expect(dfa.match("b") == nil)
		#expect(dfa.match("bb") == 1)
		#expect(dfa.match("bbb") == 1)
	}

	@Test("Union of DFAs")
	func testDFAUnion() {
		let dfa1 = DFA<String>(verbatim: "a")
		let dfa2 = DFA<String>(verbatim: "b")
		let unionDFA = dfa1.union(dfa2)
		// print(unionDFA.toViz())

		#expect(unionDFA.contains("a"))
		#expect(unionDFA.contains("b"))
		#expect(!unionDFA.contains("ab"))
	}

	@Test("Intersection of DFAs")
	func testDFAIntersection() {
		let dfa1 = DFA<String>(["a", "b"])
		let dfa2 = DFA<String>(["b", "c"])
		let intersectionDFA = dfa1.intersection(dfa2)

		#expect(!intersectionDFA.contains("a"))
		#expect(intersectionDFA.contains("b"))
		#expect(!intersectionDFA.contains("c"))
		#expect(!intersectionDFA.contains("ab"))
	}

	@Test("Symmetric Difference of DFAs")
	func testDFASymmetricDifference() {
		let dfa1 = DFA<String>(["a", "b", "ab"])
		let dfa2 = DFA<String>(verbatim: "ab")
		let symDiffDFA = dfa1.symmetricDifference(dfa2)

		#expect(symDiffDFA.contains("a"))
		#expect(symDiffDFA.contains("b"))
		#expect(!symDiffDFA.contains("ab"))
	}

	@Test("Insert and remove operations")
	func testInsertRemove() {
		var dfa = DFA<String>()
		let (inserted, _) = dfa.insert("test")
		#expect(inserted)
		#expect(dfa.contains("test"))

		let removed = dfa.remove("test")
		#expect(removed != nil)
		#expect(!dfa.contains("test"))
	}

	@Test("Alphabet generation")
	func testAlphabet() {
		let dfa = DFA<String>(verbatim: "abc")
		let expectedAlphabet: Set<Character> = ["a", "b", "c"]
		#expect(dfa.alphabet == expectedAlphabet)
	}

	@Test("Next state for single symbol")
	func testNextStateSingleSymbol() {
		let dfa = DFA<String>(verbatim: "abc")
		#expect(dfa.nextState(state: 0, symbol: "a") == 1)
		#expect(dfa.nextState(state: 1, symbol: "b") == 2)
	}

	@Test("Next state for input string")
	func testNextStateStringInput() {
		let dfa = DFA<String>(verbatim: "abc")
		#expect(dfa.nextState(state: 0, input: "ab") == 2)
		#expect(dfa.nextState(state: 0, input: "abc") == 3)
		#expect(dfa.nextState(state: 0, input: "abcd") == nil)
	}

	@Test("ToViz should produce graphviz string")
	func testToViz() {
		let dfa = DFA<String>(verbatim: "a")
		let viz = dfa.toViz()
		#expect(viz.contains("digraph G {"))
		#expect(viz.contains("_initial -> 0"))
		#expect(viz.contains("shape=\"doublecircle\""))
	}

	@Test("IteratorProtocol conformance: Empty string")
	func testIteratorProtocol1() {
		let dfa = DFA<String>(verbatim: "")
		var values: [String] = []
		for string in dfa {
			print("string");
			print(string);
			values.append(string)
		}
		#expect(values == [""])
	}

	@Test("IteratorProtocol DepthFirst")
	func testIteratorProtocol2() {
		let dfa = DFA<String>(["bc", "a", "abcdefg", "ab", ""])
//		print(dfa.toViz());
		var values: [String] = []
		for string in dfa {
			values.append(string)
		}
		#expect(values == ["", "a", "ab", "abcdefg", "bc"])
	}

	@Test("IteratorProtocol DepthFirst")
	func testIteratorProtocol3() {
		let dfa = DFA<String>(["bc", "a", "abcdefg", "ab", ""])
//		print(dfa.toViz());
		var values: [String] = []
		for string in dfa {
			values.append(string)
		}
		#expect(values == ["", "a", "ab", "abcdefg", "bc"])
	}
}
