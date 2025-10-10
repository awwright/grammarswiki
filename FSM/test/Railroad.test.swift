import Testing;
@testable import FSM;

@Suite("Railroad Tests") struct RailroadTests {
	@Test("Terminal")
	func testTerminal() async throws {
		let diagram = RailroadTextNode.Terminal(text: "A");
		#expect(diagram.lines == [
			" ╭───╮ ",
			"─│ A │─",
			" ╰───╯ ",
		]);
	}

	@Test("NonTerminal")
	func testNonTerminal() async throws {
		let diagram = RailroadTextNode.NonTerminal(text: "rule");
		#expect(diagram.lines == [
			" ┌──────┐ ",
			"─│ rule │─",
			" └──────┘ ",
		])
	}

	@Test("Comment")
	func testComment() async throws {
		let diagram = RailroadTextNode.Comment(text: "comment");
		#expect(diagram.text == "comment")
	}

	@Test("Skip")
	func testSkip() async throws {
		let diagram = RailroadTextNode.Skip();
		#expect(diagram.text == "─")
	}

	@Test("Start")
	func testStart() async throws {
		let diagram = RailroadTextNode.Start(label: nil);
		#expect(diagram.text == "├┼─")
	}

	@Test("Start with label")
	func testStartWithLabel() async throws {
		let diagram = RailroadTextNode.Start(label: "begin");
		#expect(diagram.lines == [
			"begin",
			"├┼───",
		])
	}

	@Test("End")
	func testEnd() async throws {
		let diagram = RailroadTextNode.End(label: nil);
		#expect(diagram.text == "─┼┤")
	}

	@Test("Sequence")
	func testSequence() async throws {
		let diagram = RailroadTextNode.Sequence(
			RailroadTextNode.Terminal(text: "A"),
			RailroadTextNode.Terminal(text: "B"),
		);
		#expect(diagram.lines == [
			"  ╭───╮   ╭───╮ ",
			"──│ A │───│ B │─",
			"  ╰───╯   ╰───╯ "])
	}

	@Test("Choice")
	func testChoice() async throws {
		let diagram = RailroadTextNode.Choice(
			RailroadTextNode.Terminal(text: "A"),
			RailroadTextNode.Terminal(text: "B"),
		);
		#expect(diagram.lines == [
			"   ╭───╮   ",
			"╮──│ A │──╭",
			"│  ╰───╯  │",
			"│         │", // TODO: Remove this line
			"│  ╭───╮  │",
			"╰──│ B │──╯",
			"   ╰───╯   ",
		])
	}

	@Test("Optional")
	func testOptional() async throws {
		let diagram = RailroadTextNode.Optional(item: RailroadTextNode.Terminal(text: "A"));
		#expect(diagram.lines == [
			"╮─────────╭",
			"│         │", // TODO: Remove this line
			"│  ╭───╮  │",
			"╰──│ A │──╯",
			"   ╰───╯   ",
		])
	}

	@Test("OneOrMore")
	func testOneOrMore() async throws {
		let diagram = RailroadTextNode.OneOrMore(item: RailroadTextNode.Terminal(text: "A"));
		#expect(diagram.lines == [
			"   ╭───╮   ",
			"╭──│ A │──╮",
			"│  ╰───╯  │",
			"╰─────────╯",
		])
	}

	@Test("ZeroOrMore")
	func testZeroOrMore() async throws {
		let diagram = RailroadTextNode.ZeroOrMore(item: RailroadTextNode.Terminal(text: "A"));
		#expect(diagram.lines == [
			"╮─────────────╭",
			"│             │", // TODO: Remove this line
			"│    ╭───╮    │",
			"╰─╭──│ A │──╮─╯",
			"  │  ╰───╯  │  ",
			"  ╰─────────╯  ",
		])
	}

	@Test("Group")
	func testGroup() async throws {
		let diagram = RailroadTextNode.Group(item: RailroadTextNode.Terminal(text: "A"), label: "group");
		#expect(diagram.lines == [
			"             ", // TODO: Remove this line
			"    group    ", // TODO: Draw this label over dashed box
			" ╭┄┄┄┄┄┄┄┄┄╮ ",
			" ┆  ╭───╮  ┆ ",
			"─┼──│ A │──┼─",
			" ┆  ╰───╯  ┆ ",
			" ╰┄┄┄┄┄┄┄┄┄╯ ",
		])
	}

	@Test("Diagram")
	func testDiagram() async throws {
		let diagram = RailroadTextNode.Diagram(
			start: RailroadTextNode.Start(label: nil),
			sequence: [RailroadTextNode.Terminal(text: "A")],
			end: RailroadTextNode.End(label: nil),
		);
		#expect(diagram.lines == [
			"     ╭───╮     ",
			"├┼───│ A │───┼┤",
			"     ╰───╯     ",
		])
	}

	@Test("Stack")
	func testStack() async throws {
		let diagram = RailroadTextNode.Stack(
			RailroadTextNode.Terminal(text: "A"),
			RailroadTextNode.Terminal(text: "B"),
		);
		#expect(diagram.lines == [
			"   ╭───╮   ",
			"───│ A │──┐",
			"   ╰───╯  │",
			"┌─────────┘",
			"│  ╭───╮   ",
			"└──│ B │───",
			"   ╰───╯   ",
		])
	}

	@Test("OptionalSequence")
	func testOptionalSequence() async throws {
		let diagram = RailroadTextNode.OptionalSequence(
			RailroadTextNode.Terminal(text: "A"),
			RailroadTextNode.Terminal(text: "B"),
		);
		#expect(diagram.lines == [
			"╭───────────╮          ",
			"│  ╭───╮    │  ╭───╮   ",
			"╯──│ A │──╮─╰──│ B │──╭",
			"   ╰───╯  │    ╰───╯  │",
			"          ╰───────────╯",
		])
	}

	@Test("AlternatingSequence")
	func testAlternatingSequence() async throws {
		let diagram = RailroadTextNode.AlternatingSequence(RailroadTextNode.Terminal(text: "A"));
		#expect(diagram.lines == [
			" ╭───╮ ",
			"─│ A │─",
			" ╰───╯ ",
		])
	}

	@Test("HorizontalChoice")
	func testHorizontalChoice() async throws {
		let diagram = RailroadTextNode.HorizontalChoice(
			RailroadTextNode.Terminal(text: "A"),
			RailroadTextNode.Terminal(text: "B"),
		);
		#expect(diagram.lines == [
			"╭──────────╮          ",
			"│  ╭───╮   │  ╭───╮   ",
			"╯──│ A │──╮╰──│ B │──╭",
			"   ╰───╯  ││  ╰───╯  │",
			"          ╰──────────╯",
		]);
	}

	@Test("MultipleChoice")
	func testMultipleChoice() async throws {
		let diagram = RailroadTextNode.MultipleChoice(
			normal: 0,
			RailroadTextNode.Terminal(text: "A"),
			RailroadTextNode.Terminal(text: "B"),
		);
		#expect(diagram.lines == [
			" ┌────┐    ╭───╮    ┌───┐ ",
			"─│ 1+ │─╮──│ A │──╭─│ ↺ │─",
			" └────┘ │  ╰───╯  │ └───┘ ",
			"        │         │       ", // TODO: Remove this line
			"        │  ╭───╮  │       ",
			"        ╰──│ B │──╯       ",
			"           ╰───╯          ",
		]);
	}
}
