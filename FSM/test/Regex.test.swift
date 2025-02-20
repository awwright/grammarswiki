import Testing;
import FSM;
import RegexBuilder;

@Test("Regex") func regex() async throws {
	func testSequence<T: Sequence>(sequence: T) where T.Element == Int {
		let emptySeq: [T.Element] = [];
		print("Empty sequence of type \(T.self): \(emptySeq)")
	}

	// Testing with Array
	let array = [1, 2, 3]
	testSequence(sequence: array)

	// Testing with Set
	let set: Set<Int> = [1, 2, 3]
	testSequence(sequence: set)
}


