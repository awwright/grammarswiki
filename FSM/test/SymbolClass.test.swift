import Testing;
@testable import FSM

// Test Suite
@Suite("SymbolClass") struct SymbolClassTests {
	@Suite("partitionReduce") struct SymbolClassTests_partitionReduce {
		@Test("empty") func test_partitionReduce_empty() async throws {
			let alphabets = [
				Set<Int>([ ]),
			];
			let partitions = alphabetCombine(alphabets)
			#expect(partitions == Set<Set<Int>>([]))
		}
		@Test("single symbol") func test_partitionReduce_single() async throws {
			let alphabets = [
				Set<Int>([1]),
			];
			let partitions = alphabetCombine(alphabets)
			#expect(partitions == Set<Set<Int>>([ Set<Int>([1]) ]))
		}
		@Test("single set multi-symbol") func test_partitionReduce_multi() async throws {
			let alphabets = [
				Set<Int>([0, 1, 2]),
			];
			let partitions = alphabetCombine(alphabets)
			#expect(partitions == Set<Set<Int>>([ Set<Int>([0, 1, 2]) ]))
		}
		@Test("alphabet ^ hexdig") func test_partitionReduce_char() async throws {
			let alphabets: Array<Set<Character>> = [
				Set(Array("a"..."z")),
				Set(Array("0"..."9") + Array("a"..."f")),
			];
			let partitions = alphabetCombine(alphabets);
			#expect(partitions == Set([ Set("0"..."9"), Set("a"..."f"), Set("g"..."z") ]))
		}
	}
}
