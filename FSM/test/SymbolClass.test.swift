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
		@Test("exercise lower bounds") func test_lower_bounds() async throws {
			let partitions = ClosedRangeAlphabet<UInt8>([0...0xFF], [0...0], [0...1])
			#expect(partitions == [ [0...0], [1...1], [2...0xFF] ]);
			#expect(partitions.contains(0))
			#expect(partitions.contains(1))
			#expect(partitions.contains(2))
			#expect(partitions.contains(0xFF))
		}
		@Test("exercise upper bounds") func test_upper_bounds() async throws {
			let partitions = ClosedRangeAlphabet<UInt8>([0...0xFF], [0xFF...0xFF])
			#expect(partitions == [ [0...0xFE], [0xFF...0xFF] ]);
			#expect(partitions.contains(0))
			#expect(partitions.contains(0xFE))
			#expect(partitions.contains(0xFF))
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

	@Suite("insert") struct ClosedRangeSymbolClassTests_insert {
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
		@Test("between multiple") func test_multi_0() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([1...3, 6...9]);
			alphabet.insert([2...7])
			#expect(alphabet == [ [1...1, 8...9], [2...3, 6...7], [4...5] ])
		}
		@Test("between multiple different") func test_multi_1() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([1...3], [6...9]);
			alphabet.insert([2...7])
			#expect(alphabet == [ [1...1], [2...3], [4...5], [6...7], [8...9] ])
		}
		@Test("multi") func test_multi_2() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([0x42...0x42, 0x62...0x62]);
			alphabet.insert([0x41...0x41, 0x61...0x61])
			#expect(alphabet == [[0x41...0x41, 0x61...0x61], [0x42...0x42, 0x62...0x62]])
		}
		@Test("multi") func test_multi_3() async throws {
			var alphabet = ClosedRangeAlphabet<Int>([0x41...0x41, 0x61...0x61]);
			alphabet.insert([0x42...0x42, 0x62...0x62])
			#expect(alphabet == [[0x41...0x41, 0x61...0x61], [0x42...0x42, 0x62...0x62]])
		}
	}
}

@Suite("AlphabetProtocol") struct AlphabetProtocolTests {
	@Suite("SymbolAlphabet") struct SymbolAlphabetTests {
		@Test("conjunction") func test_SymbolAlphabet_conjunction() {
			let pet0: SymbolAlphabet<Int> = [0, 1];
			let pet1: SymbolAlphabet<Int> = [1, 2];
			let conjunction: SymbolAlphabet<Int> = pet0.conjunction(pet1);
			#expect(conjunction == [0, 1, 2])
		}
	}
	@Suite("SetAlphabet") struct SetAlphabetTests {
		@Test("conjunction") func test_SetAlphabet_conjunction() {
			let pet0: SetAlphabet<Int> = [ [10, 11, 12, 13], [20, 21, 22, 23] ];
			let pet1: SetAlphabet<Int> = [ [10, 11, 20, 21], [12, 13, 22, 23] ];
			let conjunction: SetAlphabet<Int> = pet0.conjunction(pet1);
			#expect(conjunction == [ [10, 11], [12, 13], [20, 21], [22, 23] ])
		}
	}
	@Suite("ClosedRangeAlphabet") struct ClosedRangeAlphabetTests {
		@Test("conjunction") func test_ClosedRangeAlphabet_conjunction() {
			let pet0: ClosedRangeAlphabet<Int> = [ [10...13], [20...23] ];
			let pet1: ClosedRangeAlphabet<Int> = [ [10...21], [12...23] ];
			let conjunction: ClosedRangeAlphabet<Int> = pet0.conjunction(pet1);
			#expect(conjunction == [ [10...11], [12...13], [14...19], [20...21], [22...23] ])
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
	@Test("ClosedRangeAlphabet single value") func test_alphabet_merge_0() async throws {
		var dict = AlphabetTable<ClosedRangeAlphabet<Int>, Int>()
		dict[ [1...3, 4...6, 7...9] ] = 2;
		#expect(dict.alphabet == [[1...9]])
	}
	@Test("ClosedRangeAlphabet two values") func test_alphabet_merge_1() async throws {
		var dict = AlphabetTable<ClosedRangeAlphabet<Int>, Int>()
		dict[ [1...3, 7...9] ] = 1;
		dict[ [4...6] ] = 2;
		#expect(dict.alphabet == [[1...3, 7...9], [4...6]])
	}
	@Test("ClosedRangeAlphabet merges partitions with same values") func test_alphabet_merge_2() async throws {
		var dict = AlphabetTable<ClosedRangeAlphabet<Int>, Int>()
		dict[ [1...3] ] = 1;
		dict[ [4...6] ] = 2;
		dict[ [7...9] ] = 1;
		// The partition should be merged together because they map to the same values
		#expect(dict.alphabet == [[1...3, 7...9], [4...6]])
	}
	@Test("Combination of two partitioned dictionaries") func test_alphabet_merge_dict() async throws {
		var dict0 = ClosedRangeAlphabet<Int>.DFATable()
		dict0[ [1...3, 7...9] ] = 1;
		dict0[ [4...6] ] = 2;
		var dict1 = ClosedRangeAlphabet<Int>.DFATable()
		dict1[ [2...5] ] = 1;
		dict1[ [6...8] ] = 2;
		// The partition should be merged together because they map to the same values
		let set = ClosedRangeAlphabet<Int>(partitions: [dict0.alphabet, dict1.alphabet].flatMap(\.self))
		#expect(set == [[1...1, 9...9], [2...3], [4...5], [6...6], [7...8]]);
		#expect(dict0[ [1...1, 9...9] ] == 1);
		#expect(dict1[ [1...1, 9...9] ] == nil);
		#expect(dict0[ [2...3] ] == 1);
		#expect(dict1[ [2...3] ] == 1);
		#expect(dict0[ [4...5] ] == 2);
		#expect(dict1[ [4...5] ] == 1);
		#expect(dict0[ [6...6] ] == 2);
		#expect(dict1[ [6...6] ] == 2);
		#expect(dict0[ [7...8] ] == 1);
		#expect(dict1[ [7...8] ] == 2);
	}
}
