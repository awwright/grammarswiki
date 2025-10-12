import Testing
@testable import FSM

@Suite("REDialect: Swift RegExp") struct REDialect_Swift_Tests {
	@Test("Swift RegExp pattern", arguments: REDialectTests.standardTestCases)
	func testPattern(testCase: PatternTestCase) async throws {
		//try await testRegexPatterns(generator: generator, dialect: .javascript, testCase: testCase)
		let pattern: REPattern<UInt32> = testCase.pattern.toPattern()

		//print(regex.description);
		// TODO: also try generating an anchored regular expression with /^regexp$/
		let regexString = REDialectBuiltins.swift.encode(pattern);
		let regexObject = try #require(try? Regex(regexString))

		for acceptingInput in testCase.acceptingInputs {
			#expect(testCase.pattern.contains(acceptingInput.unicodeScalars.map { UInt32($0) }))
			#expect(acceptingInput.wholeMatch(of: regexObject) != nil, "\(regexString) <- \(acceptingInput) failed, should accept")
		}
		for rejectingInput in testCase.rejectingInputs {
			#expect(!testCase.pattern.contains(rejectingInput.unicodeScalars.map { UInt32($0) }))
			#expect(rejectingInput.wholeMatch(of: regexObject) == nil, "\(regexString) <- \(rejectingInput) accepted, should fail")
		}
	}
}
