import Testing;
@testable import FSM

// Test Suite
@Suite("SymbolClass functions") struct SymbolClassFunctionsTests {
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
		@Test("alphabet ^ hexdig") func test_partitionReduce_char2() async throws {
			let alphabets: Array<Set<Character>> = [
				Set(Array("0"..."1")),
				Set(Array("a"..."z")),
				Set(Array("0"..."9") + Array("a"..."f")),
				Set(Array("0"..."9") + Array("a"..."z")),
			];
			let partitions = alphabetCombine(alphabets);
			#expect(partitions == Set([ Set("0"..."1"), Set("2"..."9"), Set("a"..."f"), Set("g"..."z") ]))
		}
	}
}

@Suite("SymbolPartitionedSet") struct SymbolPartitionedSetTests {
	@Suite("contains") struct SymbolPartitionedSet_partitionReduce {
		@Test("array literal") func test_array_literal() async throws {
			let partitions: SymbolPartitionedSet<Int> = [[0, 1]]
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("init ranges") func test_partitionReduce_empty() async throws {
			let partitions: SymbolPartitionedSet<Int> = []
			#expect(!partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single symbol") func test_partitionReduce_single() async throws {
			let partitions: SymbolPartitionedSet<Int> = [ [1] ]
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single set multi-symbol") func test_partitionReduce_multi() async throws {
			let partitions: SymbolPartitionedSet<Int> = [ [0, 1, 2] ]
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(partitions.contains(2))
			#expect(!partitions.contains(3))
		}
		@Test("range of values") func test_contains_range() async throws {
			let partitions: SymbolPartitionedSet<Int> = [ Array(0x30...0x39) ]
			#expect(!partitions.contains(0x2F))
			#expect(partitions.contains(0x30))
			#expect(partitions.contains(0x31))
			#expect(partitions.contains(0x38))
			#expect(partitions.contains(0x39))
			#expect(!partitions.contains(0x3A))
		}
	}
	@Suite("isEquivalent") struct SymbolPartitionedSetTests_isEquivalent {
		@Test("single symbol") func test__single() async throws {
			let partitions: SymbolPartitionedSet<Int> = [ [1] ]
			#expect(partitions.isEquivalent(1, 1))
		}
		@Test("single part multi-symbol") func test_isEquivalent_2() async throws {
			let partitions: SymbolPartitionedSet<Int> = [ [0, 1, 2] ]
			#expect(partitions.isEquivalent(0, 1))
		}
		@Test("multi-part") func test_isEquivalent_3() async throws {
			let partitions: SymbolPartitionedSet<Int> = [ [0, 2, 4], [1, 3, 5] ]
			#expect(!partitions.isEquivalent(0, 1))
			#expect(partitions.isEquivalent(0, 2))
			#expect(partitions.isEquivalent(1, 5))
		}
	}
	@Suite("set operations") struct SymbolPartitionedSetTests_SetAlgebra {
		@Test("empty") func test_single() async throws {
			let partitions = SymbolPartitionedSet<Int>.empty
			#expect(partitions.symbols == [])
			#expect(partitions.partitions == [])
		}
		@Test("epsilon") func test_epsilon() async throws {
			let partitions = SymbolPartitionedSet<Int>.epsilon
			#expect(partitions.symbols == [])
			#expect(partitions.partitions == [])
		}
		@Test("symbol") func test_symbol() async throws {
			let partitions = SymbolPartitionedSet<Int>.symbol(1)
			#expect(partitions.symbols == [1])
			#expect(partitions.partitions == [ [1] ])
		}
		@Test("union of concatenation") func test_union2() async throws {
			let partitions = SymbolPartitionedSet.union([
				SymbolPartitionedSet.union([ SymbolPartitionedSet.symbol(1) ])
			])
			#expect(partitions.symbols == [])
			#expect(partitions.partitions == [])
		}
	}
}

@Suite("SymbolClass") struct SymbolClassTests {
	@Suite("contains") struct SymbolClassTests_partitionReduce {
		@Test("array literal") func test_array_literal() async throws {
			let partitions: SymbolClass<Int> = [0, 1]
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("init ranges") func test_partitionReduce_empty() async throws {
			let partitions: SymbolClass<Int> = []
			#expect(!partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single symbol") func test_partitionReduce_single() async throws {
			let partitions = SymbolClass<Int>([ 1 ])
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single set multi-symbol") func test_partitionReduce_multi() async throws {
			let partitions = SymbolClass<Int>([0, 1, 2])
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(partitions.contains(2))
			#expect(!partitions.contains(3))
		}
		@Test("range of values") func test_contains_range() async throws {
			let partitions = SymbolClass<Int>(0x30...0x39)
			#expect(!partitions.contains(0x2F))
			#expect(partitions.contains(0x30))
			#expect(partitions.contains(0x31))
			#expect(partitions.contains(0x38))
			#expect(partitions.contains(0x39))
			#expect(!partitions.contains(0x3A))
		}
		@Test("two ranges of values") func test_contains_ranges() async throws {
			let partitions = SymbolClass<Int>([0x41...0x5A], [0x61...0x7A])
			#expect(!partitions.contains(0x40))
			#expect(partitions.contains(0x41))
			#expect(partitions.contains(0x42))
			#expect(partitions.contains(0x59))
			#expect(partitions.contains(0x5A))
			#expect(!partitions.contains(0x5B))
			#expect(!partitions.contains(0x60))
			#expect(partitions.contains(0x61))
			#expect(partitions.contains(0x62))
			#expect(partitions.contains(0x79))
			#expect(partitions.contains(0x7A))
			#expect(!partitions.contains(0x7B))
		}
		@Test("three ranges of values") func test_contains_ranges3() async throws {
			let partitions = SymbolClass<Int>([0x30...0x39], [0x41...0x5A], [0x61...0x7A])
			#expect(!partitions.contains(0x2F))
			#expect(partitions.contains(0x30))
			#expect(partitions.contains(0x31))
			#expect(partitions.contains(0x38))
			#expect(partitions.contains(0x39))
			#expect(!partitions.contains(0x3A))
			#expect(!partitions.contains(0x40))
			#expect(partitions.contains(0x41))
			#expect(partitions.contains(0x42))
			#expect(partitions.contains(0x59))
			#expect(partitions.contains(0x5A))
			#expect(!partitions.contains(0x5B))
			#expect(!partitions.contains(0x60))
			#expect(partitions.contains(0x61))
			#expect(partitions.contains(0x62))
			#expect(partitions.contains(0x79))
			#expect(partitions.contains(0x7A))
			#expect(!partitions.contains(0x7B))
		}
	}
	@Suite("get partition label") struct SymbolClassTests_getPartitionLabel {
		@Test("three partitions") func test_three_parts() async throws {
			let partitions = SymbolClass<Int>([0, 1, 2], [3, 4, 5], [6, 7, 8])
			#expect(partitions.getPartitionLabel(0) == 0)
			#expect(partitions.getPartitionLabel(1) == 0)
			#expect(partitions.getPartitionLabel(2) == 0)
			#expect(partitions.getPartitionLabel(3) == 3)
			#expect(partitions.getPartitionLabel(4) == 3)
			#expect(partitions.getPartitionLabel(5) == 3)
			#expect(partitions.getPartitionLabel(6) == 6)
			#expect(partitions.getPartitionLabel(7) == 6)
			#expect(partitions.getPartitionLabel(8) == 6)
		}
		@Test("three ranges") func test_three_parts_ranges() async throws {
			let partitions = SymbolClass<Int>([0...2], [3...4, 5...5], [6...7, 7...7, 8...8])
			#expect(partitions.getPartitionLabel(0) == 0)
			#expect(partitions.getPartitionLabel(1) == 0)
			#expect(partitions.getPartitionLabel(2) == 0)
			#expect(partitions.getPartitionLabel(3) == 3)
			#expect(partitions.getPartitionLabel(4) == 3)
			#expect(partitions.getPartitionLabel(5) == 3)
			#expect(partitions.getPartitionLabel(6) == 6)
			#expect(partitions.getPartitionLabel(7) == 6)
			#expect(partitions.getPartitionLabel(8) == 6)
		}
		@Test("single symbol") func test_partitionReduce_single() async throws {
			let partitions = SymbolClass<Int>([ 1 ])
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single set multi-symbol") func test_partitionReduce_multi() async throws {
			let partitions = SymbolClass<Int>([0, 1, 2])
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(partitions.contains(2))
			#expect(!partitions.contains(3))
		}
		@Test("range of values") func test_contains_range() async throws {
			let partitions = SymbolClass<Int>(0x30...0x39)
			#expect(!partitions.contains(0x2F))
			#expect(partitions.contains(0x30))
			#expect(partitions.contains(0x31))
			#expect(partitions.contains(0x38))
			#expect(partitions.contains(0x39))
			#expect(!partitions.contains(0x3A))
		}
	}
	@Suite("isEquivalent") struct SymbolClassTests_isEquivalent {
		@Test("single symbol") func test__single() async throws {
			let partitions = SymbolClass<Int>([ 1 ])
			#expect(partitions.isEquivalent(1, 1))
		}
		@Test("single set multi-symbol") func test_isEquivalent_multi() async throws {
			let partitions = SymbolClass<Int>([0, 1, 2])
			#expect(partitions.isEquivalent(0, 1))
		}
	}
	@Suite("meet") struct SymbolClassTests_meet {
		@Test("two nested partitions") func test_two_nested_parts() async throws {
			let part1 = SymbolClass<Int>([ 0x30...0x39 ])
			let part2 = SymbolClass<Int>([ 0x32 ])
			let partitions = part1.meet(part2)
			#expect(partitions.getPartitionLabel(0x30) == 0x30)
			#expect(partitions.getPartitionLabel(0x31) == 0x30)
			#expect(partitions.getPartitionLabel(0x32) == 0x32)
			#expect(partitions.getPartitionLabel(0x33) == 0x30)
			#expect(partitions.getPartitionLabel(0x34) == 0x30)
			#expect(partitions.getPartitionLabel(0x35) == 0x30)
			#expect(partitions.getPartitionLabel(0x36) == 0x30)
			#expect(partitions.getPartitionLabel(0x37) == 0x30)
			#expect(partitions.getPartitionLabel(0x38) == 0x30)
		}
		@Test("two nested partitions (range)") func test_two_nested_parts_range() async throws {
			let part1 = SymbolClass<Int>([ 0x30...0x39 ])
			let part2 = SymbolClass<Int>([ 0x32...0x35 ])
			let partitions = part1.meet(part2)
			#expect(partitions.getPartitionLabel(0x30) == 0x30)
			#expect(partitions.getPartitionLabel(0x31) == 0x30)
			#expect(partitions.getPartitionLabel(0x32) == 0x32)
			#expect(partitions.getPartitionLabel(0x33) == 0x32)
			#expect(partitions.getPartitionLabel(0x34) == 0x32)
			#expect(partitions.getPartitionLabel(0x35) == 0x32)
			#expect(partitions.getPartitionLabel(0x36) == 0x30)
			#expect(partitions.getPartitionLabel(0x37) == 0x30)
			#expect(partitions.getPartitionLabel(0x38) == 0x30)
		}
		@Test("two overlapping partitions") func test_two_overlapping_parts() async throws {
			let part1 = SymbolClass<Int>([ 0x30...0x35 ])
			let part2 = SymbolClass<Int>([ 0x32...0x39 ])
			let partitions = part1.meet(part2)
			print(partitions.symbols)
			#expect(partitions.getPartitionLabel(0x30) == 0x30)
			#expect(partitions.getPartitionLabel(0x31) == 0x30)
			#expect(partitions.getPartitionLabel(0x32) == 0x32)
			#expect(partitions.getPartitionLabel(0x33) == 0x32)
			#expect(partitions.getPartitionLabel(0x34) == 0x32)
			#expect(partitions.getPartitionLabel(0x35) == 0x32)
			#expect(partitions.getPartitionLabel(0x36) == 0x36)
			#expect(partitions.getPartitionLabel(0x37) == 0x36)
			#expect(partitions.getPartitionLabel(0x38) == 0x36)
		}
		@Test("two disjoint partitions") func test_two_disjoint_parts() async throws {
			let part1 = SymbolClass<Int>([ 0x30...0x32 ])
			let part2 = SymbolClass<Int>([ 0x35...0x39 ])
			let partitions = part1.meet(part2)
			#expect(partitions.getPartitionLabel(0x30) == 0x30)
			#expect(partitions.getPartitionLabel(0x31) == 0x30)
			#expect(partitions.getPartitionLabel(0x32) == 0x30)
			#expect(!partitions.contains(0x33))
			#expect(!partitions.contains(0x34))
			#expect(partitions.getPartitionLabel(0x35) == 0x35)
			#expect(partitions.getPartitionLabel(0x36) == 0x35)
			#expect(partitions.getPartitionLabel(0x37) == 0x35)
			#expect(partitions.getPartitionLabel(0x38) == 0x35)
		}
		@Test("3 partitions") func test_3_parts() async throws {
			let part1 = SymbolClass<Int>([ 0x30...0x36 ])
			let part2 = SymbolClass<Int>([ 0x32...0x34 ])
			let part3 = SymbolClass<Int>([ 0x33...0x39 ])
			let partitions = SymbolClass<Int>.meet([part1, part2, part3])
			#expect(partitions.getPartitionLabel(0x30) == 0x30)
			#expect(partitions.getPartitionLabel(0x31) == 0x30)
			#expect(partitions.getPartitionLabel(0x32) == 0x32)
			#expect(partitions.getPartitionLabel(0x33) == 0x33)
			#expect(partitions.getPartitionLabel(0x34) == 0x33)
			#expect(partitions.getPartitionLabel(0x35) == 0x35)
			#expect(partitions.getPartitionLabel(0x36) == 0x35)
			#expect(partitions.getPartitionLabel(0x37) == 0x37)
			#expect(partitions.getPartitionLabel(0x38) == 0x37)
			#expect(partitions.getPartitionLabel(0x39) == 0x37)
		}
		@Test("4 partitions") func test_4_parts() async throws {
			let part1 = SymbolClass<Int>([ 0x30...0x36 ])
			let part2 = SymbolClass<Int>([ 0x32...0x34 ])
			let part3 = SymbolClass<Int>([ 0x33...0x38 ])
			let part4 = SymbolClass<Int>([ 0x30...0x39 ])
			let partitions = SymbolClass<Int>.meet([part1, part2, part3, part4])
			#expect(partitions.getPartitionLabel(0x30) == 0x30)
			#expect(partitions.getPartitionLabel(0x31) == 0x30)
			#expect(partitions.getPartitionLabel(0x32) == 0x32)
			#expect(partitions.getPartitionLabel(0x33) == 0x33)
			#expect(partitions.getPartitionLabel(0x34) == 0x33)
			#expect(partitions.getPartitionLabel(0x35) == 0x35)
			#expect(partitions.getPartitionLabel(0x36) == 0x35)
			#expect(partitions.getPartitionLabel(0x37) == 0x37)
			#expect(partitions.getPartitionLabel(0x38) == 0x37)
			#expect(partitions.getPartitionLabel(0x39) == 0x39)
		}
	}
}
