import Testing
@testable import FSM

// Shared test case structure
struct PatternTestCase: CustomDebugStringConvertible {
	let description: String
	let pattern: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	let acceptingInputs: [String]
	let rejectingInputs: [String]

	var debugDescription: String {
		"PatternTestCase(\(description))"
	}
}

struct Tests {
	// Shared list of test cases
	static let standardTestCases: [PatternTestCase] = [
		PatternTestCase(
			description: "[A-Za-z]",
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
		PatternTestCase(
			description: "\\d{3}",
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
		PatternTestCase(
			description: "(ab)*a",
			pattern: RangeDFA<UInt32>(
				states: [
					[[98...98]: 1],
					[[97...97]: 0],
				],
				initial: 1,
				finals: [0]
			),
			acceptingInputs: ["a", "aba", "ababa"],
			rejectingInputs: ["", "ab", "abab", "ABA"]
		),
		PatternTestCase( // case insensitive of above
			description: "([Aa][Bb])*[Aa]",
			pattern: RangeDFA<UInt32>(
				states: [
					[[66...66, 98...98]: 1],
					[[65...65, 97...97]: 0],
				],
				initial: 1,
				finals: [0]
			),
			acceptingInputs: ["a", "AbA", "ABabA"],
			rejectingInputs: ["", "ab", "abab", "1234"]
		),
		PatternTestCase(
			description: "(ab)*c",
			pattern: RangeDFA<UInt32>(
				states: [
					[:],
					[[98...98]: 2],
					[[99...99]: 0, [97...97]: 1],
				],
				initial: 2,
				finals: [0]
			),
			acceptingInputs: ["c", "abc", "ababc"],
			rejectingInputs: ["", "ab", "abca", "ABC"]
		),
		// Single characters 0x20...0x2F
		singleCharacter(" "),
		singleCharacter("!"),
		singleCharacter("\""),
		singleCharacter("#"),
		singleCharacter("$"),
		singleCharacter("%"),
		singleCharacter("&"),
		singleCharacter("'"),
		singleCharacter("("),
		singleCharacter(")"),
		singleCharacter("*"),
		singleCharacter("+"),
		singleCharacter(","),
		singleCharacter("-"),
		singleCharacter("."),
		singleCharacter("/"),
		rangeCharacters(" ", "/"),
		rangeCharacters("0", "9"),
		rangeCharacters("A", "z"),
		rangeCharacters("-", "."),
		rangeCharacters("[", "]"),
		rangeCharacters(" ", "["),
		rangeCharacters(" ", "]"),
	]

	static func singleCharacter(_ character: Character) -> PatternTestCase {
		PatternTestCase(
			description: String(character),
			pattern: RangeDFA<UInt32>(
				states: [
					[[UInt32(character.asciiValue!)...UInt32(character.asciiValue!)]: 1],
					[:],
				],
				initial: 0,
				finals: [1]
			),
			acceptingInputs: [String(character)],
			rejectingInputs: (0...0x7F).map { String((UnicodeScalar($0)!)) }.filter { $0 != String(character) }
		)
	}

	static func rangeCharacters(_ lower: Character, _ upper: Character) -> PatternTestCase {
		PatternTestCase(
			description: "\(lower)-\(upper)",
			pattern: RangeDFA<UInt32>(
				states: [
					[[UInt32(lower.asciiValue!)...UInt32(upper.asciiValue!)]: 1],
					[:],
				],
				initial: 0,
				finals: [1]
			),
			acceptingInputs: ((lower.asciiValue!)...(upper.asciiValue!)).map { String((UnicodeScalar($0))) },
			rejectingInputs: (0...0x7F).map { String((UnicodeScalar($0)!)) }.filter { !((lower.asciiValue!)...(upper.asciiValue!)).map { String((UnicodeScalar($0))) }.contains($0) }
		)
	}
}

@Suite("REDialect") struct REDialectTests {
	@Suite("Swift RegExp") struct POSIXGrepTests {
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
