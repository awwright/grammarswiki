import Testing
@testable import FSM

// Shared test case structure
struct PatternTestCase {
	let pattern: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	let acceptingInputs: [String]
	let rejectingInputs: [String]
}

struct Tests {
	// Shared list of test cases
	static let standardTestCases: [PatternTestCase] = [
		// [A-Za-z]
		PatternTestCase(
			pattern: RangeDFA<UInt32>(
				states: [
					[:],
					[[65...90, 97...122]: 0],
				],
				initial: 1,
				finals: [0]
			),
			acceptingInputs: ["A", "a", "Z", "z"],
			rejectingInputs: [ "", "1", "AA", "_"]
		),
		// \\d{3}
		PatternTestCase(
			pattern: RangeDFA<UInt32>(
				states: [
					[:],
					[[48...57]: 0],
					[[48...57]: 3],
					[[48...57]: 1],
				],
				initial: 2,
				finals: [0]
			),
			acceptingInputs: ["123", "456", "789"],
			rejectingInputs: ["", "1", "12", "ABC", "   ", "1234"]
		),
		// Add more test cases
	]
}

@Suite("REDialect") struct REDialectTests {
	@Suite("Swift RegExp") struct POSIXGrepTests {
		//let generator: RegexGenerator = JavaScriptRegexGenerator() // Your generator

		@Test("Swift RegExp pattern", arguments: Tests.standardTestCases)
		func testPattern(testCase: PatternTestCase) async throws {
			//try await testRegexPatterns(generator: generator, dialect: .javascript, testCase: testCase)
			let regex: REPattern<UInt32> = testCase.pattern.toPattern()

			//print(regex.description);
			// TODO: also try generating an anchored regular expression with /^regexp$/
			let regexString = REDialectBuiltins.swift.encode(regex);
			guard let regex = try? Regex(regex.description) else { return }

			for acceptingInput in testCase.acceptingInputs {
				#expect(testCase.pattern.contains(acceptingInput.unicodeScalars.map { UInt32($0) }))
				#expect(acceptingInput.wholeMatch(of: regex) != nil, "\(regexString) <- \(acceptingInput) failed, should accept")
			}
			for rejectingInput in testCase.rejectingInputs {
				#expect(!testCase.pattern.contains(rejectingInput.unicodeScalars.map { UInt32($0) }))
				#expect(rejectingInput.wholeMatch(of: regex) == nil, "\(regexString) <- \(rejectingInput) accepted, should fail")
			}
		}
	}
}
