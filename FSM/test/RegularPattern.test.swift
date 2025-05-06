import Testing;
@testable import FSM

// Test Suite
@Suite("SimpleRegex") struct SimpleRegexTests {
	@Suite("description") struct SimpleRegexTests_description {
		@Test("Empty pattern")
		func test_UInt8_empty() async throws {
			let empty = SimpleRegex<Int>.empty
			#expect(empty.description == "∅", "Empty pattern should be represented as ∅")
			if case .alternation(let array) = empty {
				#expect(array.isEmpty, "Empty pattern should be an empty union")
			} else {
				#expect(false, "Empty pattern should be a union with no alternates")
			}
		}

		@Test("Epsilon pattern")
		func test_UInt8_epsilon() async throws {
			let epsilon = SimpleRegex<Int>.epsilon
			#expect(epsilon.description == "ε", "Epsilon pattern should be represented as ε")
			if case .concatenation(let array) = epsilon {
				#expect(array.isEmpty, "Epsilon pattern should be an empty concatenation")
			} else {
				#expect(false, "Epsilon pattern should be a concatenation with no elements")
			}
		}

		@Test("CodePoint pattern")
		func test_UInt8_symbol() async throws {
			let pattern = SimpleRegex<Int>.symbol(10)
			#expect(pattern.description == "a", "CodePoint 10 should be 'a' in hex")
			if case .symbol(let value) = pattern {
				#expect(value == 10, "CodePoint should store the correct value")
			} else {
				#expect(false, "CodePoint pattern should be a symbol case")
			}
		}

		@Test("Union of patterns")
		func test_UInt8_union() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let union = a.union(b)
			#expect(union.description == "1|2", "Union should join patterns with '|'")
			if case .alternation(let array) = union {
				#expect(array.count == 2, "Union should contain two elements")
				#expect(array[0].description == "1")
				#expect(array[1].description == "2")
			} else {
				#expect(false, "Union should be a union case")
			}
		}

		@Test("Nested union")
		func test_UInt8_nestedUnion() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let c = SimpleRegex.symbol(3);
			let union1 = a.union(b)
			let union2 = c.union(a)
			let union = union1.union(union2)
			#expect(union.description == "1|2|3", "Nested unions should flatten with '|'")
			if case .alternation(let array) = union {
				#expect(array.count == 3, "Nested union should contain three elements")
			}
		}

		@Test("Concatenation of patterns")
		func test_UInt8_concatenate() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let concat = a.concatenate(b)
			#expect(concat.description == "1.2", "Concatenation should join patterns with '.'")
			if case .concatenation(let array) = concat {
				#expect(array.count == 2, "Concatenation should contain two elements")
				#expect(array[0].description == "1")
				#expect(array[1].description == "2")
			} else {
				#expect(false, "Concatenation should be a concatenate case")
			}
		}

		@Test("Nested concatenation")
		func test_UInt8_nestedConcatenate() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let c = SimpleRegex.symbol(3);
			let concat1 = a.concatenate(b)
			let concat2 = concat1.concatenate(c)
			#expect(concat2.description == "1.2.3", "Nested concatenations should flatten with '.'")
			if case .concatenation(let array) = concat2 {
				#expect(array.count == 3, "Nested concatenation should contain three elements")
			}
		}

		@Test("Kleene star")
		func test_UInt8_star() async throws {
			let a = SimpleRegex.symbol(1);
			let star = a.star()
			#expect(star.description == "1*", "Star should append '*'")
			if case .star(let inner) = star {
				#expect(inner.description == "1", "Star should contain the base pattern")
			} else {
				#expect(false, "Star should be a star case")
			}
		}

		@Test("Precedence: union over concatenation")
		func test_UInt8_precedenceUnionOverConcat() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let c = SimpleRegex.symbol(3);
			let union = a.union(b)
			let concat = union.concatenate(c)
			#expect(concat.description == "(1|2).3", "Union should be parenthesized within concatenation")
		}

		@Test("Precedence: concatenation over star")
		func test_UInt8_precedenceConcatOverStar() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let star = b.star()
			let concat = a.concatenate(star)
			#expect(concat.description == "1.2*", "Star should not be parenthesized within concatenation")
		}

		@Test("Optional pattern")
		func test_UInt8_optional() async throws {
			let a = SimpleRegex.symbol(1);
			let opt = a.optional()
			#expect(opt.description == "ε|1", "Optional should union with epsilon")
			if case .alternation(let array) = opt {
				#expect(array.count == 2)
				#expect(array.contains(where: { $0.description == "ε" }))
				#expect(array.contains(where: { $0.description == "1" }))
			}else{
				#expect(false)
			}
		}

		@Test("Plus pattern")
		func test_UInt8_plus() async throws {
			let a = SimpleRegex.symbol(1);
			let plus = a.plus()
			#expect(plus.description == "1.1*", "Plus should be concatenation with star")
			if case .concatenation(let array) = plus {
				#expect(array.count == 2)
				#expect(array[0].description == "1")
				if case .star(let inner) = array[1] {
					#expect(inner.description == "1")
				}
			}
		}

		@Test("Repeating exact count")
		func test_UInt8_repeatingExact() async throws {
			let a = SimpleRegex.symbol(1);
			let repeat3 = a.repeating(3)
			#expect(repeat3.description == "1.1.1", "Repeating 3 should concatenate three times")
			if case .concatenation(let array) = repeat3 {
				#expect(array.count == 3)
				#expect(array.allSatisfy { $0.description == "1" })
			}
		}

		@Test("Repeating range")
		func test_UInt8_repeatingRange() async throws {
			let a = SimpleRegex.symbol(1);
			let range = a.repeating(1...3)
			#expect(range.description == "1.(ε|1).(ε|1)", "Range 1...3 should include optional parts")
			if case .concatenation(let array) = range {
				#expect(array.count == 3)
				#expect(array[0].description == "1")
				#expect(array[1].description == "ε|1")
				#expect(array[2].description == "ε|1")
			}
		}

		@Test("Repeating at least")
		func test_UInt8_repeatingAtLeast() async throws {
			let a = SimpleRegex.symbol(1);
			let atLeast2 = a.repeating(2...)
			#expect(atLeast2.description == "1.1.1*", "At least 2 should append star")
			if case .concatenation(let array) = atLeast2 {
				#expect(array.count == 3)
				#expect(array[0].description == "1")
				#expect(array[1].description == "1")
				#expect(array[2].description == "1*")
			}
		}

		@Test("Sequence initialization")
		func test_UInt8_sequenceInit() async throws {
			let seq = SimpleRegex([1, 2, 3])
			#expect(seq.description == "1.2.3", "Sequence init should concatenate elements")
			if case .concatenation(let array) = seq {
				#expect(array.count == 3)
				#expect(array.map { $0.description } == ["1", "2", "3"])
			}
		}

		@Test("empty.union(empty)")
		func test_UInt8_empty_union_empty() async throws {
			let seq = SimpleRegex<UInt8>.empty.union(SimpleRegex<UInt8>.empty)
			// Union of two empty sets is empty
			#expect(seq.description == "∅")
		}

		@Test("empty.union(epsilon)")
		func test_UInt8_empty_union_epsilon() async throws {
			let seq = SimpleRegex<UInt8>.empty.union(SimpleRegex<UInt8>.epsilon)
			// Union of of empty set and singleton is singleton
			#expect(seq.description == "ε")
		}

		@Test("empty.union(symbol)")
		func test_UInt8_empty_union_symbol() async throws {
			let seq = SimpleRegex<UInt8>.empty.union(SimpleRegex<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(seq.description == "20")
		}

		@Test("empty.concatenate(empty)")
		func test_UInt8_empty_concatenate_empty() async throws {
			let seq = SimpleRegex<UInt8>.empty.concatenate(SimpleRegex<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(seq.description == "∅")
		}

		@Test("empty.concatenate(epsilon)")
		func test_UInt8_empty_concatenate_epsilon() async throws {
			let seq = SimpleRegex<UInt8>.empty.concatenate(SimpleRegex<UInt8>.epsilon)
			// Concatenation with empty set is empty set
			#expect(seq.description == "∅")
		}

		@Test("empty.concatenate(symbol)")
		func test_UInt8_empty_concatenate_symbol() async throws {
			let seq = SimpleRegex<UInt8>.empty.concatenate(SimpleRegex<UInt8>.symbol(0x20))
			// Concatenation with empty set is empty set
			#expect(seq.description == "∅")
		}

		@Test("empty.star")
		func test_UInt8_empty_star() async throws {
			let seq = SimpleRegex<UInt8>.empty.star()
			// This becomes epsilon, because empty set repeated zero times is epsilon
			#expect(seq.description == "ε")
		}

		@Test("epsilon.union(empty)")
		func test_UInt8_epsilon_union_empty() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.union(SimpleRegex<UInt8>.empty)
			// Union with epsilon contains epsilon
			#expect(seq.description == "ε")
		}

		@Test("epsilon.union(epsilon)")
		func test_UInt8_epsilon_union_epsilon() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.union(SimpleRegex<UInt8>.epsilon)
			// Union with epsilon and itself contains epsilon
			#expect(seq.description == "ε")
		}

		@Test("epsilon.union(symbol)")
		func test_UInt8_epsilon_union_symbol() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.union(SimpleRegex<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(seq.description == "ε|20")
		}

		@Test("epsilon.concatenate(empty)")
		func test_UInt8_epsilon_concatenate_empty() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.concatenate(SimpleRegex<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(seq.description == "∅")
		}

		@Test("epsilon.concatenate(epsilon)")
		func test_UInt8_epsilon_concatenate_epsilon() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.concatenate(SimpleRegex<UInt8>.epsilon)
			// Concatenation with epsilon is itself
			#expect(seq.description == "ε")
		}

		@Test("epsilon.concatenate(symbol)")
		func test_UInt8_epsilon_concatenate_symbol() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.concatenate(SimpleRegex<UInt8>.symbol(0x20))
			// Concatenation with epsilon is itself
			#expect(seq.description == "20")
		}

		@Test("epsilon.star")
		func test_UInt8_epsilon_star() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.star()
			// Nothing never grows adding nothing
			#expect(seq.description == "ε")
		}

		@Test("union(union(union))")
		func test_UInt8_union_nested() async throws {
			let seq = SimpleRegex<UInt8>.union([
				SimpleRegex<UInt8>.union([
					SimpleRegex<UInt8>.union([
						SimpleRegex<UInt8>.symbol(0x20),
					])
				])
			])
			// epsilon* == epsilon
			#expect(seq.description == "20", "Sequence init should concatenate elements")
		}

		@Test("union.star")
		func test_UInt8_union_star() async throws {
			let seq = SimpleRegex<UInt8>.alternation([
				SimpleRegex<UInt8>.symbol(0x20),
				SimpleRegex<UInt8>.symbol(0x21),
			]).star()
			// epsilon* == epsilon
			#expect(seq.description == "(20|21)*", "Sequence init should concatenate elements")
		}

		@Test("concatenate.star")
		func test_UInt8_concatenate_star() async throws {
			let seq = SimpleRegex<UInt8>.epsilon.star()
			// epsilon* == epsilon
			#expect(seq.description == "ε", "Sequence init should concatenate elements")
		}

		@Test("epsilon.star")
		func test_UInt8_symbol_star() async throws {
			let seq = SimpleRegex<UInt8>.symbol(0x20).star()
			#expect(seq.description == "20*", "Sequence init should concatenate elements")
		}
	}

	// Test Suite
	@Suite("alphabet") struct SimpleRegexTests_alphabet {
		@Test("Empty pattern")
		func test_UInt8_empty() async throws {
			let pattern = SimpleRegex<Int>.empty
			#expect(pattern.alphabet == Set([]))
		}

		@Test("Epsilon pattern")
		func test_UInt8_epsilon() async throws {
			let pattern = SimpleRegex<Int>.epsilon
			#expect(pattern.alphabet == Set())
		}

		@Test("Symbol pattern")
		func test_UInt8_symbol() async throws {
			let pattern = SimpleRegex<Int>.symbol(10)
			#expect(pattern.alphabet == Set([10]))
		}

		@Test("Union of patterns")
		func test_UInt8_union() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let pattern = a.union(b)
			#expect(pattern.alphabet == Set([1, 2]))
		}

		@Test("Nested union")
		func test_UInt8_nestedUnion() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let c = SimpleRegex.symbol(3);
			let union1 = a.union(b)
			let union2 = c.union(a)
			let pattern = union1.union(union2)
			#expect(pattern.alphabet == Set([1, 2, 3]))
		}

		@Test("Concatenation of patterns")
		func test_UInt8_concatenate() async throws {
			let a = SimpleRegex.range(1...4);
			let b = SimpleRegex.range(3...6);
			let pattern = a.concatenate(b)
			#expect(Set(1...3) == Set([1,2,3]))
			#expect(pattern.alphabet == Set(1...6))
		}

		@Test("Nested concatenation")
		func test_UInt8_nestedConcatenate() async throws {
			let a = SimpleRegex.range(1...20);
			let b = SimpleRegex.range(2...19);
			let c = SimpleRegex.range(3...18);
			let concat1 = a.concatenate(b)
			let pattern = concat1.concatenate(c)
			#expect(pattern.alphabet == Set(1...20))
		}

		@Test("Kleene star")
		func test_UInt8_star() async throws {
			let a = SimpleRegex.range(1...3);
			let pattern = a.star()
			#expect(pattern.alphabet == Set([1, 2, 3]))
		}

		@Test("Precedence: union over concatenation")
		func test_UInt8_precedenceUnionOverConcat() async throws {
			let a = SimpleRegex.symbol(1);
			let b = SimpleRegex.symbol(2);
			let c = SimpleRegex.symbol(3);
			let union = a.union(b)
			let pattern = union.concatenate(c)
			#expect(pattern.alphabet == Set(1...3))
		}

		@Test("Precedence: concatenation over star")
		func test_UInt8_precedenceConcatOverStar() async throws {
			let a = SimpleRegex.range(1...4);
			let b = SimpleRegex.range(3...6);
			let star = b.star()
			let pattern = a.concatenate(star)
			#expect(pattern.alphabet == Set(1...6))
		}

		@Test("Optional pattern")
		func test_UInt8_optional() async throws {
			let a = SimpleRegex.range(1...3);
			let pattern = a.optional()
			#expect(pattern.alphabet == Set([1, 2, 3]))
		}

		@Test("Plus pattern")
		func test_UInt8_plus() async throws {
			let a = SimpleRegex.symbol(1);
			let pattern = a.plus()
			#expect(pattern.alphabet == Set([1]))
		}

		@Test("Repeating exact count")
		func test_UInt8_repeatingExact() async throws {
			let a = SimpleRegex.symbol(1);
			let pattern = a.repeating(3)
			#expect(pattern.alphabet == Set([1]))
		}

		@Test("Repeating range")
		func test_UInt8_repeatingRange() async throws {
			let a = SimpleRegex.symbol(1);
			let pattern = a.repeating(1...3)
			#expect(pattern.alphabet == Set([1]))
		}

		@Test("Repeating at least")
		func test_UInt8_repeatingAtLeast() async throws {
			let a = SimpleRegex.range(1...3);
			let pattern = a.repeating(2...)
			#expect(pattern.alphabet == Set(1...3))
		}

		@Test("Sequence initialization")
		func test_UInt8_sequenceInit() async throws {
			let pattern = SimpleRegex([1, 2, 3])
			#expect(pattern.alphabet == Set(1...3))
		}

		@Test("empty.union(empty)")
		func test_UInt8_empty_union_empty() async throws {
			let pattern = SimpleRegex<UInt8>.empty.union(SimpleRegex<UInt8>.empty)
			// Union of two empty sets is empty
			#expect(pattern.alphabet == Set([]))
		}

		@Test("empty.union(epsilon)")
		func test_UInt8_empty_union_epsilon() async throws {
			let pattern = SimpleRegex<UInt8>.empty.union(SimpleRegex<UInt8>.epsilon)
			// Union of of empty set and singleton is singleton
			#expect(pattern.alphabet == Set([]))
		}

		@Test("empty.union(symbol)")
		func test_UInt8_empty_union_symbol() async throws {
			let pattern = SimpleRegex<UInt8>.empty.union(SimpleRegex<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(pattern.alphabet == Set([0x20]))
		}

		@Test("empty.concatenate(empty)")
		func test_UInt8_empty_concatenate_empty() async throws {
			let pattern = SimpleRegex<UInt8>.empty.concatenate(SimpleRegex<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
		}

		@Test("empty.concatenate(epsilon)")
		func test_UInt8_empty_concatenate_epsilon() async throws {
			let pattern = SimpleRegex<UInt8>.empty.concatenate(SimpleRegex<UInt8>.epsilon)
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
		}

		@Test("empty.concatenate(symbol)")
		func test_UInt8_empty_concatenate_symbol() async throws {
			let pattern = SimpleRegex<UInt8>.empty.concatenate(SimpleRegex<UInt8>.symbol(0x20))
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
		}

		@Test("empty.star")
		func test_UInt8_empty_star() async throws {
			let pattern = SimpleRegex<UInt8>.empty.star()
			// This becomes epsilon, because empty set repeated zero times is epsilon
			#expect(pattern.alphabet == Set([]))
		}

		@Test("epsilon.union(empty)")
		func test_UInt8_epsilon_union_empty() async throws {
			let pattern = SimpleRegex<UInt8>.epsilon.union(SimpleRegex<UInt8>.empty)
			// Union with epsilon contains epsilon
			#expect(pattern.alphabet == Set([]))
		}

		@Test("epsilon.union(epsilon)")
		func test_UInt8_epsilon_union_epsilon() async throws {
			let pattern = SimpleRegex<UInt8>.epsilon.union(SimpleRegex<UInt8>.epsilon)
			// Union with epsilon and itself contains epsilon
			#expect(pattern.alphabet == Set([]))
		}

		@Test("epsilon.union(symbol)")
		func test_UInt8_epsilon_union_symbol() async throws {
			let pattern = SimpleRegex<UInt8>.epsilon.union(SimpleRegex<UInt8>.symbol(0x20))
			// Union of of empty set and singleton is singleton
			#expect(pattern.alphabet == Set([0x20]))
		}

		@Test("epsilon.concatenate(empty)")
		func test_UInt8_epsilon_concatenate_empty() async throws {
			let pattern = SimpleRegex<UInt8>.epsilon.concatenate(SimpleRegex<UInt8>.empty)
			// Concatenation with empty set is empty set
			#expect(pattern.alphabet == Set([]))
		}

		@Test("epsilon.concatenate(epsilon)")
		func test_UInt8_epsilon_concatenate_epsilon() async throws {
			let pattern = SimpleRegex<UInt8>.epsilon.concatenate(SimpleRegex<UInt8>.epsilon)
			// Concatenation with epsilon is itself
			#expect(pattern.alphabet == Set([]))
		}

		@Test("epsilon.concatenate(symbol)")
		func test_UInt8_epsilon_concatenate_symbol() async throws {
			let pattern = SimpleRegex<UInt8>.epsilon.concatenate(SimpleRegex<UInt8>.symbol(0x20))
			// Concatenation with epsilon is itself
			#expect(pattern.alphabet == Set([0x20]))
		}

		@Test("epsilon.star")
		func test_UInt8_epsilon_star() async throws {
			let pattern = SimpleRegex<UInt8>.epsilon.star()
			// Nothing never grows adding nothing
			#expect(pattern.alphabet == Set([]))
		}

		@Test("union(union(union))")
		func test_UInt8_union_nested() async throws {
			let pattern = SimpleRegex<UInt8>.union([
				SimpleRegex<UInt8>.union([
					SimpleRegex<UInt8>.union([
						SimpleRegex<UInt8>.symbol(0x20),
					]),
					SimpleRegex<UInt8>.symbol(0x21),
				]),
				SimpleRegex<UInt8>.symbol(0x22),
			])
			#expect(pattern.alphabet == Set(0x20...0x22))
		}

		@Test("union.star")
		func test_UInt8_union_star() async throws {
			let pattern = SimpleRegex<UInt8>.alternation([
				SimpleRegex<UInt8>.symbol(0x20),
				SimpleRegex<UInt8>.symbol(0x21),
			]).star()
			#expect(pattern.alphabet == Set(0x20...0x21))
		}

		@Test("epsilon.star")
		func test_UInt8_symbol_star() async throws {
			let pattern = SimpleRegex<UInt8>.range(0x30...0x39).star()
			#expect(pattern.alphabet == Set(0x30...0x39))
		}
	}
}
