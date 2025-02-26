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

	@Test("nextState for symbol")
	func test_nextState_symbol() {
		let dfa_string = DFA<String>(verbatim: "abc")
		#expect(dfa_string.nextState(state: 0, symbol: "a") == 1)
		#expect(dfa_string.nextState(state: 1, symbol: "b") == 2)

		let dfa_int = DFA<Array<Int>>(verbatim: [0, 1, 2])
		#expect(dfa_int.nextState(state: 0, symbol: 0) == 1)
		#expect(dfa_int.nextState(state: 1, symbol: 1) == 2)
		#expect(dfa_int.nextState(state: 2, symbol: 2) == 3)
		#expect(dfa_int.nextState(state: 3, symbol: 0) == nil)

		let dfa_bool = DFA<Array<Bool>>(verbatim: [true, false, true])
		#expect(dfa_bool.nextState(state: 0, symbol: true) == 1)
		#expect(dfa_bool.nextState(state: 1, symbol: false) == 2)
		#expect(dfa_bool.nextState(state: 2, symbol: true) == 3)
		#expect(dfa_bool.nextState(state: 3, symbol: false) == nil)
		#expect(dfa_bool.nextState(state: 3, symbol: true) == nil)
	}

	@Test("nextState for input string")
	func test_nextState_string() {
		let dfa_string = DFA<String>(verbatim: "abc")
		#expect(dfa_string.nextState(state: 0, input: "a") == 1)
		#expect(dfa_string.nextState(state: 0, input: "ab") == 2)
		#expect(dfa_string.nextState(state: 1, input: "bc") == 3)
		#expect(dfa_string.nextState(state: 1, input: "c") == nil)

		let dfa_int = DFA<Array<Int>>(verbatim: [0, 1, 2])
		#expect(dfa_int.nextState(state: 0, input: [0, 1]) == 2)
		#expect(dfa_int.nextState(state: 1, input: [1, 2]) == 3)
		#expect(dfa_int.nextState(state: 2, input: [2, 3]) == nil)
		#expect(dfa_int.nextState(state: 3, input: [0]) == nil)

		let dfa = DFA<Array<Bool>>(verbatim: [true, false, true])
		#expect(dfa.nextState(state: 0, input: [true, false]) == 2)
		#expect(dfa.nextState(state: 0, input: [true, false, true]) == 3)
		#expect(dfa.nextState(state: 0, input: [true, false, true, false]) == nil)
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

	@Test("repeating(Int)")
	func test_repeating_int() {
		let original = DFA<String>(["a", "b"])
		let repeated = original.repeating(2);
		#expect(!repeated.contains(""))
		#expect(!repeated.contains("a"))
		#expect(!repeated.contains("b"))
		#expect(repeated.contains("aa"))
		#expect(repeated.contains("ab"))
		#expect(repeated.contains("ba"))
		#expect(!repeated.contains("aaa"))
	}

	@Test("repeating(ClosedRange)")
	func test_repeating_closed() {
		let original = DFA<String>(["a", "b"])
		let repeated = original.repeating(2...3);
		#expect(!repeated.contains(""))
		#expect(!repeated.contains("a"))
		#expect(!repeated.contains("b"))
		#expect(repeated.contains("aa"))
		#expect(repeated.contains("ab"))
		#expect(repeated.contains("ba"))
		#expect(repeated.contains("aaa"))
		#expect(!repeated.contains("aaaa"))
	}

	@Test("repeating(PartialRangeFrom)")
	func test_repeating_lower() {
		let original = DFA<String>(["a", "b"])
		let repeated = original.repeating(2...);
		#expect(!repeated.contains(""))
		#expect(!repeated.contains("a"))
		#expect(!repeated.contains("b"))
		#expect(repeated.contains("aa"))
		#expect(repeated.contains("ab"))
		#expect(repeated.contains("ba"))
		#expect(repeated.contains("aaaaaa"))
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
