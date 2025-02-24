@testable import FSM
import Testing

@Suite("DFA Tests") struct DFATests {

	@Test("Empty DFA of Strings should not contain any input")
	func testEmptyDFAString() {
		let dfa = DFA<String>()
		#expect(!dfa.contains("a"))
		#expect(!dfa.contains(""))
	}

	@Test("Empty DFA of UInt8 Arrays should not contain any input")
	func testEmptyDFAUInt8() {
		let dfa = DFA<Array<UInt8>>()
		#expect(!dfa.contains([0]))
		#expect(!dfa.contains([]))
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
		let nfa = NFA<String>(
			states: [
				[:],
				[:],
				[ "x": [5] ],
				[ "y": [5] ],
				[ "z": [5] ],
				[:],
				[ "0": [0]], // Unreachable state just because
			],
			epsilon: [
				[2],
				[3],
				[],
				[4],
				[],
				[],
				[],
			],
			initials: [0, 1],
			finals: [3, 5, 6]
		);
		let dfa = DFA(nfa: nfa);
		#expect(dfa.contains(""))
		#expect(dfa.contains("x"))
		#expect(dfa.contains("y"))
		#expect(dfa.contains("z"))
		#expect(!dfa.contains("0"))
	}

	@Test("== operator")
	func testEqualsOperator() {
		let a = DFA(["abc", "def"]);
		let b = DFA(["def", "abc"]);
		#expect(a == b)
	}

	@Test("Alphabet generation")
	func testAlphabet() {
		let dfa = DFA<String>(verbatim: "abc")
		let expectedAlphabet: Set<Character> = ["a", "b", "c"]
		#expect(dfa.alphabet == expectedAlphabet)
	}


	@Test("Greedy match")
	func test_match() {
		let dfa = DFA<String>(["a", "ab", "xy"])
		#expect(dfa.match("zzz") == nil)
		#expect(dfa.match("") == nil)
		#expect(dfa.match("a")! == ("a", ""))
		#expect(dfa.match("ab")! == ("ab", ""))
		#expect(dfa.match("abc")! == ("ab", "c"))
		#expect(dfa.match("x") == nil)
		#expect(dfa.match("xy")! == ("xy", ""))
		#expect(dfa.match("xyz")! == ("xy", "z"))

		let dfa2 = DFA<String>(["", "abc"])
		#expect(dfa2.match("")! == ("", ""))
		#expect(dfa2.match("a")! == ("", "a"))
		#expect(dfa2.match("ab")! == ("", "ab"))
		#expect(dfa2.match("abc")! == ("abc", ""))
		#expect(dfa2.match("abcd")! == ("abc", "d"))
	}

	@Test("parallel")
	func test_parallel() {
		// See union, intersection, and symmetricDifference below
	}

	@Test("Union of DFAs")
	func testDFAUnion() {
		let dfa1 = DFA<String>(verbatim: "a")
		let dfa2 = DFA<String>(verbatim: "b")
		let unionDFA = dfa1.union(dfa2)
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

	@Test("concatenate")
	func test_concatenate() {
		let dfa1 = DFA<String>(["a", "b"])
		let dfa2 = DFA<String>(["x", "y"])
		let concatenation = dfa1.concatenate(dfa2);
		let language = Array(concatenation);
		#expect(language.count == 4)
		#expect(language.contains("ax"))
		#expect(language.contains("ay"))
		#expect(language.contains("bx"))
		#expect(language.contains("by"))
	}

	@Test("optional")
	func test_optional() {
		let dfa1 = DFA<String>(["a", "b"])
		let optional = dfa1.optional();
		#expect(optional.contains(""))
		#expect(optional.contains("a"))
		#expect(optional.contains("b"))
		let array = Array(optional);
		#expect(array.count == 3)
	}

	@Test("plus")
	func test_plus() {
		let dfa1 = DFA<String>(["a", "b"])
		let optional = dfa1.plus();
		#expect(!optional.contains(""))
		#expect(optional.contains("a"))
		#expect(optional.contains("b"))
		#expect(optional.contains("aa"))
		#expect(optional.contains("ab"))
		#expect(optional.contains("ba"))
	}

	@Test("star")
	func test_star() {
		let dfa1 = DFA<String>(["a", "b"])
		let optional = dfa1.star();
		#expect(optional.contains(""))
		#expect(optional.contains("a"))
		#expect(optional.contains("b"))
		#expect(optional.contains("aa"))
		#expect(optional.contains("ab"))
		#expect(optional.contains("ba"))
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

	@Test("IteratorProtocol conformance: Empty string")
	func testIteratorProtocol1() {
		let dfa = DFA<String>(verbatim: "")
		var values: [String] = []
		for string in dfa {
			values.append(string)
		}
		#expect(values == [""])
	}

	@Test("IteratorProtocol DepthFirst")
	func testIteratorProtocol2() {
		let dfa = DFA<String>(["bc", "a", "abcdefg", "ab", ""])
		var values: [String] = []
		for string in dfa {
			values.append(string)
		}
		#expect(values == ["", "a", "ab", "abcdefg", "bc"])
	}

	@Test("IteratorProtocol DepthFirst")
	func testIteratorProtocol3() {
		let dfa = DFA<String>(["bc", "a", "abcdefg", "ab", ""])
		var values: [String] = []
		for string in dfa {
			values.append(string)
		}
		#expect(values == ["", "a", "ab", "abcdefg", "bc"])
	}
}
