import Testing;
@testable import FSM

// Test Suite
@Suite("RE") struct RETests {
	@Suite("description") struct REPatternTests_description {
		@Test("Empty pattern")
		func test_UInt8_empty() async throws {
			let empty = REPattern<Int>.empty
			#expect(empty.description == "[^]", "Empty pattern should be represented as an impossible regex")
		}

		@Test("Epsilon pattern")
		func test_UInt8_epsilon() async throws {
			let epsilon = REPattern<Int>.epsilon
			#expect(epsilon.description == "", "Epsilon pattern should be represented as emptystring")
		}

		@Test("CodePoint pattern")
		func test_UInt8_symbol() async throws {
			let pattern = REPattern<Int>.symbol(0x61)
			#expect(pattern.description == "a")
		}

		@Test("Union of patterns")
		func test_UInt8_union() async throws {
			let a = REPattern.symbol(0x41);
			let b = REPattern.symbol(0x43);
			let union = a.union(b)
			#expect(union.description == "A|C", "Union should join patterns with '|'")
		}

		@Test("Nested union")
		func test_UInt8_nestedUnion() async throws {
			let a = REPattern.symbol(0x41);
			let b = REPattern.symbol(0x43);
			let c = REPattern.symbol(0x45);
			let union1 = a.union(b)
			let union2 = c.union(a)
			let union = union1.union(union2)
			#expect(union.description == "A|C|E", "Nested unions should flatten with '|'")
		}

		@Test("Character range")
		func test_UInt8_union_range() async throws {
			let union = REPattern.union([REPattern.symbol(0x41), REPattern.symbol(0x42), REPattern.symbol(0x43)])
			#expect(union.description == "[A-C]")
		}

		@Test("Concatenation of patterns")
		func test_UInt8_concatenate() async throws {
			let a = REPattern.symbol(0x31);
			let b = REPattern.symbol(0x32);
			let concat = a.concatenate(b)
			#expect(concat.description == "12")
		}

		@Test("Nested concatenation")
		func test_UInt8_nestedConcatenate() async throws {
			let a = REPattern.symbol(0x31);
			let b = REPattern.symbol(0x32);
			let c = REPattern.symbol(0x33);
			let concat1 = a.concatenate(b)
			let concat2 = concat1.concatenate(c)
			#expect(concat2.description == "123", "Nested concatenations should flatten with '.'")
		}

		@Test("Kleene star")
		func test_UInt8_star() async throws {
			let a = REPattern.symbol(0x50);
			let star = a.star()
			#expect(star.description == "P*", "Star should append '*'")
		}

		@Test("Precedence: union over concatenation")
		func test_UInt8_precedenceUnionOverConcat() async throws {
			let a = REPattern.symbol(0x31);
			let b = REPattern.symbol(0x33);
			let c = REPattern.symbol(0x35);
			let union = a.union(b)
			let concat = union.concatenate(c)
			#expect(concat.description == "(1|3)5", "Union should be parenthesized within concatenation")
		}

		@Test("Precedence: concatenation over star")
		func test_UInt8_precedenceConcatOverStar() async throws {
			let a = REPattern.symbol(0x31);
			let b = REPattern.symbol(0x32);
			let star = b.star()
			let concat = a.concatenate(star)
			#expect(concat.description == "12*", "Star should not be parenthesized within concatenation")
		}

		@Test("Optional pattern")
		func test_UInt8_optional() async throws {
			let a = REPattern.symbol(0x31);
			let opt = a.optional()
			#expect(opt.description == "|1", "Optional should union with epsilon")
		}

		@Test("Plus pattern")
		func test_UInt8_plus() async throws {
			let a = REPattern.symbol(0x31);
			let plus = a.plus()
			#expect(plus.description == "11*", "Plus should be concatenation with star")
		}

		@Test("Repeating exact count")
		func test_UInt8_repeatingExact() async throws {
			let a = REPattern.symbol(0x41);
			let repeat3 = a.repeating(3)
			#expect(repeat3.description == "AAA", "Repeating 3 should concatenate three times")
		}

		@Test("Repeating range")
		func test_UInt8_repeatingRange() async throws {
			let a = REPattern.symbol(0x41);
			let range = a.repeating(1...3)
			// TODO: Update to "A{1,3}"
			#expect(range.description == "A(|A)(|A)", "Range 1...3 should include optional parts")
		}

		@Test("Repeating at least")
		func test_UInt8_repeatingAtLeast() async throws {
			let a = REPattern.symbol(0x41);
			let atLeast2 = a.repeating(2...)
			#expect(atLeast2.description == "AAA*")
		}

		@Test("Sequence initialization")
		func test_UInt8_sequenceInit() async throws {
			let seq = REPattern([0x31, 0x32, 0x33])
			#expect(seq.description == "123")
		}

		@Test("empty.union(empty)")
		func test_UInt8_empty_union_empty() async throws {
			let seq = REPattern<UInt8>.empty.union(REPattern<UInt8>.empty)
			// Union of two empty sets is empty
			#expect(seq.description == "[^]")
		}

		@Test("empty.union(epsilon)")
		func test_UInt8_empty_union_epsilon() async throws {
			let seq = REPattern<UInt8>.empty.union(REPattern<UInt8>.epsilon)
			// Union of of empty set and singleton is singleton
			#expect(seq.description == "")
		}

		@Test("empty.union(symbol)")
		func test_UInt8_empty_union_symbol() async throws {
			let seq = REPattern<UInt8>.empty.union(REPattern<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(seq.description == " ")
		}

		@Test("empty.concatenate(empty)")
		func test_UInt8_empty_concatenate_empty() async throws {
			let seq = REPattern<UInt8>.empty.concatenate(REPattern<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(seq.description == "[^]")
		}

		@Test("empty.concatenate(epsilon)")
		func test_UInt8_empty_concatenate_epsilon() async throws {
			let seq = REPattern<UInt8>.empty.concatenate(REPattern<UInt8>.epsilon)
			// Concatenation with empty set is empty set
			#expect(seq.description == "[^]")
		}

		@Test("empty.concatenate(symbol)")
		func test_UInt8_empty_concatenate_symbol() async throws {
			let seq = REPattern<UInt8>.empty.concatenate(REPattern<UInt8>.symbol(0x20))
			// Concatenation with empty set is empty set
			#expect(seq.description == "[^]")
		}

		@Test("empty.star")
		func test_UInt8_empty_star() async throws {
			let seq = REPattern<UInt8>.empty.star()
			// This becomes epsilon, because empty set repeated zero times is epsilon
			#expect(seq.description == "")
		}

		@Test("epsilon.union(empty)")
		func test_UInt8_epsilon_union_empty() async throws {
			let seq = REPattern<UInt8>.epsilon.union(REPattern<UInt8>.empty)
			// Union with epsilon contains epsilon
			#expect(seq.description == "")
		}

		@Test("epsilon.union(epsilon)")
		func test_UInt8_epsilon_union_epsilon() async throws {
			let seq = REPattern<UInt8>.epsilon.union(REPattern<UInt8>.epsilon)
			// Union with epsilon and itself contains epsilon
			#expect(seq.description == "")
		}

		@Test("epsilon.union(symbol)")
		func test_UInt8_epsilon_union_symbol() async throws {
			let seq = REPattern<UInt8>.epsilon.union(REPattern<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(seq.description == "| ")
		}

		@Test("epsilon.concatenate(empty)")
		func test_UInt8_epsilon_concatenate_empty() async throws {
			let seq = REPattern<UInt8>.epsilon.concatenate(REPattern<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(seq.description == "[^]")
		}

		@Test("epsilon.concatenate(epsilon)")
		func test_UInt8_epsilon_concatenate_epsilon() async throws {
			let seq = REPattern<UInt8>.epsilon.concatenate(REPattern<UInt8>.epsilon)
			// Concatenation with epsilon is itself
			#expect(seq.description == "")
		}

		@Test("epsilon.concatenate(symbol)")
		func test_UInt8_epsilon_concatenate_symbol() async throws {
			let seq = REPattern<UInt8>.epsilon.concatenate(REPattern<UInt8>.symbol(0x20))
			// Concatenation with epsilon is itself
			#expect(seq.description == " ")
		}

		@Test("epsilon.star")
		func test_UInt8_epsilon_star() async throws {
			let seq = REPattern<UInt8>.epsilon.star()
			// Nothing never grows adding nothing
			#expect(seq.description == "")
		}

		@Test("union(union(union))")
		func test_UInt8_union_nested() async throws {
			let seq = REPattern<UInt8>.union([
				REPattern<UInt8>.union([
					REPattern<UInt8>.union([
						REPattern<UInt8>.symbol(0x20),
					])
				])
			])
			// epsilon* == epsilon
			#expect(seq.description == " ", "Sequence init should concatenate elements")
		}

		@Test("union.star")
		func test_UInt8_union_star() async throws {
			let seq = REPattern<UInt8>.alternation([
				REPattern<UInt8>.symbol(0x20),
				REPattern<UInt8>.symbol(0x30),
			]).star()
			// epsilon* == epsilon
			#expect(seq.description == "( |0)*", "Sequence init should concatenate elements")
		}

		@Test("concatenate.star")
		func test_UInt8_concatenate_star() async throws {
			let seq = REPattern<UInt8>.epsilon.star()
			// epsilon* == epsilon
			#expect(seq.description == "", "Sequence init should concatenate elements")
		}

		@Test("epsilon.star")
		func test_UInt8_symbol_star() async throws {
			let seq = REPattern<UInt8>.symbol(0x20).star()
			#expect(seq.description == " *", "Sequence init should concatenate elements")
		}
	}

	// Test Suite
	@Suite("alphabet/alphabetPartitions") struct REPatternTests_alphabet {
		@Test("Empty pattern")
		func test_UInt8_empty() async throws {
			let pattern = REPattern<Int>.empty
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("Epsilon pattern")
		func test_UInt8_epsilon() async throws {
			let pattern = REPattern<Int>.epsilon
			#expect(pattern.alphabet == Set())
			#expect(pattern.alphabetPartitions == Set())
		}

		@Test("Symbol pattern")
		func test_UInt8_symbol() async throws {
			let pattern = REPattern<Int>.symbol(10)
			#expect(pattern.alphabet == Set([10]))
			#expect(pattern.alphabetPartitions == Set([ Set([10]) ]))
		}

		@Test("Union of patterns")
		func test_UInt8_union() async throws {
			let a = REPattern.symbol(1);
			let b = REPattern.symbol(2);
			let pattern = a.union(b)
			#expect(pattern.alphabet == Set([1, 2]))
			#expect(pattern.alphabetPartitions == Set([ Set([1, 2]) ]))
		}

		@Test("Nested union")
		func test_UInt8_nestedUnion() async throws {
			let a = REPattern.symbol(1);
			let b = REPattern.symbol(2);
			let c = REPattern.symbol(3);
			let union1 = a.union(b)
			let union2 = c.union(a)
			let pattern = union1.union(union2)
			#expect(pattern.alphabet == Set([1, 2, 3]))
			#expect(pattern.alphabetPartitions == Set([ Set([1, 2, 3]) ]))
		}

		@Test("Concatenation of patterns")
		func test_UInt8_concatenate() async throws {
			let a = REPattern.range(1...4);
			let b = REPattern.range(3...6);
			let pattern = a.concatenate(b)
			#expect(Set(1...3) == Set([1,2,3]))
			#expect(pattern.alphabet == Set(1...6))
			#expect(pattern.alphabetPartitions == Set([ Set(1...2), Set(3...4), Set(5...6) ]))
		}

		@Test("Nested concatenation")
		func test_UInt8_nestedConcatenate() async throws {
			let a = REPattern.range(1...20);
			let b = REPattern.range(2...19);
			let c = REPattern.range(3...18);
			let concat1 = a.concatenate(b)
			let pattern = concat1.concatenate(c)
			#expect(pattern.alphabet == Set(1...20))
			#expect(pattern.alphabetPartitions == Set([ Set([1, 20]), Set([2, 19]), Set(3...18) ]))
		}

		@Test("Kleene star")
		func test_UInt8_star() async throws {
			let a = REPattern.range(1...3);
			let pattern = a.star()
			#expect(pattern.alphabet == Set([1, 2, 3]))
			#expect(pattern.alphabetPartitions == Set([ Set([1, 2, 3]) ]))
		}

		@Test("Precedence: union over concatenation")
		func test_UInt8_precedenceUnionOverConcat() async throws {
			let a = REPattern.symbol(1);
			let b = REPattern.symbol(2);
			let c = REPattern.symbol(3);
			let union = a.union(b)
			let pattern = union.concatenate(c)
			#expect(pattern.alphabet == Set(1...3))
			#expect(pattern.alphabetPartitions == Set([ Set(1...2), Set([3]) ]))
		}

		@Test("Precedence: concatenation over star")
		func test_UInt8_precedenceConcatOverStar() async throws {
			let a = REPattern.range(1...4);
			let b = REPattern.range(3...6);
			let star = b.star()
			let pattern = a.concatenate(star)
			#expect(pattern.alphabet == Set(1...6))
			#expect(pattern.alphabetPartitions == Set([ Set(1...2),  Set(3...4),  Set(5...6) ]))
		}

		@Test("Optional pattern")
		func test_UInt8_optional() async throws {
			let a = REPattern.range(1...3);
			let pattern = a.optional()
			#expect(pattern.alphabet == Set([1, 2, 3]))
			#expect(pattern.alphabetPartitions == Set([ Set([1, 2, 3]) ]))
		}

		@Test("Plus pattern")
		func test_UInt8_plus() async throws {
			let a = REPattern.symbol(1);
			let pattern = a.plus()
			#expect(pattern.alphabet == Set([1]))
			#expect(pattern.alphabetPartitions == Set([ Set([1]) ]))
		}

		@Test("Repeating exact count")
		func test_UInt8_repeatingExact() async throws {
			let a = REPattern.symbol(1);
			let pattern = a.repeating(3)
			#expect(pattern.alphabet == Set([1]))
			#expect(pattern.alphabetPartitions == Set([ Set([1]) ]))
		}

		@Test("Repeating range")
		func test_UInt8_repeatingRange() async throws {
			let a = REPattern.symbol(1);
			let pattern = a.repeating(1...3)
			#expect(pattern.alphabet == Set([1]))
			#expect(pattern.alphabetPartitions == Set([ Set([1]) ]))
		}

		@Test("Repeating at least")
		func test_UInt8_repeatingAtLeast() async throws {
			let a = REPattern.range(1...3);
			let pattern = a.repeating(2...)
			#expect(pattern.alphabet == Set(1...3))
			#expect(pattern.alphabetPartitions == Set([ Set(1...3) ]))
		}

		@Test("Sequence initialization")
		func test_UInt8_sequenceInit() async throws {
			let pattern = REPattern([1, 2, 3])
			#expect(pattern.alphabet == Set(1...3))
			#expect(pattern.alphabetPartitions == Set([ Set([1]), Set([2]), Set([3]) ]))
		}

		@Test("empty.union(empty)")
		func test_UInt8_empty_union_empty() async throws {
			let pattern = REPattern<UInt8>.empty.union(REPattern<UInt8>.empty)
			// Union of two empty sets is empty
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("empty.union(epsilon)")
		func test_UInt8_empty_union_epsilon() async throws {
			let pattern = REPattern<UInt8>.empty.union(REPattern<UInt8>.epsilon)
			// Union of of empty set and singleton is singleton
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("empty.union(symbol)")
		func test_UInt8_empty_union_symbol() async throws {
			let pattern = REPattern<UInt8>.empty.union(REPattern<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(pattern.alphabet == Set([0x20]))
			#expect(pattern.alphabetPartitions == Set([ Set([0x20]) ]))
		}

		@Test("empty.concatenate(empty)")
		func test_UInt8_empty_concatenate_empty() async throws {
			let pattern = REPattern<UInt8>.empty.concatenate(REPattern<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("empty.concatenate(epsilon)")
		func test_UInt8_empty_concatenate_epsilon() async throws {
			let pattern = REPattern<UInt8>.empty.concatenate(REPattern<UInt8>.epsilon)
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("empty.concatenate(symbol)")
		func test_UInt8_empty_concatenate_symbol() async throws {
			let pattern = REPattern<UInt8>.empty.concatenate(REPattern<UInt8>.symbol(0x20))
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("empty.star")
		func test_UInt8_empty_star() async throws {
			let pattern = REPattern<UInt8>.empty.star()
			// This becomes epsilon, because empty set repeated zero times is epsilon
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("epsilon.union(empty)")
		func test_UInt8_epsilon_union_empty() async throws {
			let pattern = REPattern<UInt8>.epsilon.union(REPattern<UInt8>.empty)
			// Union with epsilon contains epsilon
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("epsilon.union(epsilon)")
		func test_UInt8_epsilon_union_epsilon() async throws {
			let pattern = REPattern<UInt8>.epsilon.union(REPattern<UInt8>.epsilon)
			// Union with epsilon and itself contains epsilon
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("epsilon.union(symbol)")
		func test_UInt8_epsilon_union_symbol() async throws {
			let pattern = REPattern<UInt8>.epsilon.union(REPattern<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(pattern.alphabet == Set([0x20]))
			#expect(pattern.alphabetPartitions == Set([ Set([0x20]) ]))
		}

		@Test("epsilon.concatenate(empty)")
		func test_UInt8_epsilon_concatenate_empty() async throws {
			let pattern = REPattern<UInt8>.epsilon.concatenate(REPattern<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("epsilon.concatenate(epsilon)")
		func test_UInt8_epsilon_concatenate_epsilon() async throws {
			let pattern = REPattern<UInt8>.epsilon.concatenate(REPattern<UInt8>.epsilon)
			// Concatenation with epsilon is itself
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("epsilon.concatenate(symbol)")
		func test_UInt8_epsilon_concatenate_symbol() async throws {
			let pattern = REPattern<UInt8>.epsilon.concatenate(REPattern<UInt8>.symbol(0x20))
			// Concatenation with epsilon is itself
			#expect(pattern.alphabet == Set([0x20]))
			#expect(pattern.alphabetPartitions == Set([ Set([0x20]) ]))
		}

		@Test("epsilon.star")
		func test_UInt8_epsilon_star() async throws {
			let pattern = REPattern<UInt8>.epsilon.star()
			// Nothing never grows adding nothing
			#expect(pattern.alphabet == Set([]))
			#expect(pattern.alphabetPartitions == Set([]))
		}

		@Test("union(union(union))")
		func test_UInt8_union_nested() async throws {
			let pattern = REPattern<UInt8>.union([
				REPattern<UInt8>.union([
					REPattern<UInt8>.union([
						REPattern<UInt8>.symbol(0x20),
					]),
					REPattern<UInt8>.symbol(0x21),
				]),
				REPattern<UInt8>.symbol(0x22),
			])
			#expect(pattern.alphabet == Set(0x20...0x22))
			#expect(pattern.alphabetPartitions == Set([ Set(0x20...0x22) ]))
		}

		@Test("union.star")
		func test_UInt8_union_star() async throws {
			let pattern = REPattern<UInt8>.alternation([
				REPattern<UInt8>.symbol(0x20),
				REPattern<UInt8>.symbol(0x21),
			]).star()
			#expect(pattern.alphabet == Set(0x20...0x21))
			#expect(pattern.alphabetPartitions == Set([ Set(0x20...0x21) ]))
		}

		@Test("epsilon.star")
		func test_UInt8_symbol_star() async throws {
			let pattern = REPattern<UInt8>.range(0x30...0x39).star()
			#expect(pattern.alphabet == Set(0x30...0x39))
			#expect(pattern.alphabetPartitions == Set([ Set(0x30...0x39) ]))
		}
	}
}
