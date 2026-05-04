import XCTest
import FSM

class CFGPerf_parens: XCTestCase {
	// A simple, non-ambiguous grammar
	func test_parens_8() {
		let cfg = CFG<ClosedRangeAlphabet<UInt8>>(start: "S", rules: [
			.init(name: "S", production: []),
			.init(name: "S", production: [.nonterminal("S"), .nonterminal("S")]),
			.init(name: "S", production: [.terminal([0x28...0x28]), .nonterminal("S"), .terminal([0x29...0x29])]),
		]);

		var str = "";
		for i in 0..<1000000 {
			if (i%5)==0 || (i%11)==0 { continue }
			switch (i % 3) {
				case 0: str = "()" + str;
				case 1: str = str + "()";
				case 2: str = "(" + str + ")";
				default: break;
			}
			if str.count > 10000 { break; }
		}
		//print(str);
		let in2 = Array(str.utf8);

		measure {
			assert(cfg.contains(in2))
		}
	}
}
