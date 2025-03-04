import Testing;
@testable import FSM

// Test Suite
@Suite("SimpleRegex Tests") struct SimpleRegexTests {
	let a = SimpleRegex.symbol(1)
	let b = SimpleRegex.symbol(2)
	let c = SimpleRegex.symbol(3)

	@Test("Empty pattern")
	func test_SimpleRegex_empty() async throws {
		let empty = SimpleRegex<Int>.empty
		#expect(empty.description == "∅", "Empty pattern should be represented as ∅")
		if case .union(let array) = empty {
			#expect(array.isEmpty, "Empty pattern should be an empty union")
		} else {
			#expect(false, "Empty pattern should be a union with no alternates")
		}
	}

	@Test("Epsilon pattern")
	func test_SimpleRegex_epsilon() async throws {
		let epsilon = SimpleRegex<Int>.epsilon
		#expect(epsilon.description == "ε", "Epsilon pattern should be represented as ε")
		if case .concatenate(let array) = epsilon {
			#expect(array.isEmpty, "Epsilon pattern should be an empty concatenation")
		} else {
			#expect(false, "Epsilon pattern should be a concatenation with no elements")
		}
	}

	@Test("CodePoint pattern")
	func test_SimpleRegex_symbol() async throws {
		let pattern = SimpleRegex<Int>.symbol(10)
		#expect(pattern.description == "a", "CodePoint 10 should be 'a' in hex")
		if case .symbol(let value) = pattern {
			#expect(value == 10, "CodePoint should store the correct value")
		} else {
			#expect(false, "CodePoint pattern should be a symbol case")
		}
	}

	@Test("Union of patterns")
	func test_SimpleRegex_union() async throws {
		let union = a.union(b)
		#expect(union.description == "1|2", "Union should join patterns with '|'")
		if case .union(let array) = union {
			#expect(array.count == 2, "Union should contain two elements")
			#expect(array[0].description == "1")
			#expect(array[1].description == "2")
		} else {
			#expect(false, "Union should be a union case")
		}
	}

	@Test("Nested union")
	func test_SimpleRegex_nestedUnion() async throws {
		let union1 = a.union(b)
		let union2 = union1.union(c)
		#expect(union2.description == "1|2|3", "Nested unions should flatten with '|'")
		if case .union(let array) = union2 {
			#expect(array.count == 3, "Nested union should contain three elements")
		}
	}

	@Test("Concatenation of patterns")
	func test_SimpleRegex_concatenate() async throws {
		let concat = a.concatenate(b)
		#expect(concat.description == "1.2", "Concatenation should join patterns with '.'")
		if case .concatenate(let array) = concat {
			#expect(array.count == 2, "Concatenation should contain two elements")
			#expect(array[0].description == "1")
			#expect(array[1].description == "2")
		} else {
			#expect(false, "Concatenation should be a concatenate case")
		}
	}

	@Test("Nested concatenation")
	func test_SimpleRegex_nestedConcatenate() async throws {
		let concat1 = a.concatenate(b)
		let concat2 = concat1.concatenate(c)
		#expect(concat2.description == "1.2.3", "Nested concatenations should flatten with '.'")
		if case .concatenate(let array) = concat2 {
			#expect(array.count == 3, "Nested concatenation should contain three elements")
		}
	}

	@Test("Kleene star")
	func test_SimpleRegex_star() async throws {
		let star = a.star()
		#expect(star.description == "1*", "Star should append '*'")
		if case .star(let inner) = star {
			#expect(inner.description == "1", "Star should contain the base pattern")
		} else {
			#expect(false, "Star should be a star case")
		}
	}

	@Test("Precedence: union over concatenation")
	func test_SimpleRegex_precedenceUnionOverConcat() async throws {
		let union = a.union(b)
		let concat = union.concatenate(c)
		#expect(concat.description == "(1|2).3", "Union should be parenthesized within concatenation")
	}

	@Test("Precedence: concatenation over star")
	func test_SimpleRegex_precedenceConcatOverStar() async throws {
		let star = b.star()
		let concat = a.concatenate(star)
		#expect(concat.description == "1.2*", "Star should not be parenthesized within concatenation")
	}

	@Test("Optional pattern")
	func test_SimpleRegex_optional() async throws {
		let opt = a.optional()
		#expect(opt.description == "ε|1", "Optional should union with epsilon")
		if case .union(let array) = opt {
			#expect(array.count == 2)
			#expect(array.contains(where: { $0.description == "ε" }))
			#expect(array.contains(where: { $0.description == "1" }))
		}
	}

	@Test("Plus pattern")
	func test_SimpleRegex_plus() async throws {
		let plus = a.plus()
		print(plus.description)
		#expect(plus.description == "1.1*", "Plus should be concatenation with star")
		if case .concatenate(let array) = plus {
			#expect(array.count == 2)
			#expect(array[0].description == "1")
			if case .star(let inner) = array[1] {
				#expect(inner.description == "1")
			}
		}
	}

	@Test("Repeating exact count")
	func test_SimpleRegex_repeatingExact() async throws {
		let repeat3 = a.repeating(3)
		#expect(repeat3.description == "1.1.1", "Repeating 3 should concatenate three times")
		if case .concatenate(let array) = repeat3 {
			#expect(array.count == 3)
			#expect(array.allSatisfy { $0.description == "1" })
		}
	}

	@Test("Repeating range")
	func test_SimpleRegex_repeatingRange() async throws {
		let range = a.repeating(1...3)
		#expect(range.description == "1.(ε|1).(ε|1)", "Range 1...3 should include optional parts")
		if case .concatenate(let array) = range {
			#expect(array.count == 3)
			#expect(array[0].description == "1")
			#expect(array[1].description == "ε|1")
			#expect(array[2].description == "ε|1")
		}
	}

	@Test("Repeating at least")
	func test_SimpleRegex_repeatingAtLeast() async throws {
		let atLeast2 = a.repeating(2...)
		#expect(atLeast2.description == "1.1.1*", "At least 2 should append star")
		if case .concatenate(let array) = atLeast2 {
			#expect(array.count == 3)
			#expect(array[0].description == "1")
			#expect(array[1].description == "1")
			#expect(array[2].description == "1*")
		}
	}

	@Test("Sequence initialization")
	func test_SimpleRegex_sequenceInit() async throws {
		let seq = SimpleRegex([1, 2, 3])
		#expect(seq.description == "1.2.3", "Sequence init should concatenate elements")
		if case .concatenate(let array) = seq {
			#expect(array.count == 3)
			#expect(array.map { $0.description } == ["1", "2", "3"])
		}
	}
}


