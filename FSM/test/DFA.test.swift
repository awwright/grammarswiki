@testable import FSM
import Testing

@Suite("DFA Tests") struct DFATests {

	@Test("Empty DFA of Strings should not contain any input")
	func testEmptyDFAString() {
		let dfa = DFA<Character>()
		#expect(!dfa.contains("a"))
		#expect(!dfa.contains(""))
	}

	@Test("Empty DFA of UInt8 Arrays should not contain any input")
	func testEmptyDFAUInt8() {
		let dfa = DFA<UInt8>()
		#expect(!dfa.contains([0]))
		#expect(!dfa.contains([]))
	}

	@Test("DFA from verbatim should recognize the input")
	func testDFAFromVerbatim() {
		let dfa = DFA<Character>(verbatim: "abc")
		#expect(dfa.contains("abc"))
		#expect(!dfa.contains("ab"))
		#expect(!dfa.contains("abcd"))
	}

	@Test("Character range")
	func test_from_ClosedRange() {
		let dfa = DFA<Character>.range("a"..."f")
		#expect(!dfa.contains(""))
		#expect(dfa.contains("a"))
		#expect(dfa.contains("f"))
		#expect(!dfa.contains("g"))
		#expect(!dfa.contains("aa"))
	}

	@Test("Import from NFA")
	func testDFAFromNFA() {
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
		let dfa = DFA<Character>(verbatim: "abc")
		let expectedAlphabet: Set<Character> = ["a", "b", "c"]
		#expect(dfa.alphabet == expectedAlphabet)
	}

	@Test("nextState for symbol")
	func test_nextState_symbol() {
		let dfa_string = DFA<Character>(verbatim: "abc")
		#expect(dfa_string.nextState(state: 0, symbol: "a") == 1)
		#expect(dfa_string.nextState(state: 1, symbol: "b") == 2)

		let dfa_int = DFA<Int>(verbatim: [0, 1, 2])
		#expect(dfa_int.nextState(state: 0, symbol: 0) == 1)
		#expect(dfa_int.nextState(state: 1, symbol: 1) == 2)
		#expect(dfa_int.nextState(state: 2, symbol: 2) == 3)
		#expect(dfa_int.nextState(state: 3, symbol: 0) == nil)

		let dfa_bool = DFA<Bool>(verbatim: [true, false, true])
		#expect(dfa_bool.nextState(state: 0, symbol: true) == 1)
		#expect(dfa_bool.nextState(state: 1, symbol: false) == 2)
		#expect(dfa_bool.nextState(state: 2, symbol: true) == 3)
		#expect(dfa_bool.nextState(state: 3, symbol: false) == nil)
		#expect(dfa_bool.nextState(state: 3, symbol: true) == nil)
	}

	@Test("nextState for input string")
	func test_nextState_string() {
		let dfa_string = DFA<Character>(verbatim: "abc")
		#expect(dfa_string.nextState(state: 0, input: "a") == 1)
		#expect(dfa_string.nextState(state: 0, input: "ab") == 2)
		#expect(dfa_string.nextState(state: 1, input: "bc") == 3)
		#expect(dfa_string.nextState(state: 1, input: "c") == nil)

		let dfa_int = DFA<Int>(verbatim: [0, 1, 2])
		#expect(dfa_int.nextState(state: 0, input: [0, 1]) == 2)
		#expect(dfa_int.nextState(state: 1, input: [1, 2]) == 3)
		#expect(dfa_int.nextState(state: 2, input: [2, 3]) == nil)
		#expect(dfa_int.nextState(state: 3, input: [0]) == nil)

		let dfa = DFA<Bool>(verbatim: [true, false, true])
		#expect(dfa.nextState(state: 0, input: [true, false]) == 2)
		#expect(dfa.nextState(state: 0, input: [true, false, true]) == 3)
		#expect(dfa.nextState(state: 0, input: [true, false, true, false]) == nil)
	}

	@Test("Greedy match")
	func test_match() {
		let dfa = DFA<Character>(["a", "ab", "xy"])
		#expect(dfa.match("zzz") == nil)
		#expect(dfa.match("") == nil)
		#expect(dfa.match("a")! == ("a", ""))
		#expect(dfa.match("ab")! == ("ab", ""))
		#expect(dfa.match("abc")! == ("ab", "c"))
		#expect(dfa.match("x") == nil)
		#expect(dfa.match("xy")! == ("xy", ""))
		#expect(dfa.match("xyz")! == ("xy", "z"))

		let dfa2 = DFA<Character>(["", "abc"])
		#expect(dfa2.match("")! == ("", ""))
		#expect(dfa2.match("a")! == ("", "a"))
		#expect(dfa2.match("ab")! == ("", "ab"))
		#expect(dfa2.match("abc")! == ("abc", ""))
		#expect(dfa2.match("abcd")! == ("abc", "d"))
	}

	@Test("equivalent")
	func test_equivalent() throws {
		let dfa = DFA<Character>(["a", "aa", "aaa", "aaaa"]).concatenate(DFA<Character>(["b", "bb", "bbb", "bbbb"])).concatenate(DFA<Character>(["a"]).star()).minimized()
		let equivalent = try #require(dfa.equivalentInputs(input: "ab"))
		#expect(Set(equivalent.map { String($0) }) == Set(["ab", "aab", "aaab", "aaaab"]))
	}

	@Test("minimized")
	func test_minimized() {
		// A DFA with only dead states
		let dfa0 = DFA<UInt8>(
			states: [[0:2], [0:2], [1:3], [0:4], [:]],
			initial: 0,
			finals: []
		)
		#expect(dfa0.finals.isEmpty)

		// A DFA with some live states and some dead states
		let dfa = DFA<UInt8>(
			states: [[0:2], [0:2], [1:3], [0:4], [:]],
			initial: 0,
			finals: [2]
		)
		#expect(dfa.minimized().states.count == 2)
		#expect(dfa.finals.count == 1)

		let providedDictionary = ABNFBuiltins<DFA<UInt8>>.dictionary
		providedDictionary.forEach { key, value in
			#expect(value.finals.isEmpty == false)
			let difference = value.symmetricDifference(value.minimized())
			#expect(difference.finals.isEmpty)
		}
	}

	@Test("parallel")
	func test_parallel() {
		// See union, intersection, and symmetricDifference below
	}

	@Test("mapTransitions")
	func test_mapTransitions() {
		// Map symbols from ASCII UInt8 to Character
		let dfa1 = DFA<UInt8>([ [0x61], [0x61, 0x62], [0x63, 0x64] ]);
		let dfa2: DFA<Character> = dfa1.mapSymbols({
			symbol in
			// Read `symbol` as an ASCII character and convert it to a Character
			return Character(UnicodeScalar(Int(symbol))!)
		})
		#expect(!dfa2.contains(""))
		#expect(dfa2.contains("a"))
		#expect(dfa2.contains("ab"))
		#expect(dfa2.contains("cd"))
	}

	@Test("Union of DFAs")
	func testDFAUnion() {
		let dfa1 = DFA<Character>(verbatim: "a")
		let dfa2 = DFA<Character>(verbatim: "b")
		let unionDFA = dfa1.union(dfa2)
		#expect(unionDFA.contains("a"))
		#expect(unionDFA.contains("b"))
		#expect(!unionDFA.contains("ab"))
	}

	@Test("Intersection of DFAs")
	func testDFAIntersection() {
		let dfa1 = DFA<Character>(["a", "b"])
		let dfa2 = DFA<Character>(["b", "c"])
		let intersectionDFA = dfa1.intersection(dfa2)

		#expect(!intersectionDFA.contains("a"))
		#expect(intersectionDFA.contains("b"))
		#expect(!intersectionDFA.contains("c"))
		#expect(!intersectionDFA.contains("ab"))
	}

	@Test("Symmetric Difference of DFAs")
	func testDFASymmetricDifference() {
		let dfa1 = DFA<Character>(["a", "b", "ab"])
		let dfa2 = DFA<Character>(verbatim: "ab")
		let symDiffDFA = dfa1.symmetricDifference(dfa2)

		#expect(symDiffDFA.contains("a"))
		#expect(symDiffDFA.contains("b"))
		#expect(!symDiffDFA.contains("ab"))
	}

	@Test("concatenate")
	func test_concatenate() {
		let dfa1 = DFA<Character>(["a", "b"])
		let dfa2 = DFA<Character>(["x", "y"])
		let concatenation = dfa1.concatenate(dfa2);
		let language = Array(concatenation.map { String($0) });
		#expect(language.count == 4)
		#expect(language.contains("ax"))
		#expect(language.contains("ay"))
		#expect(language.contains("bx"))
		#expect(language.contains("by"))
	}

	@Test("optional")
	func test_optional() {
		let dfa1 = DFA<Character>(["a", "b"])
		let optional = dfa1.optional();
		#expect(optional.contains(""))
		#expect(optional.contains("a"))
		#expect(optional.contains("b"))
		let array = Array(optional);
		#expect(array.count == 3)
	}

	@Test("plus")
	func test_plus() {
		let dfa1 = DFA<Character>(["a", "b"])
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
		let dfa1 = DFA<Character>(["a", "b"])
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
		let original = DFA<Character>(["a", "b"])
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
		let original = DFA<Character>(["a", "b"])
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
		let original = DFA<Character>(["a", "b"])
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
		var dfa = DFA<Character>()
		let (inserted, _) = dfa.insert("test")
		#expect(inserted)
		#expect(dfa.contains("test"))

		let removed = dfa.remove("test")
		#expect(removed != nil)
		#expect(!dfa.contains("test"))
	}

	@Test("DFA#paths Iterator: Single initial state, empty set")
	func test_paths_0() {
		let dfa = DFA<Character>(
			states: [
				[:],
			],
			initial: 0,
			finals: []
		)
		let paths = Array(dfa.paths);
		#expect(paths == [[]])
	}

	@Test("DFA#paths iterator: Single initial state, empty string final")
	func test_paths_1() {
		let dfa = DFA<Character>(
			states: [
				[:],
			],
			initial: 0,
			finals: [0]
		)
		let paths = Array(dfa.paths);
		#expect(paths == [[]])
	}

	@Test("DFA#paths iterator: Single initial state, empty string final")
	func test_paths_2() {
		let dfa = DFA<Character>(
			states: [
				["x": 1],
				[:],
			],
			initial: 0,
			finals: [1]
		)
		let paths = Array(dfa.paths);
		#expect(paths == [
			[],
			[DFA<Character>.PathIterator.Segment(source: 0, index: 0, symbol: "x", target: 1)],
		])
	}

	@Test("DFA#paths filtered: Single initial state, single character star, path length less than 3")
	func test_paths_filter_0() {
		let dfa = DFA<Character>(
			states: [
				["x": 0],
			],
			initial: 0,
			finals: [0]
		)
		func filter(iterator: DFA<Character>.PathIterator, path: DFA<Character>.PathIterator.Path) -> Bool {
			return path.count < 3;
		}
		var array: Array<DFA<Character>.PathIterator.Path> = [];
		for path in dfa.pathIterator(filter: filter) {
			array.append(path);
		}
		#expect(array == [
			[],
			[DFA<Character>.PathIterator.Segment(source: 0, index: 0, symbol: "x", target: 0)],
			[DFA<Character>.PathIterator.Segment(source: 0, index: 0, symbol: "x", target: 0), DFA<Character>.PathIterator.Segment(source: 0, index: 0, symbol: "x", target: 0)]
		]);
	}

	@Test("DFA#paths filtered: No revisiting states (no cycles)")
	func test_paths_filter_2() {
		let dfa = DFA<Character>(
			states: [
				["x": 1],
				["y": 2],
				["z": 0],
			],
			initial: 0,
			finals: [0, 1, 2]
		)
		func filter(iterator: DFA<Character>.PathIterator, path: DFA<Character>.PathIterator.Path) -> Bool {
			var seenTargets = Set([0])
			for segment in path {
				if seenTargets.insert(segment.target).inserted == false {
					// If insert returns false, we’ve seen this target before; skip it
					return false
				}
			}
			return true
		}
		let paths = Array(dfa.pathIterator(filter: filter));
		#expect(paths == [
			[],
			[DFA<Character>.PathIterator.Segment(source: 0, index: 0, symbol: "x", target: 1)],
			[DFA<Character>.PathIterator.Segment(source: 0, index: 0, symbol: "x", target: 1), DFA<Character>.PathIterator.Segment(source: 1, index: 0, symbol: "y", target: 2)],
			// No transition to "z" because that targets the origin, which we've always previously "visited"
		]);
	}

	@Test("IteratorProtocol conformance: Empty string")
	func testIteratorProtocol1() {
		let dfa = DFA<Character>(verbatim: "")
		var values: [String] = []
		for string: String in dfa {
			values.append(String(string))
		}
		#expect(values == [""])
	}

	@Test("IteratorProtocol")
	func testIteratorProtocol3() {
		let dfa = DFA<Character>(["bc", "a", "abcdefg", "ab", ""])
		var values: [String] = []
		for string: String in dfa {
			values.append(String(string))
		}
		#expect(values == ["", "a", "ab", "bc", "abcdefg"])
	}

	@Test("nextStates by DFA")
	func test_nextStates_DFA() {
		let dfa = DFA(["abcdefghi"]);
		let pattern = DFA(["abc"])
			.concatenate(DFA(["d"]).optional())
			.concatenate(DFA(["e"]).optional())
			.concatenate(DFA(["f"]).optional());
		#expect(dfa.nextStates(initial: 0, input: pattern) == [3, 4, 5, 6]);
	}

	@Test("nextStates by DFA #2")
	func test_nextStates_DFA_2() {
		let dfa = DFA(["101001000100"]);
		// Follow any number of 0's, then a 1
		let pattern = DFA(["0"]).star().concatenate(DFA(["1"]));
		#expect(dfa.nextStates(initial: 0, input: pattern) == [1]);
		#expect(dfa.nextStates(initial: 1, input: pattern) == [3]);
		#expect(dfa.nextStates(initial: 2, input: pattern) == [3]);
		#expect(dfa.nextStates(initial: 3, input: pattern) == [6]);
		#expect(dfa.nextStates(initial: 4, input: pattern) == [6]);
		#expect(dfa.nextStates(initial: 5, input: pattern) == [6]);
		#expect(dfa.nextStates(initial: 6, input: pattern) == [10]);
		#expect(dfa.nextStates(initial: 7, input: pattern) == [10]);
	}

	@Suite("toPattern") struct DFATests_toPattern {
		@Test("empty")
		func test_empty() {
			let dfa: DFA<UInt8> = DFA([]);
			#expect(Array(dfa).count == 0)
			let pattern: SimpleRegex<UInt8> = dfa.toPattern()
			#expect(pattern.description == "∅")
		}

		@Test("epsilon")
		func test_epsilon() {
			let dfa: DFA<UInt8> = DFA([ [] ]);
			#expect(Array(dfa).count == 1)
			let pattern: SimpleRegex<UInt8> = dfa.toPattern()
			#expect(pattern.description == "ε")
		}

		@Test("character")
		func test_char() {
			let dfa: DFA<UInt8> = DFA([ [0x30] ]);
			#expect(Array(dfa).count == 1)
			let pattern: SimpleRegex<UInt8> = dfa.toPattern()
			#expect(pattern.description == "30")
		}

		@Test("character?")
		func test_optional() {
			let dfa: DFA<UInt8> = DFA([ [], [0x30] ]);
			#expect(Array(dfa).count == 2)
			let pattern: SimpleRegex<UInt8> = dfa.toPattern()
			#expect(pattern.description == "ε|30")
		}

		@Test("character+")
		func test_plus() {
			// FIXME: .minimized() is required otherwise this produces 30.30*
			// Is this something that can be fixed in .star()?
			let dfa: DFA<UInt8> = DFA([ [0x30] ]).plus().minimized();
			let pattern: SimpleRegex<UInt8> = dfa.toPattern()
			#expect(pattern.description == "30.30*")
		}

		@Test("character*")
		func test_star() {
			// FIXME: .minimized() is required otherwise this produces ε|30.30*
			// Is this something that can be fixed in .star()?
			let dfa: DFA<UInt8> = DFA([ [0x30] ]).star().minimized();
			let pattern: SimpleRegex<UInt8> = dfa.toPattern()
			#expect(pattern.description == "30*")
		}
	}

	@Suite("alphabet/alphabetPattern") struct DFATests_alphabet {
		@Test("empty") func empty() async throws {
			let dfa: DFA<UInt8> = DFA([])
			#expect(dfa.alphabet == [])
			#expect(dfa.alphabetPartitions == [])
		}
		@Test("epsilon") func epsilon() async throws {
			let dfa: DFA<UInt8> = DFA([ [] ]).minimized();
			#expect(dfa.alphabet == [])
			#expect(dfa.alphabetPartitions == [])
		}
		@Test("single") func single() async throws {
			let dfa: DFA<UInt8> = DFA([ [0x30] ]).minimized();
			#expect(dfa.alphabet == [0x30])
			#expect(dfa.alphabetPartitions == [ [0x30] ])
		}
		@Test("union") func union() async throws {
			let dfa: DFA<UInt8> = DFA([ [0x30], [0x31], [0x32] ]).minimized();
			#expect(dfa.alphabet == [0x30, 0x31, 0x32])
			#expect(dfa.alphabetPartitions == [ [0x30, 0x31, 0x32] ])
		}
		@Test("sequence") func sequence() async throws {
			let dfa: DFA<UInt8> = DFA([ [0x30, 0x31, 0x32] ]).minimized();
			#expect(dfa.alphabet == [0x30, 0x31, 0x32])
			#expect(dfa.alphabetPartitions == [ [0x30], [0x31], [0x32] ])
		}
		@Test("intersection") func intersection() async throws {
			let dfa: DFA<UInt8> = DFA([ [0x30],  [0x31],  [0x32],  [0x33], [0x30, 0x33] ]).minimized();
			#expect(dfa.alphabet == [0x30, 0x31, 0x32, 0x33])
			#expect(dfa.alphabetPartitions == [ [0x30], [0x31, 0x32], [0x33] ])
		}
		@Test("concatenation 1") func concatenation() async throws {
			let dfa: DFA<UInt8> = DFA([ [0x30],  [0x31],  [0x32, 0x32],  [0x33, 0x33] ]).minimized().minimized();
			#expect(dfa.alphabet == [0x30, 0x31, 0x32, 0x33])
			#expect(dfa.alphabetPartitions == [ [0x30, 0x31], [0x32], [0x33] ])
		}
		@Test("concatenation 2") func concatenation_2() async throws {
			// FIXME: Why does this only minimize correctly with two minimized() calls???
			let dfa: DFA<UInt8> = DFA([ [0x30],  [0x31],  [0x32, 0x32],  [0x32, 0x33],  [0x33, 0x32],  [0x33, 0x33] ]).minimized().minimized();
			#expect(dfa.alphabet == [0x30, 0x31, 0x32, 0x33])
			#expect(dfa.alphabetPartitions == [ [0x30, 0x31], [0x32, 0x33] ])
		}
	}
}
