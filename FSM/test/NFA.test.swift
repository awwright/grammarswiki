import Testing
@testable import FSM

@Suite("NFA Tests") struct NFATests {
	@Test("Initialization") func Initialization() {
		let nfa = NFA<Character>()
		#expect(nfa.statesSet.count == 1)
		#expect(nfa.epsilon.count == 1)
		#expect(nfa.initials == [0])
		#expect(nfa.finals.isEmpty)
	}

	@Test("Initialization with specific states") func Initialization2() {
		//	let transitions = [
		//		["a": Set([1])],
		//		["b": Set([0])],
		//	];
		//	let nfa = NFA<Character>(states: transitions, epsilon: [[], []], initials: [0], finals: [1])
		//	#expect(nfa.states.count == 2)
		//	#expect(nfa.epsilon.count == 2)
		//	#expect(nfa.initials == [0])
		//	#expect(nfa.finals == [1])
	}

	@Test("Initialization with verbatim input") func Initialization3() {
		let nfa = NFA(verbatim: "abc")
		#expect(nfa.statesSet.count == 4) // 'a', 'b', 'c', and end state
		#expect(nfa.initials == [0])
		#expect(nfa.finals == [3])
		#expect(nfa.nextStates(states: [0], symbol: "a") == [1])
		#expect(nfa.nextStates(states: [1], symbol: "b") == [2])
		#expect(nfa.nextStates(states: [2], symbol: "c") == [3])
	}

	@Test("Contains for valid input") func Initialization4() {
		let nfa = NFA<Character>(verbatim: "abc")
		#expect(nfa.contains("abc"))
		#expect(!nfa.contains("ab"))
	}

	@Test("Follow epsilon function")
	func test_followε() {
		let nfa = NFA<Character>(
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
		#expect(nfa.followε(states: [0]) == [0, 2]);
		#expect(nfa.followε(states: [1]) == [1, 3, 4]);
		#expect(nfa.followε(states: [2]) == [2]);
		#expect(nfa.followε(states: [3]) == [3, 4]);
		#expect(nfa.followε(states: [4]) == [4]);
		#expect(nfa.followε(states: [5]) == [5]);
		#expect(nfa.followε(states: [6]) == [6]);
		#expect(nfa.followε(states: [0, 1]) == [0, 1, 2, 3, 4]);
	}

	@Test("Next States Calculation") func Initialization5() {
		let nfa = NFA<Character>(states: [["a": [1]], ["b": [0]]], epsilon: [[], []], initial: 0, finals: [1])
		#expect(nfa.nextStates(states: [0], symbol: "a") == [1])
		#expect(nfa.nextStates(states: [1], symbol: "b") == [0])
		#expect(nfa.nextStates(states: [0], string: "ab") == [0])
	}

	@Test("Derive Function") func Initialization6() {
		let nfa = NFA(verbatim: "abc")
		let derived = nfa.derive("ab")
		#expect(derived.initials == [2]) // After consuming 'ab', we're at state 2
		#expect(derived.contains("c"))
		#expect(!derived.contains("b"))
	}

	@Test("Union of NFAs") func Initialization7() {
		let nfa1 = NFA(verbatim: "abc")
		let nfa2 = NFA(verbatim: "def")
		let unionNFA = nfa1.union(nfa2)
		#expect(unionNFA.contains("abc") && unionNFA.contains("def"))
	}

	@Test("Intersection of NFAs") func Initialization8() {
		let nfa1 = NFA(verbatim: "abc")
		let nfa2 = NFA(verbatim: "abc")
		let intersectNFA = nfa1.intersection(nfa2)
		#expect(intersectNFA.contains("abc"))

		let nfa3 = NFA(verbatim: "def")
		let noIntersect = nfa1.intersection(nfa3)
		#expect(!noIntersect.contains("abc") && !noIntersect.contains("def"))
	}

	@Test("Symmetric Difference") func Initialization9() {
		let nfa1 = NFA(["aaa", "bbb"])
		let nfa2 = NFA(["bbb", "ddd"])
		let symDiff = nfa1.symmetricDifference(nfa2)
		#expect(symDiff.contains("aaa"))
		#expect(!symDiff.contains("bbb"))
		#expect(symDiff.contains("ddd"))
	}

	@Test("concatenate")
	func test_concatenate() {
		let epsilon = NFA<Character>.concatenate([])
		#expect(epsilon.contains(""))

		let dfa1 = NFA<Character>(["a", "b"])
		let single = NFA.concatenate([dfa1]);
		#expect(single.contains("a"))

		let dfa2 = NFA<Character>(["x", "y"])
		let concatenation = dfa1.concatenate(dfa2);
		let language = Array(DFA(nfa: concatenation).map { String($0) });
		#expect(language.count == 4)
		#expect(language.contains("ax"))
		#expect(language.contains("ay"))
		#expect(language.contains("bx"))
		#expect(language.contains("by"))

		let triple = NFA.concatenate([dfa1, dfa1, dfa1]);
		#expect(triple.contains("aba"))

		let range = NFA.concatenate([dfa1.optional(), dfa1, dfa1.optional()]);
		#expect(range.contains("a"))
		#expect(range.contains("ab"))
		#expect(range.contains("aba"))
	}

	@Test("optional")
	func test_optional() {
		let dfa1 = NFA<Character>(["a", "b"])
		let optional = dfa1.optional();
		#expect(optional.contains(""))
		#expect(optional.contains("a"))
		#expect(optional.contains("b"))
//		let array = Array(optional);
//		#expect(array.count == 3)
	}

	@Test("plus")
	func test_plus() {
		let dfa1 = NFA<Character>(["a", "b"])
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
		let dfa1 = NFA<Character>(["a", "b"])
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
		let original = NFA<Character>(["a", "b"])
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
		let original = NFA<Character>(["a", "b"])
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
		let original = NFA<Character>(["a", "b"])
		let repeated = original.repeating(2...);
		#expect(!repeated.contains(""))
		#expect(!repeated.contains("a"))
		#expect(!repeated.contains("b"))
		#expect(repeated.contains("aa"))
		#expect(repeated.contains("ab"))
		#expect(repeated.contains("ba"))
		#expect(repeated.contains("aaaaaa"))
	}



	@Test("Set Operations") func Initialization0() {
		var nfa = NFA<Character>(["abc", "def"])
		#expect(nfa.contains("abc"))
		#expect(nfa.contains("def"))

		nfa.formIntersection(NFA(verbatim: "abc"))
		#expect(nfa.contains("abc"))
		#expect(!nfa.contains("def"))

		nfa.formSymmetricDifference(NFA(verbatim: "def"))
		#expect(nfa.contains("abc"))
		#expect(nfa.contains("def"))

		nfa.formSymmetricDifference(NFA(verbatim: "abc"))
		#expect(!nfa.contains("abc"))
		#expect(nfa.contains("def"))
	}

	@Test("Simple Homomorphism - Identity Mapping") func Test01() {
		let nfa = NFA<Character>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "a"), ("b", "b"), ("c", "c")]
		let newNFA: NFA<Character> = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("abc"))
		#expect(!newNFA.contains("ab"))
	}

	@Test("Homomorphism - Symbol Replacement") func Test02() {
		let nfa = NFA<Character>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "x"), ("b", "y"), ("c", "z")]
		let newNFA: NFA<Character> = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("xyz"))
		#expect(!newNFA.contains("abc"))
		#expect(!newNFA.contains("xy"))
	}

	@Test("Homomorphism - Symbol to Multiple Symbols") func Test03() {
		let nfa = NFA<Character>(verbatim: "a")
		let mapping: [(String, String)] = [("a", "bb")]
		let newNFA: NFA<Character> = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("bb"))
		#expect(!newNFA.contains("a"))
		#expect(!newNFA.contains("b"))
	}

	@Test("Homomorphism - Multiple Symbols to One Symbol") func Test04() {
		let nfa = NFA<Character>(verbatim: "ab")
		let mapping: [(String, String)] = [("a", "x"), ("b", "x")]
		let newNFA: NFA<Character> = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("xx"))
		#expect(!newNFA.contains("x"))
	}

	@Test("Homomorphism - Heterogneous types") func Test05() {
		let language = NFA<Character>(["ab", "ba"]);
		let mapping: [(String, Array<UInt8>)] = [("a", [1]), ("b", [2])]
		let translation: NFA<UInt8> = language.homomorphism(mapping: mapping)

		#expect(translation.contains([1, 2]))
		#expect(translation.contains([2, 1]))
		#expect(!translation.contains([1, 1]))
		#expect(!translation.contains([2, 2]))
	}

	@Test("Homomorphism - Complex Mapping") func Test06() {
		let nfa = NFA<Character>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "x"), ("bc", "yz")]
		let newNFA: NFA<Character> = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("xyz"))
		#expect(!newNFA.contains("xy"))
		#expect(!newNFA.contains("x"))
	}

	@Test("Homomorphism - No Mapping for Some Symbols") func Test07() {
		let language = NFA<Character>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "x"), ("b", "b"), ("c", "c")]
		let translation: NFA<Character> = language.homomorphism(mapping: mapping)
		#expect(translation.contains("xbc"))
		#expect(!translation.contains("abc"))
		#expect(!translation.contains("xb"))
		#expect(!translation.contains("ab"))
	}

//	@Test("Homomorphism - Plain text to JSON") func Test08() {
//		let language = NFA<Character>(verbatim: "abc")
//		let mapping: [(DFA<String>, DFA<String>)] = [
//			(DFA(["a"]), DFA(["a", "\\x61"])),
//			(DFA(["b"]), DFA(["b", "\\x62"])),
//			(DFA(["c"]), DFA(["c", "\\x63"])),
//		]
//		let translation = NFA(["abc"]).homomorphism(mapping: mapping)
//		for string in translation {
//			print(string);
//		}
//
//		#expect(translation.contains("xbc"))
//		#expect(!translation.contains("abc"))
//		#expect(!translation.contains("xb"))
//		#expect(!translation.contains("ab"))
//	}

}
