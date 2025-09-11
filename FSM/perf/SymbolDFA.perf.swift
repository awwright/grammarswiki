import XCTest
import FSM

class DFA_Derive_Performance: XCTestCase {
	func get_reference() -> SymbolDFA<Character> {
		SymbolDFA<Character>([
			"a", "ab", "abc", "abcd", "abcde", "abcdef", "abcdefg", "abcdefgh", "abcdefghi",
			"b", "bc", "bcd", "bcde", "bcdef", "bcdefg", "bcdefgh", "bcdefghi",
		].map { Array($0) }).minimized()
	}
	func test_builtin() {
		let reference = get_reference()
		measure {
			let val = reference.derive(reference)
		}
	}
	func test_union_from_finals() {
		let reference = get_reference()
		measure {
			let val = SymbolDFA.union(reference.finals.map {
				source in reference.subpaths(source: source, target: reference.finals).minimized()
			})
		}
	}
}
