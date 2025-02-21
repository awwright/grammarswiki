import Testing
@testable import FSM

@Suite("DFA Tests") struct NFATests {
	@Test("Initialization") func Initialization() {
		let nfa = NFA<String>()
		#expect(nfa.states.count == 1)
		#expect(nfa.epsilon.count == 1)
		#expect(nfa.initials == [0])
		#expect(nfa.finals.isEmpty)
	}

	@Test("Initialization with specific states") func Initialization2() {
		//	let transitions = [
		//		["a": Set([1])],
		//		["b": Set([0])],
		//	];
		//	let nfa = NFA<String>(states: transitions, epsilon: [[], []], initials: [0], finals: [1])
		//	#expect(nfa.states.count == 2)
		//	#expect(nfa.epsilon.count == 2)
		//	#expect(nfa.initials == [0])
		//	#expect(nfa.finals == [1])
	}

	@Test("Initialization with verbatim input") func Initialization3() {
		let nfa = NFA(verbatim: "abc")
		#expect(nfa.states.count == 4) // 'a', 'b', 'c', and end state
		#expect(nfa.initials == [0])
		#expect(nfa.finals == [3])
		#expect(nfa.nextStates(states: [0], symbol: "a") == [1])
		#expect(nfa.nextStates(states: [1], symbol: "b") == [2])
		#expect(nfa.nextStates(states: [2], symbol: "c") == [3])
	}

	@Test("Contains for valid input") func Initialization4() {
		let nfa = NFA(verbatim: "abc")
		#expect(nfa.contains("abc"))
		#expect(!nfa.contains("ab"))
	}

	@Test("Follow epsilon function")
	func test_followε() {
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
		let nfa = NFA<String>(states: [["a": [1]], ["b": [0]]], epsilon: [[], []], initial: 0, finals: [1])
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

	@Test("Set Operations") func Initialization0() {
		var nfa = NFA<String>(["abc", "def"])
		#expect(nfa.contains("abc"))
		#expect(nfa.contains("def"))

		nfa.formIntersection(NFA(verbatim: "abc"))
		#expect(nfa.contains("abc"))
		#expect(!nfa.contains("def"))

		print(nfa.toViz());
		nfa.formSymmetricDifference(NFA(verbatim: "def"))
		print(nfa.toViz());
		#expect(nfa.contains("abc"))
		#expect(nfa.contains("def"))

		nfa.formSymmetricDifference(NFA(verbatim: "abc"))
		#expect(!nfa.contains("abc"))
		#expect(nfa.contains("def"))
	}

	@Test("Simple Homomorphism - Identity Mapping") func Test01() {
		let nfa = NFA<String>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "a"), ("b", "b"), ("c", "c")]
		let newNFA = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("abc"))
		#expect(!newNFA.contains("ab"))
	}

	@Test("Homomorphism - Symbol Replacement") func Test02() {
		let nfa = NFA<String>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "x"), ("b", "y"), ("c", "z")]
		let newNFA = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("xyz"))
		#expect(!newNFA.contains("abc"))
		#expect(!newNFA.contains("xy"))
	}

	@Test("Homomorphism - Symbol to Multiple Symbols") func Test03() {
		let nfa = NFA<String>(verbatim: "a")
		let mapping: [(String, String)] = [("a", "bb")]
		let newNFA = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("bb"))
		#expect(!newNFA.contains("a"))
		#expect(!newNFA.contains("b"))
	}

	@Test("Homomorphism - Multiple Symbols to One Symbol") func Test04() {
		let nfa = NFA<String>(verbatim: "ab")
		let mapping: [(String, String)] = [("a", "x"), ("b", "x")]
		let newNFA = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("xx"))
		#expect(!newNFA.contains("x"))
	}

	@Test("Homomorphism - Heterogneous types") func Test05() {
		let language = NFA<String>(["ab", "ba"]);
		let mapping: [(String, Array<UInt8>)] = [("a", [1]), ("b", [2])]
		let translation = language.homomorphism(mapping: mapping)

		#expect(translation.contains([1, 2]))
		#expect(translation.contains([2, 1]))
		#expect(!translation.contains([1, 1]))
		#expect(!translation.contains([2, 2]))
	}

	@Test("Homomorphism - Complex Mapping") func Test06() {
		let nfa = NFA<String>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "x"), ("bc", "yz")]
		let newNFA = nfa.homomorphism(mapping: mapping)

		#expect(newNFA.contains("xyz"))
		#expect(!newNFA.contains("xy"))
		#expect(!newNFA.contains("x"))
	}

	@Test("Homomorphism - No Mapping for Some Symbols") func Test07() {
		let language = NFA<String>(verbatim: "abc")
		let mapping: [(String, String)] = [("a", "x"), ("b", "b"), ("c", "c")]
		let translation = language.homomorphism(mapping: mapping)
		print(language.toViz())
		print(translation.toViz())

		#expect(translation.contains("xbc"))
		#expect(!translation.contains("abc"))
		#expect(!translation.contains("xb"))
		#expect(!translation.contains("ab"))
	}

//	@Test("Homomorphism - Plain text to JSON") func Test08() {
//		let language = NFA<String>(verbatim: "abc")
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
