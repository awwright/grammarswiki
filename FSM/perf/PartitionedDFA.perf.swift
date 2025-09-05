import FSM
import XCTest

class PartitionedDFAPerf: XCTestCase {
	func testRead() {
		let parts = (0...0x20).map { (SymbolDFA<Int>([ [$0] ]).star(), String($0)) };
		let dfa = PartitionedDFA<Int>.Table<String>(uniqueKeysWithValues: parts)
		measure {
			_ = dfa[symbol: [] ] == "255"
			_ = dfa[symbol: [0, 0] ] == "0"
			_ = dfa[symbol: [8, 8] ] == 	"8"
			_ = dfa[symbol: [9] ] == "9"
			_ = dfa[symbol: [1, 1, 1, 1, 1] ] == "1"
		}
	}
}

