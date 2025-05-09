import Testing;
@testable import FSM

@Suite("SymbolClass") struct SymbolClassTests {
	@Suite("contains") struct SymbolClassTests_partitionReduce {
		@Test("array literal") func test_array_literal() async throws {
			let partitions: SetAlphabet<Int> = [[0], [1]]
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("init ranges") func test_partitionReduce_empty() async throws {
			let partitions: SetAlphabet<Int> = []
			#expect(!partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single symbol") func test_partitionReduce_single() async throws {
			let partitions: SetAlphabet<Int> = [ [1] ]
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single set multi-symbol") func test_partitionReduce_multi() async throws {
			let partitions: SetAlphabet<Int> = [ [0, 1, 2] ]
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(partitions.contains(2))
			#expect(!partitions.contains(3))
		}
		@Test("range of values") func test_contains_range() async throws {
			let partitions: SetAlphabet<Int> = [Set(0x30...0x39)]
			#expect(!partitions.contains(0x2F))
			#expect(partitions.contains(0x30))
			#expect(partitions.contains(0x31))
			#expect(partitions.contains(0x38))
			#expect(partitions.contains(0x39))
			#expect(!partitions.contains(0x3A))
		}
		@Test("two ranges of values") func test_contains_ranges() async throws {
			let partitions: SetAlphabet<Int> = [ Set(0x41...0x5A), Set(0x61...0x7A) ]
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
			let partitions: SetAlphabet<Int> = [ Set(0x30...0x39), Set(0x41...0x5A), Set(0x61...0x7A) ]
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
	@Suite("isEquivalent") struct SymbolClassTests_isEquivalent {
		@Test("single symbol") func test__single() async throws {
			let partitions: SetAlphabet<Int> = [ [1] ]
			#expect(partitions.isEquivalent(1, 1))
		}
		@Test("single set multi-symbol") func test_isEquivalent_multi() async throws {
			let partitions: SetAlphabet<Int> = [[0, 1, 2]]
			#expect(partitions.isEquivalent(0, 1))
		}
	}
}

@Suite("ClosedRangeSymbolClass") struct ClosedRangeSymbolClassTests {
	@Suite("contains") struct ClosedRangeSymbolClassTests_partitionReduce {
		@Test("array literal") func test_array_literal() async throws {
			let partitions: ClosedRangeAlphabet<Int> = [[0...1]]
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("init ranges") func test_partitionReduce_empty() async throws {
			let partitions: ClosedRangeAlphabet<Int> = []
			#expect(!partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single symbol") func test_partitionReduce_single() async throws {
			let partitions = ClosedRangeAlphabet<Int>([ 1 ])
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single set multi-symbol") func test_partitionReduce_multi() async throws {
			let partitions = ClosedRangeAlphabet<Int>([0, 1, 2])
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(partitions.contains(2))
			#expect(!partitions.contains(3))
		}
		@Test("range of values") func test_contains_range() async throws {
			let partitions = ClosedRangeAlphabet<Int>([0x30...0x39])
			#expect(!partitions.contains(0x2F))
			#expect(partitions.contains(0x30))
			#expect(partitions.contains(0x31))
			#expect(partitions.contains(0x38))
			#expect(partitions.contains(0x39))
			#expect(!partitions.contains(0x3A))
		}
		@Test("two ranges of values") func test_contains_ranges() async throws {
			let partitions = ClosedRangeAlphabet<Int>([0x41...0x5A], [0x61...0x7A])
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
			let partitions = ClosedRangeAlphabet<Int>([0x30...0x39], [0x41...0x5A], [0x61...0x7A])
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
	@Suite("get partition label") struct ClosedRangeSymbolClassTests_getPartitionLabel {
		@Test("three partitions") func test_three_parts() async throws {
			let partitions = ClosedRangeAlphabet<Int>([0, 1, 2], [3, 4, 5], [6, 7, 8])
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
			let partitions = ClosedRangeAlphabet<Int>([0...2], [3...4, 5...5], [6...7, 7...7, 8...8])
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
			let partitions = ClosedRangeAlphabet<Int>([ 1 ])
			#expect(partitions.contains(1))
			#expect(!partitions.contains(2))
		}
		@Test("single set multi-symbol") func test_partitionReduce_multi() async throws {
			let partitions = ClosedRangeAlphabet<Int>([0, 1, 2])
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(partitions.contains(2))
			#expect(!partitions.contains(3))
		}
		@Test("range of values") func test_contains_range() async throws {
			let partitions = ClosedRangeAlphabet<Int>([0x30...0x39])
			#expect(!partitions.contains(0x2F))
			#expect(partitions.contains(0x30))
			#expect(partitions.contains(0x31))
			#expect(partitions.contains(0x38))
			#expect(partitions.contains(0x39))
			#expect(!partitions.contains(0x3A))
		}
	}
	@Suite("isEquivalent") struct ClosedRangeSymbolClassTests_isEquivalent {
		@Test("single symbol") func test__single() async throws {
			let partitions = ClosedRangeAlphabet<Int>([ 1 ])
			#expect(partitions.isEquivalent(1, 1))
		}
		@Test("single set multi-symbol") func test_isEquivalent_multi() async throws {
			let partitions = ClosedRangeAlphabet<Int>([0, 1, 2])
			#expect(partitions.isEquivalent(0, 1))
		}
	}
	@Suite("meet") struct ClosedRangeSymbolClassTests_meet {
		@Test("two nested partitions") func test_two_nested_parts() async throws {
			let part1 = ClosedRangeAlphabet<Int>([ 0x30...0x39 ])
			let part2 = ClosedRangeAlphabet<Int>([ 0x32 ])
			let partitions = ClosedRangeAlphabet<Int>(partitions: Array(part1) + Array(part2))
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
			let part1 = ClosedRangeAlphabet<Int>([ 0x30...0x39 ])
			let part2 = ClosedRangeAlphabet<Int>([ 0x32...0x35 ])
			let partitions = ClosedRangeAlphabet<Int>(partitions: Array(part1) + Array(part2))
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
			let part1 = ClosedRangeAlphabet<Int>([ 0x30...0x35 ])
			let part2 = ClosedRangeAlphabet<Int>([ 0x32...0x39 ])
			let partitions = ClosedRangeAlphabet<Int>(partitions: Array(part1) + Array(part2))
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
			let part1 = ClosedRangeAlphabet<Int>([ 0x30...0x32 ])
			let part2 = ClosedRangeAlphabet<Int>([ 0x35...0x39 ])
			let partitions = ClosedRangeAlphabet<Int>(partitions: Array(part1) + Array(part2))
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
			let part1 = ClosedRangeAlphabet<Int>([ 0x30...0x36 ])
			let part2 = ClosedRangeAlphabet<Int>([ 0x32...0x34 ])
			let part3 = ClosedRangeAlphabet<Int>([ 0x33...0x39 ])
			let partitions = ClosedRangeAlphabet<Int>(partitions: [part1, part2, part3].reduce([], +))
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
			let part1 = ClosedRangeAlphabet<Int>([ 0x30...0x36 ])
			let part2 = ClosedRangeAlphabet<Int>([ 0x32...0x34 ])
			let part3 = ClosedRangeAlphabet<Int>([ 0x33...0x38 ])
			let part4 = ClosedRangeAlphabet<Int>([ 0x30...0x39 ])
			let partitions = ClosedRangeAlphabet<Int>(partitions: [part1, part2, part3, part4].reduce([], +))
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

	@Suite("expanded") struct ClosedRangeSymbolClassTests_expanded {
		@Test("two nested partitions") func test_two_nested_parts() async throws {
			let part1 = ClosedRangeAlphabet<Int>([ 0x30...0x39 ])
			let part2 = ClosedRangeAlphabet<Int>([ 0x32 ])
			let partitions = ClosedRangeAlphabet<Int>(partitions: Array(part1) + Array(part2))
			#expect(partitions.isEquivalent(0x30, 0x30))
			#expect(partitions.isEquivalent(0x31, 0x30))
			#expect(partitions.isEquivalent(0x32, 0x32))
			#expect(partitions.isEquivalent(0x33, 0x30))
			#expect(partitions.isEquivalent(0x34, 0x30))
			#expect(partitions.isEquivalent(0x35, 0x30))
			#expect(partitions.isEquivalent(0x36, 0x30))
			#expect(partitions.isEquivalent(0x37, 0x30))
			#expect(partitions.isEquivalent(0x38, 0x30))
		}
	}

	@Suite("insert", .disabled("Tests to be implemented")) struct ClosedRangeSymbolClassTests_insert {
		@Test("insert before") func test_before() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([6...9]);
			alphabet.insert([1...3])
			#expect(alphabet == [ [1...3], [6...9] ])
		}
		@Test("overlapping before") func test_overlap_before() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([4...9]);
			alphabet.insert([1...6])
			#expect(alphabet == [ [1...3], [4...6], [7...9] ])
		}
		@Test("overlapping after") func test_overlap_after() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([0...6]);
			alphabet.insert([4...9])
			#expect(alphabet == [ [0...3], [4...6], [7...9] ])
		}
		@Test("insert after") func test_after() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([0...3]);
			alphabet.insert([6...12])
			#expect(alphabet == [ [0...3], [6...12] ])
		}
		@Test("inside") func test_inside() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([0...9]);
			alphabet.insert([3...6])
			#expect(alphabet == [ [0...2, 7...9], [3...6] ])
		}
		@Test("outside") func test_outside() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([3...6]);
			alphabet.insert([1...9])
			#expect(alphabet == [ [1...2, 7...9], [3...6] ])
		}
	}
}

@Suite("AlphabetTable") struct AlphabetTableTests {
	@Test("SymbolAlphabet") func test_SymbolAlphabet() async throws {
		//var dict = AlphabetTable<SymbolAlphabet<Int>, Int>()
		var dict = SymbolAlphabet<Int>.DFATable()
		dict[2] = 1;
		dict[3] = 2;
		#expect(dict[symbol: 1] == nil)
		#expect(dict[symbol: 2] == 1)
		#expect(dict[symbol: 3] == 2)
		#expect(dict[symbol: 4] == nil)
	}
	@Test("SetAlphabet") func test_SetAlphabet() async throws {
		var dict = AlphabetTable<SetAlphabet<Int>, Int>()
		dict[ [1,2,3] ] = 1;
		dict[ [2] ] = 2;
		#expect(dict[symbol: 0] == nil)
		#expect(dict[symbol: 1] == 1)
		#expect(dict[symbol: 2] == 2)
		#expect(dict[symbol: 3] == 1)
		#expect(dict[symbol: 4] == nil)
	}
	@Test("ClosedRangeAlphabet") func test_ClosedRangeAlphabet() async throws {
//		let alphabet: ClosedRangeAlphabet<Int> = [ [0...2], [3...5] ]
		var dict = AlphabetTable<ClosedRangeAlphabet<Int>, Int>()
		dict[ [3...9] ] = 1;
		dict[ [5...7] ] = 2;
		#expect(dict[symbol: 3] == 1)
		#expect(dict[symbol: 4] == 1)
		#expect(dict[symbol: 5] == 2)
		#expect(dict[symbol: 6] == 2)
		#expect(dict[symbol: 7] == 2)
		#expect(dict[symbol: 8] == 1)
		#expect(dict[symbol: 9] == 1)
	}
}

