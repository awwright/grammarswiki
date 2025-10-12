import Testing
@testable import FSM
import JavaScriptCore

@Suite("REDialect: ECMAScript") struct REDialect_ECMAScript_Tests {
	@Test("RegExp.test", arguments: REDialectTests.standardTestCases)
	func testString(testCase: PatternTestCase) async throws {
		//try await testRegexPatterns(generator: generator, dialect: .javascript, testCase: testCase)
		let pattern: REPattern<UInt32> = testCase.pattern.toPattern()

		//print(regex.description);
		// TODO: also try generating an anchored regular expression with /^regexp$/
		let regexString = REDialectBuiltins.ecmascriptString.encodeWhole(pattern);
//		let regexObject = try #require(try? Regex(regexString))

		for acceptingInput in testCase.acceptingInputs {
			#expect(evaluateRegex(pattern: regexString, testString: acceptingInput) == true, "expected \(regexString) to accept \(acceptingInput)")
		}
		for rejectingInput in testCase.rejectingInputs {
			#expect(evaluateRegex(pattern: regexString, testString: rejectingInput) == false, "expected \(regexString) to reject \(rejectingInput)")
		}

		func evaluateRegex(pattern: String, testString: String) -> Bool? {
			// Create a JavaScript context
			guard let context = JSContext() else {
				print("Failed to create JavaScript context")
				return nil
			}

			// Create a JavaScript RegExp object
			let script = """
				function testRegex(pattern, str) {
					try {
						const regex = new RegExp(pattern);
						return regex.test(str);
					} catch (e) { return null; }
				}
				"""

			// Evaluate the JavaScript code
			context.evaluateScript(script)

			// Call the JavaScript function
			guard let function = context.objectForKeyedSubscript("testRegex") else {
				print("Failed to get testRegex function")
				return nil
			}

			// Execute the function with the pattern and test string
			if let result = function.call(withArguments: [pattern, testString]) {
				if result.isUndefined { return nil }
				if result.isBoolean { return result.toBool() }
				return nil;
			}

			return nil
		}
	}

	@Test("Regex Literal test", arguments: REDialectTests.standardTestCases)
	func testLiteral(testCase: PatternTestCase) async throws {
		//try await testRegexPatterns(generator: generator, dialect: .javascript, testCase: testCase)
		let pattern: REPattern<UInt32> = testCase.pattern.toPattern()

		//print(regex.description);
		// TODO: also try generating an anchored regular expression with /^regexp$/
		let regexString = REDialectBuiltins.ecmascriptLiteral.encodeWhole(pattern);
//		let regexObject = try #require(try? Regex(regexString))

		for acceptingInput in testCase.acceptingInputs {
			#expect(evaluateRegex(pattern: regexString, testString: acceptingInput) == true, "expected \(regexString) to accept \(acceptingInput)")
		}
		for rejectingInput in testCase.rejectingInputs {
			#expect(evaluateRegex(pattern: regexString, testString: rejectingInput) == false, "expected \(regexString) to reject \(rejectingInput)")
		}

		func evaluateRegex(pattern: String, testString: String) -> Bool? {
			// Create a JavaScript context
			guard let context = JSContext() else {
				print("Failed to create JavaScript context")
				return nil
			}

			// Create a JavaScript RegExp object
			let script = """
				function testRegex(pattern, str) {
					try {
						const regex = \(pattern);
						return regex.test(str);
					} catch (e) { return null; }
				}
				"""

			// Evaluate the JavaScript code
			context.evaluateScript(script)

			// Call the JavaScript function
			guard let function = context.objectForKeyedSubscript("testRegex") else {
				print("Failed to get testRegex function")
				return nil
			}

			// Execute the function with the pattern and test string
			if let result = function.call(withArguments: ["", testString]) {
				if result.isUndefined { return nil }
				if result.isBoolean { return result.toBool() }
				return nil;
			}

			return nil
		}
	}
}

