import Testing;
@testable import FSM;

@Suite("ABNF Tests") struct ABNFTests {
	@Test("rulelist")
	func test_rulelist      () async throws {
		let abnf = "rule1 = foo\r\nrule2 = \r\n\tfoo\r\nanother"
		let (rule, remainder) = ABNFRulelist.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation.match("foo".utf8)!
		#expect(rule == ABNFRulelist(rules: [
			ABNFRule(rulename: ABNFRulename(label: "rule1"), definedAs: "=", alternation: inner),
			ABNFRule(rulename: ABNFRulename(label: "rule2"), definedAs: "=", alternation: inner),
		]));
		#expect(CHAR_string(remainder) == "another");
	}

	@Test("rule")
	func test_rule() async throws {
		let abnf = "foo = bar\r\nanother"; // Must contain trailing \r\n, escape this for cross-platform reasons
		let (rule, remainder) = ABNFRule.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation.match("bar".utf8)!
		#expect(rule == ABNFRule(rulename: ABNFRulename(label: "foo"), definedAs: "=", alternation: inner));
		#expect(CHAR_string(remainder) == "another");
	}

	@Test("rulename")
	func test_rulename() async throws {
		let abnf = "foo ";
		let (rulename, remainder) = ABNFRulename.match(abnf.utf8)!
		#expect(rulename == ABNFRulename(label: "foo"));
		#expect(CHAR_string(remainder) == " ");
	}

	@Test("alternation")
	func test_alternation() async throws {
		let abnf = "foo / foo )";
		let (rule, remainder) = ABNFAlternation.match(abnf.utf8)!
		let (inner, _) = ABNFConcatenation.match("foo".utf8)!
		#expect(rule == ABNFAlternation(matches: [inner, inner]));
		#expect(CHAR_string(remainder) == " )");
	}

	@Test("concatenation")
	func test_concatenation() async throws {
		let abnf = "foo foo ";
		let (rule, remainder) = ABNFConcatenation.match(abnf.utf8)!
		let (inner, _) = ABNFRepetition.match("foo".utf8)!
		#expect(rule == ABNFConcatenation(repetitions: [inner, inner]));
		#expect(CHAR_string(remainder) == " ");
	}

	@Test("repetition 1")
	func test_repetition_1() async throws {
		let (foo, _) = ABNFElement.match("foo".utf8)!;
		let abnf = "foo ";
		let (rule, remainder) = ABNFRepetition.match(abnf.utf8)!
		#expect(rule == ABNFRepetition(min: 1, max: 1, element: foo));
		#expect(CHAR_string(remainder) == " ");
	}

	@Test("repetition min")
	func test_repetition_2() async throws {
		let (foo, _) = ABNFElement.match("foo".utf8)!;
		let abnf = "1*foo ";
		let (rule, remainder) = ABNFRepetition.match(abnf.utf8)!
		#expect(rule == ABNFRepetition(min: 1, max: nil, element: foo));
		#expect(CHAR_string(remainder) == " ");
	}

	@Test("repetition max")
	func test_repetition_3() async throws {
		let (foo, _) = ABNFElement.match("foo".utf8)!;
		let abnf = "*4foo ";
		let (rule, remainder) = ABNFRepetition.match(abnf.utf8)!
		#expect(rule == ABNFRepetition(min: 0, max: 4, element: foo));
		#expect(CHAR_string(remainder) == " ");
	}

	@Test("repetition min/max")
	func test_repetition_4() async throws {
		let (foo, _) = ABNFElement.match("foo".utf8)!;
		let abnf = "2*4foo ";
		let (rule, remainder) = ABNFRepetition.match(abnf.utf8)!
		#expect(rule == ABNFRepetition(min: 2, max: 4, element: foo));
		#expect(CHAR_string(remainder) == " ");
	}

	// element        =  rulename / group / option / char-val / num-val / prose-val
	@Test("element")
	func test_element() async throws {
		let abnf = "foo";
		let (rule, remainder) = ABNFElement.match(abnf.utf8)!
		#expect(rule == ABNFElement.rulename(ABNFRulename(label: "foo")));
		#expect(CHAR_string(remainder) == "");
	}

	@Test("group")
	func test_group() async throws {
		let abnf = "( foo )";
		let (rule, remainder) = ABNFGroup.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation.match("foo".utf8)!
		#expect(rule == ABNFGroup(alternation: inner));
		#expect(CHAR_string(remainder) == "");
	}

	@Test("option")
	func test_option() async throws {
		let abnf = "[ foo ]";
		let (rule, remainder) = ABNFOption.match(abnf.utf8)!
		let (inner, _) = ABNFAlternation.match("foo".utf8)!
		#expect(rule == ABNFOption(alternation: inner));
		#expect(CHAR_string(remainder) == "");
	}

	// char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
	@Test("char-val")
	func test_char_val() async throws {
		let abnf = """
		"foo"
		""";
		let (rule, remainder) = ABNFCharVal.match(abnf.utf8)!
		#expect(rule == ABNFCharVal(sequence: "foo".utf8.map{ UInt($0) }));
		#expect(CHAR_string(remainder) == "");
	}

	@Test("num-val w/ bin-val")
	func test_bin_val() async throws {
		let abnf = "%b100000.100000";
		let (rule, remainder) = ABNFNumVal.match(abnf.utf8)!
		#expect(rule == ABNFNumVal(base: .bin, value: .sequence([0x20, 0x20])));
		#expect(CHAR_string(remainder) == "");
	}

	@Test("num-val w/ dec-val")
	func test_dec_val() async throws {
		let abnf = "%d32.32";
		let (rule, remainder) = ABNFNumVal.match(abnf.utf8)!
		#expect(rule == ABNFNumVal(base: .dec, value: .sequence([0x20, 0x20])));
		#expect(CHAR_string(remainder) == "");
	}

	@Test("num-val w/ hex-val")
	func test_hex_val() async throws {
		let abnf = "%x20.20";
		let (rule, remainder) = ABNFNumVal.match(abnf.utf8)!
		#expect(rule == ABNFNumVal(base: .hex, value: .sequence([0x20, 0x20])));
		#expect(CHAR_string(remainder) == "");
	}

	@Test("prose_val")
	func test_prose_val() async throws {
		let input = "<Some message> 123".utf8;
		let (prose, remainder) = ABNFProseVal.match(input)!
		#expect(prose == ABNFProseVal(remark: "Some message"));
		#expect(CHAR_string(remainder) == " 123");
	}

	@Test("expression.toFSM")
	func test_rulelist_toFSM() async throws {
		let input = """
		"A" / "B" / 3"C"
		""";
		let (expression, _) = ABNFAlternation.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(fsm.contains("A".utf8.map{UInt($0)}));
	}

	@Test("repetition.toFSM optional")
	func test_repetition_optional_toFSM() async throws {
		let input = """
		0*1"C"
		""";
		let (expression, _) = ABNFRepetition.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(fsm.contains("".utf8.map{UInt($0)}));
		#expect(fsm.contains("C".utf8.map{UInt($0)}));
		#expect(!fsm.contains("CC".utf8.map{UInt($0)}));
	}

	@Test("repetition.toFSM plus")
	func test_repetition_plus_toFSM() async throws {
		let input = """
		1*"C"
		""";
		let (expression, _) = ABNFRepetition.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(!fsm.contains("".utf8.map{UInt($0)}));
		#expect(fsm.contains("C".utf8.map{UInt($0)}));
		#expect(fsm.contains("CC".utf8.map{UInt($0)}));
	}

	@Test("repetition.toFSM star")
	func test_repetition_star_toFSM() async throws {
		let input = """
		*"C"
		""";
		let (expression, _) = ABNFRepetition.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(fsm.contains("".utf8.map{UInt($0)}));
		#expect(fsm.contains("C".utf8.map{UInt($0)}));
		#expect(fsm.contains("CC".utf8.map{UInt($0)}));
	}

	@Test("repetition.toFSM min")
	func test_repetition_min_toFSM() async throws {
		let input = """
		2*"C"
		""";
		let (expression, _) = ABNFRepetition.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(!fsm.contains("C".utf8.map{UInt($0)}));
		#expect(fsm.contains("CC".utf8.map{UInt($0)}));
		#expect(fsm.contains("CCC".utf8.map{UInt($0)}));
	}

	@Test("repetition.toFSM max")
	func test_repetition_max_toFSM() async throws {
		let input = """
		*2"C"
		""";
		let (expression, _) = ABNFRepetition.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(fsm.contains("".utf8.map{UInt($0)}));
		#expect(fsm.contains("C".utf8.map{UInt($0)}));
		#expect(fsm.contains("CC".utf8.map{UInt($0)}));
		#expect(!fsm.contains("CCC".utf8.map{UInt($0)}));
	}

	@Test("repetition.toFSM min/max")
	func test_repetition_minmax_toFSM() async throws {
		let input = """
		2*3"C"
		""";
		let (expression, _) = ABNFRepetition.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(!fsm.contains("C".utf8.map{UInt($0)}));
		#expect(fsm.contains("CC".utf8.map{UInt($0)}));
		#expect(fsm.contains("CCC".utf8.map{UInt($0)}));
		#expect(!fsm.contains("CCCC".utf8.map{UInt($0)}));
	}

	@Test("element.toFSM")
	func test_element_toFSM() async throws {
		let input = """
		"C"
		""";
		let (expression, _) = ABNFElement.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(fsm.contains("C".utf8.map{UInt($0)}));
	}

	@Test("char_val.toFSM")
	func test_char_val_toFSM() async throws {
		let input = """
		"C"
		""";
		let (expression, _) = ABNFCharVal.match(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(fsm.contains("C".utf8.map{UInt($0)}));
	}

	@Test("rulelist.toFSM with rule")
	func test_rulelist_toFSM_2() async throws {
		let input = "Top = 3Rule\r\nRule = \"C\"\r\n";
		let expression = ABNFRulelist.parse(input.utf8)!
		let fsm = expression.toFSM(rules: [:]);
		#expect(fsm["Top"]!.contains("CCC".utf8.map{UInt($0)}));
	}

	@Test("ABNFAlternation#union")
	func test_abnf_upcast() async throws {
		let abnf = "%x20";
		let (rule, _) = ABNFNumVal.match(abnf.utf8)!
		#expect(rule.element.repetition.concatenation.alternation.toString() == abnf);
	}

	@Test("ABNFAlternation#union")
	func test_alternation_union() async throws {
		// Put it out of order just to see if it matches them
		let matches = [0x20, 0x29, 0x22, 0x27, 0x24, 0x25, 0x26, 0x23, 0x28, 0x21].map { ABNFNumVal(base: .hex, value: .sequence([$0])).element.repetition.concatenation }
		let expression = ABNFAlternation(matches:[]).union(ABNFAlternation(matches: matches))
		#expect(expression.toString() == "%x20-29");
	}

	@Test("num-val hasUnion")
	func test_numVal_hasUnion() async throws {
		let (rule1, _) = ABNFNumVal.match("%x20".utf8)!
		let (rule2, _) = ABNFNumVal.match("%x21".utf8)!
		let (union, _) = ABNFNumVal.match("%x20-21".utf8)!
		#expect(rule1.hasUnion(rule2) == union);
		#expect(rule1.hasUnion(rule2)!.toString() == "%x20-21");
	}
}
