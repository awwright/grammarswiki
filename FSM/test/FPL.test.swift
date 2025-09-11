// Tests for FPL (), to see how well this works and models operations on generalized partitioned languages

@testable import FSM
import Testing

private typealias StringFPL = FPL<Character>
private typealias StringAlphabet = StringFPL.Alphabet

private func set(_ strs: String...) -> Set<Array<Character>>{
	Set(strs.map { Array($0) });
}

@Suite() struct FPLTests {
	@Test()
	func test_init() {
		let empty = StringFPL.empty
		#expect(empty.elements.isEmpty)
		#expect(empty.partitions.isEmpty)

		let epsilon = StringFPL.epsilon
		#expect(epsilon.elements == Set([[]]))
	}

	@Test
	func test_init_arrayLiteral() {
		let lang: StringFPL = [ set("ab", "c") ]
		#expect(lang.elements == Set([Array("ab"), Array("c")]))
		#expect(lang.partitions == SetAlphabet(partitions: [ set("ab", "c") ]))
	}

	@Test
	func test_init_elements() {
		let lang = StringFPL(elements: Set([Array("ab"), Array("c")]))
		#expect(lang.elements == Set([Array("ab"), Array("c")]))
		#expect(lang.partitions == SetAlphabet(partitions: [Set([Array("ab"), Array("c")])]))
	}

	@Test
	func test_eq() {
		let a: StringFPL = [ set("a") ]
		let b: StringFPL = [ set("a") ]
		#expect(a == b)

		let c = StringFPL(elements: Set([Array("b")]))
		#expect(a != c)

		let empty = StringFPL.empty
		#expect(empty == StringFPL())
	}

	@Test
	func test_contains_array_symbols() {
		let lang = StringFPL(elements: [Array("ab"), Array("c")])
		#expect(lang.contains(Array("ab")))
		#expect(!lang.contains(Array("d")))

		let empty = StringFPL.empty
		#expect(!empty.contains([]))
	}

	@Test
	func test_contains_sequence_symbols() {
		let lang = StringFPL(elements: [Array("ab"), Array("c")])
		#expect(lang.contains("ab"))
		#expect(lang.contains("c"))
		#expect(!lang.contains("d"))

		let epsilon = StringFPL.epsilon
		#expect(epsilon.contains(""))
		#expect(!epsilon.contains("a"))
	}

	@Test
	func test_union() {
		let a = StringFPL(elements: Set([Array("a")]))
		let b = StringFPL(elements: Set([Array("b")]))
		let union = a.union(b)
		#expect(union.elements == Set([Array("a"), Array("b")]))
	}

	@Test
	func test_intersection() {
		let a = StringFPL(elements: Set([Array("a"), Array("b")]))
		let b = StringFPL(elements: Set([Array("b"), Array("c")]))
		let intersection = a.intersection(b)
		#expect(intersection.elements == Set([Array("b")]))
	}

	@Test
	func test_symmetricDifference() {
		let a = StringFPL(elements: Set([Array("a"), Array("b")]))
		let b = StringFPL(elements: Set([Array("b"), Array("c")]))
		let diff = a.symmetricDifference(b)
		#expect(diff.elements == Set([Array("a"), Array("c")]))
	}

	@Test
	func test_static_union() {
		let a = StringFPL(elements: Set([Array("a")]))
		let b = StringFPL(elements: Set([Array("b")]))
		let union = StringFPL.union([a, b])
		#expect(union.elements == Set([Array("a"), Array("b")]))
	}

	@Test
	func test_static_concatenate() {
		let a = StringFPL(elements: Set([Array("a"), Array("b")]))
		let b = StringFPL(elements: Set([Array("c"), Array("d")]))
		let concat = StringFPL.concatenate([a, b])
		#expect(concat.elements == Set([Array("ac"), Array("ad"), Array("bc"), Array("bd")]))
	}

	@Test
	func test_concatenate_1() {
		let a: StringFPL = [ set("A", "a") ]
		let b: StringFPL = [ set("B", "b") ]
		let concat = a.concatenate(b)
		#expect(concat.partitions == StringAlphabet(partitions: [
			set("AB", "Ab", "aB", "ab"),
		]));
	}

	@Test
	func test_concatenate_2() {
		let a: StringFPL = [ set("A", "a"), set("B", "b") ]
		let b: StringFPL = [ set("C", "c") ]
		let concat = a.concatenate(b)
		#expect(concat.partitions == StringAlphabet(partitions: [
			set("AC", "Ac", "aC", "ac"),
			set("BC", "Bc", "bC", "bc"),
		]))
	}

	@Test
	func test_concatenate_4() {
		let a: StringFPL = [ set("A", "a"), set("B", "b") ]
		let b: StringFPL = [ set("C", "c"), set("D", "d") ]
		let concat = a.concatenate(b)
		#expect(concat.partitions == StringAlphabet(partitions: [
			set("AC", "Ac", "aC", "ac"),
			set("AD", "Ad", "aD", "ad"),
			set("BC", "Bc", "bC", "bc"),
			set("BD", "Bd", "bD", "bd"),
		]))
	}

	@Test
	static func test_symbol() {
		let lang = StringFPL.symbol("a".first!)
		#expect(lang.elements == Set([Array("a")]))
	}

	@Test
	static func test_symbol_range() {
		// Since Character not Strideable, but function is same as symbol
		let lang = StringFPL.symbol(range: "a".first!)
		#expect(lang.elements == Set([Array("a")]))
	}

	@Test
	func test_optional() {
		let lang = StringFPL.symbol("a".first!)
		let opt = lang.optional()
		#expect(opt.elements == Set([[], Array("a")]))
	}

	@Test
	func test_star() {
		// star fatalErrors if non-empty
//		let lang = StringFPL.symbol("a".first!).plus()
//		let starred = lang.star()
//		#expect(starred.contains(""))
//		#expect(starred.contains("a"))
//		#expect(starred.contains("aa"))
//		#expect(starred.contains("aaa"))
	}

	@Test
	func test_plus() {
//		let lang = StringFPL.symbol("a".first!)
//		let plus = lang.plus()
//		#expect(!plus.contains(""))
//		#expect(plus.contains("a"))
//		#expect(plus.contains("aa"))
//		#expect(plus.contains("aaa"))
	}

	@Test
	func test_repeating_int() {
		let lang = StringFPL.symbol("a".first!)
		let rep = lang.repeating(3)
		#expect(rep.contains("aaa"))
		#expect(!rep.contains("aa"))
		#expect(!rep.contains("aaaa"))
	}

	@Test
	func test_repeating_range() {
		let lang = StringFPL.symbol("a".first!)
		let rep = lang.repeating(2...4)
		#expect(rep.contains("aa"))
		#expect(rep.contains("aaa"))
		#expect(rep.contains("aaaa"))
		#expect(!rep.contains("a"))
		#expect(!rep.contains("aaaaa"))
	}

	@Test
	func test_reversed() {
		let lang = StringFPL(elements: Set([Array("ab"), Array("cd")]))
		let rev = lang.reversed()
		#expect(rev.elements == Set([Array("ba"), Array("dc")]))
	}

	@Test
	func test_derive_string() {
		let lang = StringFPL(elements: Set([Array("abc"), Array("ad")]))
		let derived = lang.derive(Array("a"))
		#expect(derived.elements == Set([Array("bc"), Array("d")]))
	}

	@Test
	func test_derive_language() {
		let lang = StringFPL(elements: Set([Array("abc"), Array("ad"), Array("e")]))
		let prefixes = StringFPL(elements: Set([Array("a"), Array("e")]))
		let derived = lang.derive(prefixes)
		#expect(derived.elements == Set([[], Array("bc"), Array("d")]))
	}

	@Test
	func test_dock() {
		let lang = StringFPL(elements: Set([Array("abc"), Array("dbc")]))
		let suffixes = StringFPL(elements: Set([Array("bc")]))
		let docked = lang.dock(suffixes)
		#expect(docked.elements == Set([Array("a"), Array("d")]))
	}

	@Test
	func test_prefixes() {
		let lang = StringFPL(elements: Set([Array("ab"), Array("a"), Array("abc"), Array("c")]))
		let prefixes = lang.prefixes()
		#expect(prefixes.elements == Set([Array("a"), Array("c")]))
	}

	@Test
	func test_toPattern() {
		let lang = StringFPL.symbol("a".first!).union(StringFPL.symbol("b".first!))
		let pattern = lang.toPattern(as: SymbolDFA<Character>.self)
		#expect(pattern.contains("a"))
		#expect(pattern.contains("b"))
		#expect(!pattern.contains("c"))
	}

	@Test
	func test_insert() {
		var lang = StringFPL(elements: Set([Array("a")]))
		let (inserted, member) = lang.insert(Array("b"))
		#expect(inserted)
		#expect(member == Array("b"))
		#expect(lang.elements == Set([Array("a"), Array("b")]))
	}

	@Test
	func test_remove() {
		var lang = StringFPL(elements: Set([Array("a"), Array("b")]))
		let removed = lang.remove(Array("a"))
		#expect(removed == Array("a"))
		#expect(lang.elements == Set([Array("b")]))
	}

	@Test
	func test_update() {
		var lang = StringFPL(elements: Set([Array("a")]))
		let updated = lang.update(with: Array("b"))
		#expect(updated == nil)
		#expect(lang.elements == Set([Array("a"), Array("b")]))
	}

	@Test
	static func test_minus(){
		let a = StringFPL(elements: Set([Array("a"), Array("b")]))
		let b = StringFPL(elements: Set([Array("b"), Array("c")]))
		let diff = a - b
		#expect(diff.elements == Set([Array("a")]))
	}
}
