import Testing;
@testable import FSM;

@Suite("ABNF Tests") struct ABNFTests {
	@Test("rulelist")
	func test_rulelist() async throws {
		let abnf = "rule1 = foo\r\nrule2 = \r\n\tfoo\r\nanother"
		let (rule, remainder) = ABNFRulelist<UInt8>.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation<UInt8>.match("foo".utf8)!
		#expect(rule == ABNFRulelist<UInt8>(rules: [
			ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule1"), definedAs: .equal, alternation: inner),
			ABNFRule(rulename: ABNFRulename<UInt8>(label: "rule2"), definedAs: .equal, alternation: inner),
		]));
		#expect(CHAR_string(remainder) == "another");
	}

	@Test("rule")
	func test_rule() async throws {
		let abnf = "foo = bar\r\nanother"; // Must contain trailing \r\n, escape this for cross-platform reasons
		let (rule, remainder) = ABNFRule<UInt8>.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation<UInt8>.match("bar".utf8)!
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
		let (rule, remainder) = ABNFAlternation<UInt8>.match(abnf.utf8)!
		let (inner, _) = ABNFConcatenation<UInt8>.match("foo".utf8)!
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
		let (rule, remainder) = ABNFAlternation<UInt8>.match(abnf.utf8)!
		let (inner, _) = ABNFConcatenation<UInt8>.match("foo".utf8)!
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
		let (rule, remainder) = ABNFConcatenation<UInt8>.match(abnf.utf8)!
		let (inner, _) = ABNFRepetition<UInt8>.match("foo".utf8)!
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
		let (rule, remainder) = ABNFConcatenation<UInt8>.match(abnf.utf8)!
		let inner1 = ABNFRepetition<UInt8>.parse("foo".utf8)!
		let inner2 = ABNFRepetition<UInt8>.parse("bar".utf8)!
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
		let (rule, remainder) = ABNFRepetition<UInt8>.match(abnf.utf8)!
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
		let (foo, _) = ABNFElement<UInt8>.match("foo".utf8)!;
		let abnf = "foo ";
		let (rule, remainder) = ABNFRepetition<UInt8>.match(abnf.utf8)!
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
		let (foo, _) = ABNFElement<UInt8>.match("foo".utf8)!;
		let abnf = "1*foo ";
		let (rule, remainder) = ABNFRepetition<UInt8>.match(abnf.utf8)!
		#expect(rule == ABNFRepetition<UInt8>(min: 1, max: nil, element: foo));
		#expect(CHAR_string(remainder) == " ");
		#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
		#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
		#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: nil, element: ABNFRulename<UInt8>.parse("foo".utf8)!.element))
		#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
		#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
		#expect(rule.isEmpty == false)
		#expect(rule.isOptional == false)
	}

	@Test("repetition max")
	func test_repetition_3() async throws {
		let (foo, _) = ABNFElement<UInt8>.match("foo".utf8)!;
		let abnf = "*4foo ";
		let (rule, remainder) = ABNFRepetition<UInt8>.match(abnf.utf8)!
		#expect(rule == ABNFRepetition<UInt8>(min: 0, max: 4, element: foo));
		#expect(CHAR_string(remainder) == " ");
		#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
		#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
		#expect(rule.repetition == ABNFRepetition<UInt8>(min: 0, max: 4, element: ABNFRulename<UInt8>.parse("foo".utf8)!.element))
		#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
		#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
		#expect(rule.isEmpty == false)
		#expect(rule.isOptional == true)
	}

	@Test("repetition min/max")
	func test_repetition_4() async throws {
		let (foo, _) = ABNFElement<UInt8>.match("foo".utf8)!;
		let abnf = "2*4foo ";
		let (rule, remainder) = ABNFRepetition<UInt8>.match(abnf.utf8)!
		#expect(rule == ABNFRepetition<UInt8>(min: 2, max: 4, element: foo));
		#expect(CHAR_string(remainder) == " ");
		#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
		#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
		#expect(rule.repetition == ABNFRepetition<UInt8>(min: 2, max: 4, element: ABNFRulename<UInt8>.parse("foo".utf8)!.element))
		#expect(rule.element == ABNFElement<UInt8>.group(rule.group))
		#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
		#expect(rule.isEmpty == false)
		#expect(rule.isOptional == false)
	}

	// element        =  rulename / group / option / char-val / num-val / prose-val
	@Test("element of rulename")
	func test_element_rulename() async throws {
		let abnf = "foo";
		let (rule, remainder) = ABNFElement<UInt8>.match(abnf.utf8)!
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

	@Test("element of group")
	func test_element_group() async throws {
		let abnf = "(foo)";
		let (rule, remainder) = ABNFElement<UInt8>.match(abnf.utf8)!
		#expect(rule == ABNFElement<UInt8>.group(ABNFGroup<UInt8>(alternation: ABNFAlternation<UInt8>(matches: [ABNFConcatenation<UInt8>(repetitions: [ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.rulename(ABNFRulename<UInt8>(label: "foo")))])]))));
		#expect(CHAR_string(remainder) == "");
		#expect(rule.alternation == ABNFAlternation<UInt8>(matches: [rule.concatenation]))
		#expect(rule.concatenation == ABNFConcatenation<UInt8>(repetitions: [rule.repetition]))
		#expect(rule.repetition == ABNFRepetition<UInt8>(min: 1, max: 1, element: rule.element))
		#expect(rule.element == rule)
		#expect(rule.group == ABNFGroup<UInt8>(alternation: rule.alternation))
		#expect(rule.isEmpty == false)
		#expect(rule.isOptional == false)
	}

	@Test("element of option")
	func test_element_option() async throws {
		let abnf = "[foo]";
		let (rule, remainder) = ABNFElement<UInt8>.match(abnf.utf8)!
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
		let (rule, remainder) = ABNFElement<UInt8>.match(abnf.utf8)!
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
		let (rule, remainder) = ABNFElement<UInt8>.match(abnf.utf8)!
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
		let (rule, remainder) = ABNFElement<UInt8>.match(abnf.utf8)!
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
		let (rule, remainder) = ABNFGroup<UInt8>.match(abnf.utf8)!
		let inner = ABNFAlternation<UInt8>.parse("0<>".utf8)!
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
		let (rule, remainder) = ABNFGroup<UInt8>.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation<UInt8>.match("foo".utf8)!
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
		let (rule, remainder) = ABNFGroup<UInt8>.match(abnf.utf8)!
		let inner = ABNFAlternation<UInt8>.parse("foo / bar".utf8)!
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
		let (rule, remainder) = ABNFGroup<UInt8>.match(abnf.utf8)!
		let inner = ABNFConcatenation<UInt8>.parse("foo bar".utf8)!
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
		let (rule, remainder) = ABNFOption<UInt8>.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation<UInt8>.match("foo".utf8)!
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
		let (rule, remainder) = ABNFCharVal<UInt8>.match(abnf.utf8)!
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
		let (rule, remainder) = ABNFNumVal<UInt8>.match(abnf.utf8)!
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
		let (rule, remainder) = ABNFNumVal<UInt8>.match(abnf.utf8)!
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
		let (rule, remainder) = ABNFNumVal<UInt8>.match(abnf.utf8)!
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
		let (prose, remainder) = ABNFProseVal<UInt8>.match(input)!
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

	@Test("expression.toPattern")
	func test_rulelist_toPattern() async throws {
		let input = """
		"A" / "B" / 3"C"
		""";
		let (expression, _) = ABNFAlternation<UInt8>.match(input.utf8)!
		let fsm = expression.toPattern(as: DFA<Array<UInt8>>.self);
		#expect(fsm.contains("A".utf8));
	}

	@Test("repetition.toPattern optional")
	func test_repetition_optional_toPattern() async throws {
		let input = """
		0*1"C"
		""";
		let (expression, _) = ABNFRepetition<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(fsm.contains("".utf8));
		#expect(fsm.contains("C".utf8));
		#expect(!fsm.contains("CC".utf8));
	}

	@Test("repetition.toPattern plus")
	func test_repetition_plus_toPattern() async throws {
		let input = """
		1*"C"
		""";
		let (expression, _) = ABNFRepetition<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(!fsm.contains("".utf8));
		#expect(fsm.contains("C".utf8));
		#expect(fsm.contains("CC".utf8));
	}

	@Test("repetition.toPattern star")
	func test_repetition_star_toPattern() async throws {
		let input = """
		*"C"
		""";
		let (expression, _) = ABNFRepetition<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(fsm.contains("".utf8));
		#expect(fsm.contains("C".utf8));
		#expect(fsm.contains("CC".utf8));
	}

	@Test("repetition.toPattern min")
	func test_repetition_min_toPattern() async throws {
		let input = """
		2*"C"
		""";
		let (expression, _) = ABNFRepetition<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(!fsm.contains("C".utf8));
		#expect(fsm.contains("CC".utf8));
		#expect(fsm.contains("CCC".utf8));
	}

	@Test("repetition.toPattern max")
	func test_repetition_max_toPattern() async throws {
		let input = """
		*2"C"
		""";
		let (expression, _) = ABNFRepetition<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(fsm.contains("".utf8));
		#expect(fsm.contains("C".utf8));
		#expect(fsm.contains("CC".utf8));
		#expect(!fsm.contains("CCC".utf8));
	}

	@Test("repetition.toPattern min/max")
	func test_repetition_minmax_toPattern() async throws {
		let input = """
		2*3"C"
		""";
		let (expression, _) = ABNFRepetition<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(!fsm.contains("C".utf8));
		#expect(fsm.contains("CC".utf8));
		#expect(fsm.contains("CCC".utf8));
		#expect(!fsm.contains("CCCC".utf8));
	}

	@Test("element.toPattern")
	func test_element_toPattern() async throws {
		let input = """
		"C"
		""";
		let (expression, _) = ABNFElement<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(fsm.contains("C".utf8));
	}

	@Test("char_val.toPattern")
	func test_char_val_toPattern() async throws {
		let input = """
		"C"
		""";
		let (expression, _) = ABNFCharVal<UInt8>.match(input.utf8)!
		let fsm: DFA<Array<UInt8>> = expression.toPattern(rules: [:]);
		#expect(fsm.contains("C".utf8));
	}

	@Test("rulelist.toPattern with rule")
	func test_rulelist_toPattern_2() async throws {
		let input = "Top = 3Rule\r\nRule = \"C\"\r\n";
		let expression = ABNFRulelist<UInt8>.parse(input.utf8)!
		let fsm: Dictionary<String, DFA<Array<UInt8>>> = expression.toPattern(rules: [:]);
		#expect(fsm["Top"]!.contains("CCC".utf8));
	}

	@Test("ABNFAlternation<UInt8>#union")
	func test_abnf_upcast() async throws {
		let abnf = "%x20";
		let (rule, _) = ABNFNumVal<UInt8>.match(abnf.utf8)!
		#expect(rule.description == abnf);
	}

	@Test("ABNFAlternation<UInt8>#union")
	func test_alternation_union() async throws {
		// Put it out of order just to see if it matches them
		let matches = [0x20, 0x29, 0x22, 0x27, 0x24, 0x25, 0x26, 0x23, 0x28, 0x21].map {
			ABNFConcatenation<UInt8>(repetitions: [ABNFRepetition<UInt8>(min: 1, max: 1, element: ABNFElement<UInt8>.numVal(ABNFNumVal<UInt8>(base: .hex, value: .sequence([$0]))))])
		}
		let expression = ABNFAlternation<UInt8>(matches:[]).union(ABNFAlternation<UInt8>(matches: matches))
		#expect(expression.description == "%x20-29");
	}

	@Test("ABNFConcatenation<UInt8>#concatenate")
	func test_concatenation_concatenate() async throws {
		let expr1 = ABNFConcatenation<UInt8>.parse("foo".utf8)!;
		let expr2 = ABNFConcatenation<UInt8>.parse("0<>".utf8)!;
		let expr3 = ABNFConcatenation<UInt8>.parse("bar".utf8)!;
		let expression = expr1.concatenate(expr2).concatenate(expr3);
		#expect(expression.description == "foo bar");
	}

	@Test("ABNFRepetition<UInt8>.element")
	func test_expression_element() async throws {
		let input = "foo";
		let expression = ABNFAlternation<UInt8>.parse(input.utf8)!
		#expect(expression.description == "foo");
		#expect(expression.repeating(2).description == "2foo");
		#expect(expression.repeating(2...).description == "2*foo");
		// TODO: Handle as a special case
		//#expect(expression.repeating(0...1).description == "[foo]");
	}

	@Test("group.repeating(0...1) is an option")
	func test_group_optional() async throws {
		let input = "(foo)";
		let expression = ABNFAlternation<UInt8>.parse(input.utf8)!
		#expect(expression.description == "(foo)");
		// Since the goal is to shrink the expression to an equivlanent form,
		// an ABNFOption<UInt8> is smaller than an ABNFRepetition<UInt8>
		#expect(expression.repeating(0...1).description == "[foo]");
	}

	@Test("expression.element")
	func test_expression_element_2() async throws {
		let input = "foo [bar]";
		let expression = ABNFAlternation<UInt8>.parse(input.utf8)!
		#expect(expression.description == "foo [bar]");
		#expect(expression.repeating(2).description == "2(foo [bar])");
		#expect(expression.repeating(2...).description == "2*(foo [bar])");
	}

	@Test("num-val hasUnion")
	func test_numVal_hasUnion() async throws {
		let (rule1, _) = ABNFNumVal<UInt8>.match("%x20".utf8)!
		let (rule2, _) = ABNFNumVal<UInt8>.match("%x21".utf8)!
		let (union, _) = ABNFNumVal<UInt8>.match("%x20-21".utf8)!
		#expect(rule1.hasUnion(rule2) == union);
		#expect(rule1.hasUnion(rule2)!.description == "%x20-21");
	}
}
