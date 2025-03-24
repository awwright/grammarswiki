import Testing;
@testable import FSM;

@Suite("ABNF Tests") struct ABNFTests {
	@Suite("alphabet/alphabetPartitions") struct ABNFTest_alphabet {
		@Test("alternation")
		func test_alphabet_alternation() async throws {
			// "A" / "B" / 3"C"
			let expression = ABNFAlternation(matches: [
				ABNFCharVal(sequence: "A".utf8).concatenation,
				ABNFCharVal(sequence: "B".utf8).concatenation,
				ABNFCharVal(sequence: "C".utf8).element.repeating(3).concatenation,
			])
			#expect(expression.alphabet() == Set([0x41, 0x42, 0x43]))
		}

		@Test("repetition optional")
		func test_alphabet_repetition_optional() async throws {
			// 0*1%x41-43
			let expression = ABNFRepetition<UInt8>(min: 0, max: 1, element: ABNFNumVal(base: .hex, value: .range(0x41...0x43)).element)
			#expect(expression.alphabet() == Set(0x41...0x43))
			#expect(expression.alphabetPartitions() == Set([ Set(0x41...0x43) ]))
		}

		@Test("repetition plus")
		func test_repetition_plus() async throws {
			// 1*"C"
			let expression = ABNFRepetition<UInt8>(min: 1, max: nil, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			#expect(expression.alphabet() == Set([0x43]))
			#expect(expression.alphabetPartitions() == Set([ [0x43] ]))
		}

		@Test("repetition star")
		func test_repetition_star() async throws {
			// *"C"
			let expression = ABNFRepetition<UInt8>(min: 0, max: nil, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			#expect(expression.alphabet() == Set([0x43]))
			#expect(expression.alphabetPartitions() == Set([ [0x43] ]))
		}

		@Test("repetition min")
		func test_repetition_min() async throws {
			// 2*"C"
			let expression = ABNFRepetition<UInt8>(min: 2, max: nil, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			#expect(expression.alphabet() == Set([0x43]))
			#expect(expression.alphabetPartitions() == Set([ [0x43] ]))
		}

		@Test("repetition max")
		func test_repetition_max() async throws {
			// *2"C"
			let expression = ABNFRepetition<UInt8>(min: 0, max: 2, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			#expect(expression.alphabet() == Set([0x43]))
			#expect(expression.alphabetPartitions() == Set([ [0x43] ]))
		}

		@Test("repetition.toPattern min/max")
		func test_repetition_minmax() async throws {
			// 2*3"ABC"
			let expression = ABNFRepetition<UInt8>(min: 2, max: 3, element: ABNFCharVal<UInt8>(sequence: "ABC".utf8).element)
			#expect(expression.alphabet() == Set([0x41, 0x42, 0x43]))
			#expect(expression.alphabetPartitions() == Set([ [0x41], [0x42], [0x43] ]))
		}

		@Test("element.toPattern")
		func test_element() async throws {
			// "C"
			let expression = ABNFElement.charVal(ABNFCharVal<UInt8>(sequence: "C".utf8))
			#expect(expression.alphabet() == Set([0x43]))
			#expect(expression.alphabetPartitions() == Set([ [0x43] ]))
		}

		@Test("char_val.toPattern")
		func test_char_val() async throws {
			// "C"
			let expression = ABNFCharVal<UInt8>(sequence: "C".utf8)
			#expect(expression.alphabet() == Set([0x43]))
			#expect(expression.alphabetPartitions() == Set([ [0x43] ]))
		}

		@Test("num-val")
		func test_numVal_range() async throws {
			let expression = ABNFNumVal<UInt8>(base: .hex, value: .range(0x30...0x39))
			#expect(expression.alphabet() == Set(0x30...0x39))
			#expect(expression.alphabetPartitions() == Set([ Set(0x30...0x39) ]))
		}

		@Test("builtins")
		func test_rulelist_builtins() async throws {
			let builtins = ABNFBuiltins<DFA<Array<UInt8>>>.dictionary.mapValues { $0.minimized() };
			let expression = ABNFRulename<UInt8>(label: "DIGIT").alternation;
			#expect(expression.alphabet(rulelist: builtins.mapValues(\.alphabet)) == Set(0x30...0x39))
			#expect(expression.alphabetPartitions(rulelist: builtins.mapValues(\.alphabetPartitions)) == Set([ Set(0x30...0x39) ]))
		}

		@Test("builtins 2")
		func test_rulelist_builtins2() async throws {
			let builtins = ABNFBuiltins<DFA<Array<UInt8>>>.dictionary.mapValues { $0.minimized() };
			let expression = ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule"), definedAs: .equal, alternation: ABNFAlternation(matches: [
				ABNFRulename(label: "DIGIT").concatenation,
				ABNFNumVal(base: .hex, value: .range(0x41...0x43)).concatenation,
			]));
			#expect(expression.alphabet(rulelist: builtins.mapValues(\.alphabet)) == Set(Array(0x30...0x39) + [0x41, 0x42, 0x43]))
			#expect(expression.alphabetPartitions(rulelist: builtins.mapValues(\.alphabetPartitions)) == Set([ Set(Array(0x30...0x39) + [0x41, 0x42, 0x43]) ]))
		}
	}
	@Suite("match/parse") struct ABNFTest_match {
		@Test("rulelist")
		func test_rulelist() async throws {
			let abnf = "rule1 = foo\r\nrule2 = \r\n\tfoo\r\nanother"
			let (rule, remainder) = try ABNFRulelist<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFAlternation<UInt8>.parse("foo".utf8)
			#expect(rule == ABNFRulelist<UInt8>(rules: [
				ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule1"), definedAs: .equal, alternation: inner),
				ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule2"), definedAs: .equal, alternation: inner),
			]));
			#expect(CHAR_string(remainder) == "another");
		}

		@Test("rulelist incremental")
		func test_rulelist_incremental() async throws {
			let abnf = "rule = %x20\r\nrule =/ %x30\r\n..."
			let (rulelist, remainder) = try ABNFRulelist<UInt8>.match(abnf.utf8)!
			#expect(rulelist == ABNFRulelist<UInt8>(rules: [
				ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule"), definedAs: .equal, alternation: ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x20])).alternation),
				ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule"), definedAs: .incremental, alternation: ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x30])).alternation),
			]));
			let dict = rulelist.dictionary;
			let expectedRule = ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule"), definedAs: .equal, alternation: ABNFAlternation(matches: [
				ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x20])).concatenation,
				ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x30])).concatenation,
			]));
			#expect(dict == ["rule": expectedRule]);
			#expect(CHAR_string(remainder) == "...");
		}

		@Test("rule")
		func test_rule() async throws {
			let abnf = "foo = bar\r\nanother"; // Must contain trailing \r\n, escape this for cross-platform reasons
			let (rule, remainder) = try ABNFRule<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFAlternation<UInt8>.parse("bar".utf8)
			#expect(rule == ABNFRule(rulename: ABNFRulename<UInt8>(label: "foo"), definedAs: .equal, alternation: inner));
			#expect(CHAR_string(remainder) == "another");
		}

		@Test("rulename")
		func test_rulename() async throws {
			let abnf = "foo ";
			let (rulename, remainder) = ABNFRulename<UInt8>.match(abnf.utf8)!
			#expect(rulename == ABNFRulename<UInt8>(label: "foo"));
			#expect(CHAR_string(remainder) == " ");
			#expect(rulename.alternation == ABNFAlternation<UInt8>(matches: [rulename.concatenation]))
			#expect(rulename.concatenation == ABNFConcatenation<UInt8>(repetitions: [rulename.repetition]))
			#expect(rulename.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rulename.element))
			#expect(rulename.element == ABNFElement<UInt8>.rulename(rulename))
			#expect(rulename.group == ABNFGroup<UInt8>(alternation: rulename.alternation))
			#expect(rulename.isEmpty == false)
			#expect(rulename.isOptional == false)
		}

		@Test("alternation of single rulename")
		func test_alternation_rulename() async throws {
			let abnf = "foo )";
			let (rule, remainder) = try! ABNFAlternation<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFConcatenation<UInt8>.parse("foo".utf8)
			#expect(rule == ABNFAlternation<UInt8>(matches: [inner]));
			#expect(CHAR_string(remainder) == " )");
			#expect(rule.alternation == rule)
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo"))) // Unwrap the alternation
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("alternation of two rulenames")
		func test_alternation_rulename2() async throws {
			let abnf = "foo / foo )";
			let (rule, remainder) = try! ABNFAlternation<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFConcatenation<UInt8>.parse("foo".utf8)
			#expect(rule == ABNFAlternation<UInt8>(matches: [inner, inner]));
			#expect(CHAR_string(remainder) == " )");
			#expect(rule.alternation == rule)
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("concatenation of single rulename")
		func test_concatenation() async throws {
			let abnf = "foo ";
			let (rule, remainder) = try! ABNFConcatenation<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFRepetition<UInt8>.parse("foo".utf8)
			#expect(rule == ABNFConcatenation<UInt8>(repetitions: [inner]));
			#expect(CHAR_string(remainder) == " ");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == rule)
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo"))) // Unwrap the concatenation
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("concatenation of two rulenames")
		func test_concatenation_rulename2() async throws {
			let abnf = "foo bar ";
			let (rule, remainder) = try! ABNFConcatenation<UInt8>.match(abnf.utf8)!
			let inner1 = try! ABNFRepetition<UInt8>.parse("foo".utf8)
			let inner2 = try! ABNFRepetition<UInt8>.parse("bar".utf8)
			#expect(rule == ABNFConcatenation<UInt8>(repetitions: [inner1, inner2]));
			#expect(CHAR_string(remainder) == " ");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == rule)
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("repetition 0")
		func test_repetition_0() async throws {
			let abnf = "0foo ...";
			let (rule, remainder) = try! ABNFRepetition<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFRepetition<UInt8>(min: 0, max: 0, element: ABNFRulename<UInt8>(label: "foo").element));
			#expect(CHAR_string(remainder) == " ...");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == rule)
			#expect(rule.element == ABNFElement<UInt8>.group(ABNFGroup<UInt8>(alternation: rule.alternation))) // Unwrap the repetition instead of wrapping it
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == true)
			#expect(rule.isOptional == true)
		}

		@Test("repetition 1")
		func test_repetition_1() async throws {
			let foo = try! ABNFElement<UInt8>.parse("foo".utf8);
			let abnf = "foo ";
			let (rule, remainder) = try! ABNFRepetition<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFRepetition<UInt8>(min: 1, max: 1, element: foo));
			#expect(CHAR_string(remainder) == " ");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == rule)
			#expect(rule.element == ABNFRulename<UInt8>(label: "foo").element) // Unwrap the repetition instead of wrapping it
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("repetition min")
		func test_repetition_2() async throws {
			let foo = try! ABNFElement<UInt8>.parse("foo".utf8);
			let abnf = "1*foo ";
			let (rule, remainder) = try! ABNFRepetition<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFRepetition<UInt8>(min: 1, max: nil, element: foo));
			#expect(CHAR_string(remainder) == " ");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: nil, element: ABNFRulename<UInt8>(label: "foo").element))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("repetition max")
		func test_repetition_3() async throws {
			let foo = try! ABNFElement<UInt8>.parse("foo".utf8);
			let abnf = "*4foo ";
			let (rule, remainder) = try! ABNFRepetition<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFRepetition<UInt8>(min: 0, max: 4, element: foo));
			#expect(CHAR_string(remainder) == " ");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 0, max: 4, element: ABNFRulename<UInt8>(label: "foo").element))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == true)
		}

		@Test("repetition min/max")
		func test_repetition_4() async throws {
			let foo = try! ABNFElement<UInt8>.parse("foo".utf8);
			let abnf = "2*4foo ";
			let (rule, remainder) = try! ABNFRepetition<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFRepetition<UInt8>(min: 2, max: 4, element: foo));
			#expect(CHAR_string(remainder) == " ");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 2, max: 4, element: ABNFRulename<UInt8>(label: "foo").element))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		// element        =  rulename / group / option / char-val / num-val / prose-val
		@Test("element of rulename")
		func test_element_rulename() async throws {
			let abnf = "foo";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo")));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == rule)
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("element of group of alternation")
		func test_element_group_alternation() async throws {
			let abnf = "(foo / bar) ...";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			let concatenation1 = ABNFConcatenation<UInt8>(repetitions: [ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo")))]);
			let concatenation2 = ABNFConcatenation<UInt8>(repetitions: [ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "bar")))]);
			#expect(rule == ABNFElement<UInt8>.group(ABNFGroup<UInt8>(alternation: ABNFAlternation<UInt8>(matches: [
				concatenation1,
				concatenation2,
			]))));
			#expect(CHAR_string(remainder) == " ...");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [concatenation1, concatenation2])) // unwrap the group
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition])) // alternation of two elements cannot be unwrapped
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == rule)
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("element of group of concatenation")
		func test_element_group_concatenation() async throws {
			let abnf = "(foo bar) ...";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			let repetition1 = ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo")));
			let repetition2 = ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "bar")));
			#expect(rule == ABNFElement<UInt8>.group(ABNFGroup<UInt8>(alternation: ABNFAlternation<UInt8>(matches: [ABNFConcatenation<UInt8>(repetitions: [repetition1, repetition2])]))));
			#expect(CHAR_string(remainder) == " ...");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [repetition1, repetition2]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == rule)
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("element of group of rulename")
		func test_element_group_rulename() async throws {
			let abnf = "(foo) ...";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFElement<UInt8>.group(ABNFGroup<UInt8>(alternation: ABNFAlternation<UInt8>(matches: [ABNFConcatenation<UInt8>(repetitions: [ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo")))])]))));
			#expect(CHAR_string(remainder) == " ...");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo")))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("element of option")
		func test_element_option() async throws {
			let abnf = "[foo]";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFElement<UInt8>.option(ABNFOption<UInt8>(optionalAlternation: ABNFAlternation<UInt8>(matches: [ABNFConcatenation<UInt8>(repetitions: [ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo")))])]))));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == rule)
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == true)
		}

		@Test("element of charVal")
		func test_element_charVal() async throws {
			let abnf = "\" \"-";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFElement<UInt8>.charVal(ABNFCharVal<UInt8>(sequence: [0x20])));
			#expect(CHAR_string(remainder) == "-");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == rule)
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("element of numval")
		func test_element_numVal() async throws {
			let abnf = "%x31";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFElement<UInt8>.numVal(ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x31]))));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == rule)
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("element of proseVal")
		func test_element_proseVal() async throws {
			let abnf = "<Plain text description>";
			let (rule, remainder) = try! ABNFElement<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFElement<UInt8>.proseVal(ABNFProseVal<UInt8>(remark: "Plain text description")));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == rule)
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("group of nothing")
		func test_group_empty() async throws {
			// An expression that can be reduced by eliminating the group
			let abnf = "( 0<> )";
			let (rule, remainder) = try! ABNFGroup<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFAlternation<UInt8>.parse("0<>".utf8)
			#expect(rule == ABNFGroup<UInt8>(alternation: inner));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == inner)
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 0, max: 0, element: ABNFElement<UInt8>.proseVal(ABNFProseVal<UInt8>(remark: ""))))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == true)
			#expect(rule.isOptional == true)
		}

		@Test("group of rulename")
		func test_group_rulename() async throws {
			// An expression that can be reduced by eliminating the group
			let abnf = "( foo )";
			let (rule, remainder) = try! ABNFGroup<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFAlternation<UInt8>.parse("foo".utf8)
			#expect(rule == ABNFGroup<UInt8>(alternation: inner));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == inner)
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo"))) // Unwrap the group
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("group of alternation")
		func test_group_alternation() async throws {
			// And an expression that cannot be reduced by eliminating the group
			let abnf = "( foo / bar ) ...";
			let (rule, remainder) = try! ABNFGroup<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFAlternation<UInt8>.parse("foo / bar".utf8)
			#expect(rule == ABNFGroup<UInt8>(alternation: inner));
			#expect(CHAR_string(remainder) == " ...");
			#expect(rule.alternation == inner)
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: inner))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("group of concatenation")
		func test_group_concatenation() async throws {
			// And an expression that cannot be reduced by eliminating the group
			let abnf = "( foo bar ) ...";
			let (rule, remainder) = try! ABNFGroup<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFConcatenation<UInt8>.parse("foo bar".utf8)
			#expect(rule == ABNFGroup<UInt8>(alternation: ABNFAlternation<UInt8>(matches: [inner])));
			#expect(CHAR_string(remainder) == " ...");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [inner]))
			#expect(rule.concatenation == inner)
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("option")
		func test_option() async throws {
			let abnf = "[ foo ] ...";
			let (rule, remainder) = try! ABNFOption<UInt8>.match(abnf.utf8)!
			let inner = try! ABNFAlternation<UInt8>.parse("foo".utf8)
			#expect(rule == ABNFOption<UInt8>(optionalAlternation: inner));
			#expect(CHAR_string(remainder) == " ...");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.option(rule))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == true)
		}

		// char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
		@Test("char-val")
		func test_char_val() async throws {
			let abnf = """
			"foo"
			""";
			let (rule, remainder) = try! ABNFCharVal<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFCharVal<UInt8>(sequence: "foo".utf8));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.charVal(rule))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("num-val w/ bin-val")
		func test_bin_val() async throws {
			let abnf = "%b100000.100000";
			let (rule, remainder) = try! ABNFNumVal<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFNumVal<UInt8>(base: .bin, value: .sequence([0x20, 0x20])));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.numVal(rule))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("num-val w/ dec-val")
		func test_dec_val() async throws {
			let abnf = "%d32.32";
			let (rule, remainder) = try! ABNFNumVal<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFNumVal<UInt8>(base: .dec, value: .sequence([0x20, 0x20])));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.numVal(rule))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("num-val w/ hex-val")
		func test_hex_val() async throws {
			let abnf = "%x20.20";
			let (rule, remainder) = try! ABNFNumVal<UInt8>.match(abnf.utf8)!
			#expect(rule == ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x20, 0x20])));
			#expect(CHAR_string(remainder) == "");
			#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
			#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
			#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
			#expect(rule.element == ABNFElement<UInt8>.numVal(rule))
			#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
			#expect(rule.isEmpty == false)
			#expect(rule.isOptional == false)
		}

		@Test("prose_val")
		func test_prose_val() async throws {
			let input = "<Some message> 123".utf8;
			let (prose, remainder) = try! ABNFProseVal<UInt8>.match(input)!
			#expect(prose == ABNFProseVal<UInt8>(remark: "Some message"));
			#expect(CHAR_string(remainder) == " 123");
			#expect(prose.alternation == ABNFAlternation<UInt8>(matches: [prose.concatenation]))
			#expect(prose.concatenation == ABNFConcatenation<UInt8>(repetitions: [prose.repetition]))
			#expect(prose.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: prose.element))
			#expect(prose.element == ABNFElement<UInt8>.proseVal(prose))
			#expect(prose.group == ABNFGroup<UInt8>(alternation: prose.alternation))
			#expect(prose.isEmpty == false)
			#expect(prose.isOptional == false)
		}
	}
	@Suite("mapSymbols") struct ABNFTest_mapSymbols {
		@Test("UInt8->UInt16")
		func test_rulelist() async throws {
			let expression = ABNFAlternation(matches: [
				ABNFCharVal(sequence: "A".utf8).concatenation,
				ABNFCharVal(sequence: "B".utf8).concatenation,
				ABNFCharVal(sequence: "C".utf8).element.repeating(3).concatenation,
			])
			let mapped = expression.mapSymbols({ UInt16($0) });
			#expect(try mapped.toPattern(as: DFA<Array<UInt16>>.self).contains("A".utf16));
		}

		@Test("To lowercase")
		func test_repetition_optional() async throws {
			let input = "[%x43] ...";
			let (expression, remainder) = try! ABNFRepetition<UInt8>.match(input.utf8)!
			#expect(CHAR_string(remainder) == " ...")
			// Make it lowercase
			let mapped = expression.mapSymbols { (0x41...0x5A).contains($0) ? ($0 + 0x20) : $0 }
			let fsm: DFA<Array<UInt8>> = try mapped.toPattern();
			#expect(fsm.contains("".utf8));
			#expect(fsm.contains("c".utf8));
			#expect(!fsm.contains("C".utf8));
		}

		@Test("char-val")
		func test_char_val() async throws {
			// FIXME: a char-val is case insensitive, how do you handle this?
		}

		@Test("num-val range")
		func test_numVal_range() async throws {
			let input = "%x30-39";
			let expression = try! ABNFAlternation<UInt8>.parse(input.utf8)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern();
			#expect(fsm.contains([0x30]))
		}

		@Test("num-val sequence")
		func test_numVal_sequence() async throws {
			let input = "%x30-39";
			let expression = try! ABNFAlternation<UInt8>.parse(input.utf8)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern();
			#expect(fsm.contains([0x30]))
		}
	}
	@Suite("mapElements") struct ABNFTest_mapElements {
		@Test("rulename")
		func test_rulename() async throws {
			// Substitute a certain rulename for its definition
		}

		@Test("group")
		func test_group() async throws {
			// FIXME: a char-val is case insensitive, how do you handle this?
		}

		@Test("option")
		func test_option() async throws {
			// FIXME: a char-val is case insensitive, how do you handle this?
		}

		@Test("char-val")
		func test_char_val() async throws {
			// FIXME: a char-val is case insensitive, how do you handle this?
		}

		@Test("num-val range")
		func test_numVal_range() async throws {
			let expression = ABNFNumVal<UInt8>(base: .hex, value: .range(0x30...0x39)).alternation
			let fsm: DFA<Array<UInt8>> = try expression.toPattern();
			#expect(fsm.contains([0x30]))
		}

		@Test("num-val sequence")
		func test_numVal_sequence() async throws {
			let expression = ABNFNumVal<UInt8>(base: .hex, value: .range(0x30...0x39)).alternation
			let fsm: DFA<Array<UInt8>> = try expression.toPattern();
			#expect(fsm.contains([0x30]))
		}

		@Test("prose-val sequence")
		func test_proseVal() async throws {
			// TODO: Substitute a prose-val for a special symbol
		}
	}
	@Suite("toPattern") struct ABNFTest_toPattern {
		@Test("alternation")
		func test_alternation_toPattern() async throws {
			// "A" / "B" / 3"C"
			let expression = ABNFAlternation(matches: [
				ABNFCharVal(sequence: "A".utf8).concatenation,
				ABNFCharVal(sequence: "B".utf8).concatenation,
				ABNFCharVal(sequence: "C".utf8).element.repeating(3).concatenation,
			])
			let fsm = try expression.toPattern(as: DFA<Array<UInt8>>.self);
			#expect(fsm.contains("A".utf8));
		}

		@Test("repetition optional")
		func test_repetition_optional_toPattern() async throws {
			// 0*1"C"
			let expression = ABNFRepetition<UInt8>(min: 0, max: 1, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern(rules: [:]);
			#expect(fsm.contains("".utf8));
			#expect(fsm.contains("C".utf8));
			#expect(!fsm.contains("CC".utf8));
		}

		@Test("repetition plus")
		func test_repetition_plus_toPattern() async throws {
			// 1*"C"
			let expression = ABNFRepetition<UInt8>(min: 1, max: nil, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern(rules: [:]);
			#expect(!fsm.contains("".utf8));
			#expect(fsm.contains("C".utf8));
			#expect(fsm.contains("CC".utf8));
		}

		@Test("repetition star")
		func test_repetition_star_toPattern() async throws {
			// *"C"
			let expression = ABNFRepetition<UInt8>(min: 0, max: nil, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern(rules: [:]);
			#expect(fsm.contains("".utf8));
			#expect(fsm.contains("C".utf8));
			#expect(fsm.contains("CC".utf8));
		}

		@Test("repetition min")
		func test_repetition_min_toPattern() async throws {
			// 2*"C"
			let expression = ABNFRepetition<UInt8>(min: 2, max: nil, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern(rules: [:]);
			#expect(!fsm.contains("C".utf8));
			#expect(fsm.contains("CC".utf8));
			#expect(fsm.contains("CCC".utf8));
		}

		@Test("repetition max")
		func test_repetition_max_toPattern() async throws {
			// *2"C"
			let expression = ABNFRepetition<UInt8>(min: 0, max: 2, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern(rules: [:]);
			#expect(fsm.contains("".utf8));
			#expect(fsm.contains("C".utf8));
			#expect(fsm.contains("CC".utf8));
			#expect(!fsm.contains("CCC".utf8));
		}

		@Test("repetition.toPattern min/max")
		func test_repetition_minmax_toPattern() async throws {
			// 2*3"C"
			let expression = ABNFRepetition<UInt8>(min: 2, max: 3, element: ABNFCharVal<UInt8>(sequence: "C".utf8).element)
			let fsm: DFA<Array<UInt8>> = try expression.toPattern(rules: [:]);
			#expect(!fsm.contains("C".utf8));
			#expect(fsm.contains("CC".utf8));
			#expect(fsm.contains("CCC".utf8));
			#expect(!fsm.contains("CCCC".utf8));
		}

		@Test("element.toPattern")
		func test_element_toPattern() async throws {
			// "C"
			let expression = ABNFElement.charVal(ABNFCharVal<UInt8>(sequence: "C".utf8))
			let fsm: DFA<Array<UInt8>> = try expression.toPattern(rules: [:]);
			#expect(fsm.contains("C".utf8));
		}

		@Test("char_val.toPattern")
		func test_char_val_toPattern() async throws {
			// "C"
			let expression = ABNFCharVal<UInt8>(sequence: "C".utf8)
			let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
			#expect(fsm.contains("C".utf8));
		}

		@Test("rulelist.toPattern with rule")
		func test_rulelist_toPattern_2() async throws {
			let expression = ABNFRulelist<UInt8>(rules: [
				ABNFRule(rulename: ABNFRulename<UInt8>(label: "Top"), definedAs: .equal, alternation: ABNFConcatenation(repetitions: [
					ABNFRepetition(min: 3, max: 3, element: ABNFRulename(label: "Rule").element)
				]).alternation),
				ABNFRule(rulename: ABNFRulename<UInt8>(label: "Rule"), definedAs: .equal, alternation: ABNFConcatenation(repetitions: [
					ABNFCharVal(sequence: [0x63]).repetition
				]).alternation),
			]);
			let fsm: Dictionary<String, DFA<Array<UInt8>>> = try expression.toPattern(rules: [:]);
			#expect(fsm["Top"]!.contains("CCC".utf8));
		}

		@Test("rulelist.toPattern with incremental rules")
		func test_rulelist_toPattern_incremental() async throws {
			let expression = ABNFRulelist<UInt16>(rules: [
				ABNFRule(rulename: ABNFRulename<UInt16>(label: "Top"), definedAs: .equal, alternation: ABNFConcatenation(repetitions: [
					ABNFNumVal<UInt16>(base: .hex, value: .sequence([0x20])).repetition
				]).alternation),
				ABNFRule(rulename: ABNFRulename<UInt16>(label: "Top"), definedAs: .incremental, alternation: ABNFConcatenation(repetitions: [
					ABNFCharVal(sequence: [0x30]).repetition
				]).alternation),
			]);
			let fsm: Dictionary<String, DFA<Array<UInt16>>> = try expression.toPattern(rules: [:]);
			let rule = try #require(fsm["Top"]);
			#expect(rule.contains(" ".utf16));
			#expect(rule.contains("0".utf16));
			#expect(rule.contains("1".utf16) == false);
		}

		@Test("num-val")
		func test_toPattern_numVal_range() async throws {
			let expression = ABNFNumVal<UInt8>(base: .hex, value: .range(0x30...0x39))
			let fsm: DFA<Array<UInt8>> = expression.toPattern();
			#expect(fsm.contains([0x30]))
		}
	}
	@Suite("union") struct ABNFTest_union {
		@Test("rulename / rulename")
		func test_union_rulename() async throws {
			let expr1 = ABNFRulename<UInt8>(label: "foo").alternation;
			let expr2 = ABNFRulename<UInt8>(label: "bar").alternation;
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "foo bar");
		}
		@Test("rulename / rulename")
		func test_union_rulename_homogeneous() async throws {
			let expr1 = ABNFRulename<UInt8>(label: "foo").alternation;
			let expr2 = ABNFRulename<UInt8>(label: "foo").alternation;
			let expression = expr1.union(expr2);
			#expect(expression.description == "foo");
		}
		@Test("alternation / alternation")
		func test_union_alternation() async throws {
			let expr1 = ABNFAlternation<UInt8>(matches: [ABNFRulename(label: "foo").concatenation, ABNFRulename(label: "bar").concatenation]); // foo/bar
			let expr2 = ABNFAlternation<UInt8>(matches: [ABNFRulename(label: "alice").concatenation, ABNFRulename(label: "bob").concatenation]); // alice/bob
			let expression = expr1.union(expr2);
			#expect(expression.description == "foo / bar / alice / bob");
		}

		@Test("concatenation / concatenation")
		func test_union_concatenation() async throws {
			let expr1 = ABNFConcatenation<UInt8>(repetitions: [ABNFRulename(label: "a").repetition, ABNFRulename(label: "b").repetition]).alternation; // a b
			let expr2 = ABNFConcatenation<UInt8>(repetitions: [ABNFRulename(label: "c").repetition, ABNFRulename(label: "d").repetition]).alternation; // c d
			let expression = expr1.union(expr2);
			#expect(expression.description == "a b / c d");
		}

		@Test("repetition / repetition (heterogeneous)")
		func test_union_repetition_0() async throws {
			let expr1 = ABNFRulename<UInt8>(label: "foo").element.repeating(2).alternation
			let expr2 = ABNFRulename<UInt8>(label: "bar").element.repeating(2).alternation
			let expression = expr1.union(expr2);
			#expect(expression.description == "2foo / 2bar");
		}

		@Test("repetition / repetition (homogeneous)")
		func test_union_repetition_1() async throws {
			let expr = ABNFRulename<UInt8>(label: "foo").alternation
			let expression = expr.union(expr);
			#expect(expression.description == "foo");
		}

		@Test("repetition / repetition (homogeneous)")
		func test_union_repetition_2() async throws {
			let expr = ABNFRulename<UInt8>(label: "foo").element.repeating(2).alternation
			let expression = expr.union(expr);
			#expect(expression.description == "2foo");
		}

		@Test("repetition / repetition (homogeneous 2)")
		func test_union_repetition_3() async throws {
			let expr1 = ABNFRulename<UInt8>(label: "foo").element.repeating(2...).alternation
			let expr2 = ABNFRulename<UInt8>(label: "foo").element.repeating(2).alternation
			let expression = expr1.union(expr2);
			#expect(expression.description == "2*foo");
		}

		@Test("group / group (rulename)")
		func test_union_group() async throws {
			let expr1 = ABNFGroup(alternation: ABNFRulename<UInt8>(label: "foo").alternation).alternation;
			let expr2 = ABNFGroup(alternation: ABNFRulename<UInt8>(label: "bar").alternation).alternation;
			let expression = expr1.union(expr2);
			#expect(expression.description == "foo / bar");
		}

		@Test("option / option (rulename)")
		func test_union_option() async throws {
			let expr1 = ABNFOption(optionalAlternation: ABNFRulename<UInt8>(label: "foo").alternation).alternation;
			let expr2 = ABNFOption(optionalAlternation: ABNFRulename<UInt8>(label: "bar").alternation).alternation;
			let expression = expr1.union(expr2);
			 #expect(expression.description == "[foo] / [bar]");
			// TODO: Should look like this:
			//#expect(expression.description == "[foo / bar]");
		}

		@Test("charVal / charVal")
		func test_union_charVal() async throws {
			let expr1 = ABNFCharVal(sequence: "foo".utf8).alternation;
			let expr2 = ABNFCharVal(sequence: "bar".utf8).alternation;
			let expression = expr1.union(expr2);
			#expect(expression.description == "\"foo\" / \"bar\"");
		}

		@Test("numVal / numVal (sequence 1)")
		func test_union_numVal_sequence() async throws {
			let expr1 = ABNFNumVal(base: .hex, value: .sequence([0x20])).alternation;
			let expr2 = ABNFNumVal(base: .hex, value: .sequence([0x21])).alternation;
			let expression = expr1.union(expr2);
			#expect(expression.description == "%x20-21");
		}

		@Test("numVal / numVal (sequence 2)")
		func test_union_numVal_sequence_2() async throws {
			let expr1 = ABNFNumVal(base: .hex, value: .sequence([0x20])).alternation;
			let expr2 = ABNFNumVal(base: .hex, value: .sequence([0x22])).alternation;
			let expression = expr1.union(expr2);
			#expect(expression.description == "%x20 / %x22");
		}

		@Test("numVal / numVal (range)")
		func test_union_numVal_range() async throws {
			let expr1 = ABNFNumVal(base: .hex, value: .range(0x20...0x21)).alternation;
			let expr2 = ABNFNumVal(base: .hex, value: .range(0x30...0x39)).alternation;
			let expression = expr1.union(expr2);
			#expect(expression.description == "%x20-21 / %x30-39");
		}

		@Test("numVal range 2")
		func test_union_numVal_2() async throws {
			// Put it out of order just to see if it matches them
			let matches = Array<UInt8>([0x20, 0x29, 0x22, 0x27, 0x24, 0x25, 0x26, 0x23, 0x28, 0x21]).map {
				ABNFNumVal<UInt8>(base: .hex, value: .sequence([$0])).alternation
			}
			let expression = ABNFAlternation<UInt8>.union(matches)
			#expect(expression.description == "%x20-29");
		}

		@Test("numVal range 3")
		func test_union_union_2() async throws {
			let expr1 = try! ABNFAlternation<UInt8>.parse("%x30-32".utf8);
			let expr2 = try! ABNFAlternation<UInt8>.parse("%x37-39".utf8);
			let expr3 = try! ABNFAlternation<UInt8>.parse("%x33-35".utf8);
			let expression = ABNFAlternation<UInt8>.union([expr1, expr2, expr3])
			#expect(expression.description == "%x30-35 / %x37-39");
		}

		@Test("proseVal / proseVal")
		func test_union_proseVal() async throws {
			let expr1 = ABNFProseVal<UInt8>(remark: "foo").alternation;
			let expr2 = ABNFProseVal<UInt8>(remark: "bar").alternation;
			let expression = expr1.union(expr2);
			#expect(expression.description == "<foo> / <bar>");
		}
	}
	@Suite("concatenate") struct ABNFTest_concatenate {
		@Test("rulename ++ rulename")
		func test_concatenate_rulename() async throws {
			let expr1 = ABNFRulename<UInt8>(label: "foo").alternation;
			let expr2 = ABNFRulename<UInt8>(label: "bar").alternation;
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "foo bar");
		}
		@Test("alternation ++ alternation")
		func test_concatenate_alternation() async throws {
			let expr1 = ABNFAlternation<UInt8>(matches: [ABNFRulename(label: "foo").concatenation, ABNFRulename(label: "bar").concatenation]); // foo/bar
			let expr2 = ABNFAlternation<UInt8>(matches: [ABNFRulename(label: "alice").concatenation, ABNFRulename(label: "bob").concatenation]); // alice/bob
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "(foo / bar) (alice / bob)");
		}

		@Test("concatenation ++ concatenation")
		func test_concatenate_concatenation() async throws {
			let expr1 = ABNFConcatenation<UInt8>(repetitions: [ABNFRulename(label: "a").repetition, ABNFRulename(label: "b").repetition]).alternation; // a b
			let expr2 = ABNFConcatenation<UInt8>(repetitions: [ABNFRulename(label: "c").repetition, ABNFRulename(label: "d").repetition]).alternation; // c d
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "a b c d");
		}

		@Test("repetition ++ repetition (heterogeneous)")
		func test_concatenate_repetition_0() async throws {
			let expr1 = ABNFRulename<UInt8>(label: "foo").element.repeating(2).alternation
			let expr2 = ABNFRulename<UInt8>(label: "bar").element.repeating(2).alternation
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "2foo 2bar");
		}

		@Test("repetition ++ repetition (homogeneous)")
		func test_concatenate_repetition_1() async throws {
			let expr = ABNFRulename<UInt8>(label: "foo").alternation
			let expression = expr.concatenate(expr);
			#expect(expression.description == "2foo");
		}

		@Test("repetition ++ repetition (homogeneous)")
		func test_concatenate_repetition_2() async throws {
			let expr = ABNFRulename<UInt8>(label: "foo").element.repeating(2).alternation
			let expression = expr.concatenate(expr);
			#expect(expression.description == "4foo");
		}

		@Test("repetition ++ repetition (homogeneous 2)")
		func test_concatenate_repetition_3() async throws {
			let expr1 = ABNFRulename<UInt8>(label: "foo").element.repeating(2...).alternation
			let expr2 = ABNFRulename<UInt8>(label: "foo").element.repeating(2).alternation
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "4*foo");
		}

		@Test("group ++ group (rulename)")
		func test_concatenate_group() async throws {
			let expr1 = ABNFGroup(alternation: ABNFRulename<UInt8>(label: "foo").alternation).alternation;
			let expr2 = ABNFGroup(alternation: ABNFRulename<UInt8>(label: "bar").alternation).alternation;
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "foo bar");
		}

		@Test("option ++ option (rulename)")
		func test_concatenate_option() async throws {
			let expr1 = ABNFOption(optionalAlternation: ABNFRulename<UInt8>(label: "foo").alternation).alternation;
			let expr2 = ABNFOption(optionalAlternation: ABNFRulename<UInt8>(label: "bar").alternation).alternation;
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "[foo] [bar]");
		}

		@Test("charVal ++ charVal")
		func test_concatenate_charVal() async throws {
			let expr1 = ABNFCharVal(sequence: "foo".utf8).alternation;
			let expr2 = ABNFCharVal(sequence: "bar".utf8).alternation;
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "\"foobar\"");
		}

		@Test("numVal ++ numVal (sequence)")
		func test_concatenate_numVal_sequence() async throws {
			let expr1 = ABNFNumVal(base: .hex, value: .sequence([0x20])).alternation;
			let expr2 = ABNFNumVal(base: .hex, value: .sequence([0x22])).alternation;
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "%x20.22");
		}

		@Test("numVal ++ numVal ++ group ++ group (sequence)")
		func test_concatenate_numVal_group() async throws {
			let expr1 = ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x20])).alternation; // %x20
			let expr2 = ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x21])).alternation; // %x21
			let expr3 = ABNFGroup<UInt8>(alternation: ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x30, 0x32, 0x34])).alternation).alternation; // (%x30.32.34)
			let expr4 = ABNFGroup<UInt8>(alternation: ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x36, 0x38])).alternation).alternation; // (%x36.38)
			let expression = ABNFAlternation<UInt8>.concatenate([expr1, expr2, expr3, expr4])
			#expect(expression.description == "%x20.21.30.32.34.36.38");
		}

		@Test("numVal ++ numVal (range)")
		func test_concatenate_numVal_range() async throws {
			let expr1 = ABNFNumVal<UInt8>(base: .hex, value: .range(0x20...0x21)).alternation;
			let expr2 = ABNFNumVal<UInt8>(base: .hex, value: .range(0x30...0x39)).alternation;
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "%x20-21 %x30-39");
		}

		@Test("proseVal ++ proseVal")
		func test_concatenate_proseVal() async throws {
			let expr1 = ABNFProseVal<UInt8>(remark: "foo").alternation
			let expr2 = ABNFProseVal<UInt8>(remark: "bar").alternation
			let expression = expr1.concatenate(expr2);
			#expect(expression.description == "<foo> <bar>");
		}

		@Test("num-val hasUnion")
		func test_numVal_hasUnion() async throws {
			let rule1 = ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x20]))
			let rule2 = ABNFNumVal<UInt8>(base: .hex, value: .sequence([0x21]))
			let union = ABNFNumVal<UInt8>(base: .hex, value: .range(0x20...0x21))
			#expect(rule1.hasUnion(rule2) == union);
			#expect(rule1.hasUnion(rule2)!.description == "%x20-21");
		}
	}
	@Suite("ABNFBuiltins") struct ABNFTest_ABNFBuiltins {
		@Test("Compare source to builtin")
		func test_builtin_source() async throws {
			// From <https://www.rfc-editor.org/rfc/rfc5234.txt> pages 12-13
			let builtin_source = """
			ALPHA          =  %x41-5A / %x61-7A   ; A-Z / a-z

			BIT            =  "0" / "1"

			CHAR           =  %x01-7F
										  ; any 7-bit US-ASCII character,
										  ;  excluding NUL
			CR             =  %x0D
										  ; carriage return

			CRLF           =  CR LF
										  ; Internet standard newline

			CTL            =  %x00-1F / %x7F
										  ; controls

			DIGIT          =  %x30-39
										  ; 0-9

			DQUOTE         =  %x22
										  ; " (Double Quote)

			HEXDIG         =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F"

			HTAB           =  %x09
										  ; horizontal tab

			LF             =  %x0A
										  ; linefeed

			LWSP           =  *(WSP / CRLF WSP)
										  ; Use of this linear-white-space rule
										  ;  permits lines containing only white
										  ;  space that are no longer legal in
										  ;  mail headers and have caused
										  ;  interoperability problems in other
										  ;  contexts.
										  ; Do not use when defining mail
										  ;  headers and use with caution in
										  ;  other contexts.

			OCTET          =  %x00-FF
										  ; 8 bits of data

			SP             =  %x20

			VCHAR          =  %x21-7E
										  ; visible (printing) characters

			WSP            =  SP / HTAB
										  ; white space

			""";

			let referenceRulelist: ABNFRulelist<UInt8> = try ABNFRulelist<UInt8>.parse(builtin_source.replacing("\n", with: "\r\n").utf8);
			let referenceDictionary = try referenceRulelist.toPattern(as: DFA<Array<UInt8>>.self);
			assert(referenceDictionary.keys.count == 16);

			let providedDictionary = ABNFBuiltins<DFA<Array<UInt8>>>.dictionary;
			#expect(providedDictionary.keys.count == 16);

			providedDictionary.forEach { key, value in
				let difference = value.symmetricDifference(referenceDictionary[key]!)
				#expect(difference.finals.isEmpty, "Builtin rule \(key) mismatches reference, have values \(difference.toViz())")
			}

			#expect(providedDictionary["DIGIT"]!.alphabet == Set(0x30...0x39));
			#expect(providedDictionary["DIGIT"]!.alphabetPartitions == Set([ Set(0x30...0x39) ]));
		}

		@Test("HEXDIG")
		func test_HEXDIG() async throws {
			// Test across types
			#expect(ABNFBuiltins<DFA<Array<UInt>>>.HEXDIG.contains([0x30]))
			#expect(ABNFBuiltins<DFA<Array<UInt8>>>.HEXDIG.contains([0x30]))
			#expect(ABNFBuiltins<DFA<Array<UInt16>>>.HEXDIG.contains([0x30]))
			#expect(ABNFBuiltins<DFA<Array<UInt32>>>.HEXDIG.contains([0x30]))
			// FIXME: this should support Character...
			//#expect(ABNFBuiltins<Character>.HEXDIG.contains("0"))

			// Test case-insensitive
			#expect(ABNFBuiltins<DFA<Array<UInt>>>.HEXDIG.contains([0x41]))
			#expect(ABNFBuiltins<DFA<Array<UInt8>>>.HEXDIG.contains([0x61]))
		}
	}

	@Suite("conversions")
	struct ABNFTest_conversions {
		@Test("group.repeating(0...1) is an option")
		func test_group_optional() async throws {
			let input = "(foo)";
			let expression = try ABNFAlternation<UInt8>.parse(input.utf8)
			#expect(expression.description == "(foo)");
			// Since the goal is to shrink the expression to an equivlanent form,
			// an ABNFOption<UInt8> is smaller than an ABNFRepetition<UInt8>
			#expect(expression.repeating(0...1).description == "[foo]");
		}

		@Test("expression.element")
		func test_expression_element_2() async throws {
			let input = "foo [bar]";
			let expression = try ABNFAlternation<UInt8>.parse(input.utf8)
			#expect(expression.description == "foo [bar]");
			#expect(expression.repeating(2).description == "2(foo [bar])");
			#expect(expression.repeating(2...).description == "2*(foo [bar])");
		}
	}
}
