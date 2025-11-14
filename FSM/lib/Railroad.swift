/// A protocol for constructing railroad diagrams, which visually represent syntax patterns.
///
/// Railroad diagrams are graphical notations for describing the structure of formal grammars,
/// commonly used in specifications like ABNF. Each method corresponds to a syntactic construct
/// and can be mapped to regular expression patterns.
///
/// - Note: Implementations of this protocol provide concrete types for rendering or processing
///   these diagrams in different contexts (e.g., SVG generation, parsing).
public protocol RailroadDiagramProtocol {
	/// Creates a complete railroad diagram with a start point, a sequence of elements, and an end point.
	///
	/// This represents the overall structure of a grammar rule, starting from an initial state,
	/// proceeding through a sequence of constructs, and ending at a terminal state.
	///
	/// ```
	/// Two  ┌───┐
	/// ├┼───│ 2 │─┼┤
	///      └───┘
	/// ```
	///
	/// - Parameters:
	///   - start: The starting element of the diagram.
	///   - sequence: An array of elements forming the main body of the diagram.
	///   - end: The ending element of the diagram.
	/// - Returns: A diagram element encompassing the entire structure.
	///
	/// - Example: A simple rule like `rule = start sequence end` corresponds to a regex pattern
	///   where the sequence is concatenated: `startsequenceend`.
	static func Diagram(start: Self, sequence: [Self], end: Self) -> Self

	/// Creates a sequence of elements that must appear in order.
	///
	/// This represents concatenation in formal grammars, where elements follow each other sequentially.
	///
	/// ```
	///  ┌───┐   ┌───┐   ┌───┐
	/// ─┤ 1 ├───┤ 2 ├───┤ 3 ├─
	///  └───┘   └───┘   └───┘
	/// ```
	///
	/// - Parameter items: An array of elements to be sequenced.
	/// - Returns: A diagram element representing the ordered sequence.
	///
	/// - Example: `Sequence([A, B, C])` represents the pattern `ABC`, equivalent to the regex `ABC`.
	static func Sequence(items: [Self]) -> Self

	/// Creates a vertical stack of elements, typically representing parallel or layered constructs.
	///
	/// This can represent overlapping or simultaneous elements in a diagram, often used for
	/// complex compositions where elements are arranged vertically.
	///
	/// ```
	///    ┌───┐
	/// ───┤ 1 ├──╮
	///    └───┘  │
	/// ╭─────────╯
	/// │  ┌───┐
	/// ╰──┤ 2 ├──╮
	///    └───┘  │
	/// ╭─────────╯
	/// │  ┌───┐
	/// ╰──┤ 3 ├───
	///    └───┘
	/// ```
	///
	/// - Parameter items: An array of elements to be stacked.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - Example: `Stack([A, B])` might represent layered patterns, conceptually similar to
	///   regex patterns that need to be combined in a non-linear fashion, though direct regex
	///   equivalence is context-dependent.
	static func Stack(items: [Self]) -> Self

	/// A sequence of elements where at least one element must appear, and elements must appear in order.
	///
	/// ```
	/// ╭───────────╮─────────────╮
	/// │  ┌───┐    │  ┌───┐      │  ┌───┐
	/// ╯──┤ 1 ├──╮─╰──┤ 2 ├──╭─╮─╰──┤ 3 ├──╭
	///    └───┘  │    └───┘  │ │    └───┘  │
	///           ╰───────────╯ ╰───────────╯
	/// ```
	///
	/// - Parameter items: An array of elements forming the optional sequence.
	/// - Returns: A diagram element representing the optional sequence.
	///
	/// - Example: `OptionalSequence([A, B])` represents `(AB)?`, equivalent to the regex `(AB)?`.
	static func OptionalSequence(items: [Self]) -> Self

	/// Creates a sequence where elements alternate or are mutually exclusive in a specific order.
	///
	/// Limit two elements.
	///
	/// This represents patterns where elements must appear in an alternating fashion,
	/// often used for constructs like key-value pairs or repeating alternations.
	///
	/// ```
	///     ┌───┐
	///  ╭──┤ 1 ├──╮
	///  │  └───┘  │
	/// ╭╰───╮ ╭───┴╮
	/// ┤     ╳     ├
	/// ╰╭───╯ ╰───┬╯
	///  │  ┌───┐  │
	///  ╰──┤ 2 ├──╯
	///     └───┘
	/// ```
	///
	/// - Parameter items: An array of elements to alternate.
	/// - Returns: A diagram element representing the alternating sequence.
	///
	/// - Example: `AlternatingSequence([A, B, A, B])` might represent `ABAB`, equivalent to the regex `(AB)+`.
	static func AlternatingSequence(items: [Self]) -> Self

	/// Creates a choice between multiple alternative elements.
	///
	/// This represents alternation in grammars, where one of the provided elements must be chosen.
	///
	/// - Parameter items: An array of alternative elements.
	/// - Returns: A diagram element representing the choice.
	///
	/// ```
	///     ┌───┐
	///  ╮──┤ 1 ├──╭
	///  │  └───┘  │
	///  │  ┌───┐  │
	///  ╰──┤ 2 ├──╯
	///  │  └───┘  │
	///  │  ┌───┐  │
	///  ╰──┤ 3 ├──╯
	///     └───┘
	/// ```
	///
	/// - Example: `Choice(items: [A, B, C])` represents to the regex `A|B|C`.
	static func Choice(items: [Self]) -> Self

	/// Creates a horizontal choice between multiple alternative elements.
	///
	/// Similar to `Choice`, but arranged horizontally in the diagram for visual distinction.
	/// Useful for case-insensitive forms of strings.
	///
	/// ```
	/// ╭──────────╮──────────╮
	/// │  ┌───┐   │  ┌───┐   │  ┌───┐
	/// ╯──┤ 1 ├──╮╰──┤ 2 ├──╮╰──┤ 3 ├──╭
	///    └───┘  │   └───┘  │   └───┘  │
	///           ╰──────────╰──────────╯
	/// ```
	///
	/// - Parameter items: An array of alternative elements.
	/// - Returns: A diagram element representing the horizontal choice.
	///
	/// - Example: `HorizontalChoice(items: [A, B])` is equivalent to the regex `A|B`.
	static func HorizontalChoice(items: [Self]) -> Self

	/// Creates a choice with a designated "normal" or default option among alternatives.
	///
	/// This represents a prioritized choice where one option is highlighted as the primary path,
	/// while others are available alternatives.
	///
	/// ```
	///    ╭───╮
	/// ╮──│ 1 │──╭
	/// │  ╰───╯  │
	/// │  ╭───╮  │
	/// ╰──│ 2 │──╯
	///    ╰───╯
	/// ```
	///
	/// - Parameters:
	///   - normal: The index of the normal or default choice in the items array.
	///   - items: An array of alternative elements.
	/// - Returns: A diagram element representing the multiple choice with a normal option.
	///
	/// - Example: `MultipleChoice(normal: 0, items: [A, B])` represents a choice where `A` is normal,
	///   equivalent to the regex `A|B` but with visual emphasis on `A`.
	static func MultipleChoice(normal: Int, items: [Self]) -> Self

	/// Creates an optional element that may or may not appear.
	///
	/// This represents an element that is optional, meaning it can be present zero or one time.
	/// ```
	/// ╮─────────╭
	/// │  ┌───┐  │
	/// ╰──┤ X ├──╯
	///    └───┘
	/// ```
	///
	/// - Parameter item: The element to make optional.
	/// - Returns: A diagram element representing the optional item.
	///
	/// - Example: `Optional(A)` represents `A?`, equivalent to the regex `A?`.
	static func Optional(item: Self) -> Self

	/// Creates an element that must appear one or more times, with an optional maximum.
	///
	/// This represents repetition where the element occurs at least once, up to a specified maximum
	/// if provided, or unbounded otherwise.
	///
	/// ```
	///     ┌───┐
	/// ─╭──┤ X ├──╮─
	///  │  └───┘  │
	///  ╰─────────╯
	/// ```
	///
	/// If separator is defined, then it is placed in the track while looping back to the start. For example, a comma:
	///
	/// ```
	///     ┌─────────┐
	/// ─╭──┤ Element ├──╮─
	///  │  └─────────┘  │
	///  │     ╭───╮     │
	///  ╰─────┤ , ├─────╯
	///        ╰───╯
	/// ```
	///
	/// - Parameters:
	///   - item: The element to repeat.
	///   - separator: An element that goes in between repeated elements, if any
	///   - max: A string representing the maximum number of repetitions (e.g., "3" for up to 3 times).
	/// - Returns: A diagram element representing the repeated item.
	///
	/// - Example: `OneOrMore(A, max: "3")` represents `A{1,3}`, equivalent to the regex `A{1,3}`.
	///   Without max, it represents `A+`, equivalent to `A+`.
	static func Loop(item: Self, separator: Self?, max: String) -> Self

	/// Creates an element that may appear zero or more times.
	///
	/// This represents optional repetition, where the element can be absent or repeated multiple times.
	///
	/// ```
	/// ╮─────────────╭
	/// │    ┌───┐    │
	/// ╰─╭──┤ X ├──╮─╯
	///   │  └───┘  │
	///   ╰─────────╯
	/// ```
	///
	/// - Parameter item: The element to repeat optionally.
	/// - Returns: A diagram element representing the zero-or-more repetition.
	///
	/// - Example: `ZeroOrMore(A)` represents `A*`, equivalent to the regex `A*`.
	static func ZeroOrMore(item: Self, separator: Self?) -> Self

	/// Groups an element with a descriptive label for clarity in the diagram.
	///
	/// This wraps an element in a group, often for organizational purposes or to provide
	/// semantic meaning, without changing the underlying pattern.
	///
	/// ```
	///  ╭ Label ┄┄╮
	///  ┆  ┌───┐  ┆
	/// ────┤ X ├────
	///  ┆  └───┘  ┆
	///  ╰┄┄┄┄┄┄┄┄┄╯
	/// ```
	///
	/// - Parameters:
	///   - item: The element to group.
	///   - label: A string label describing the group.
	/// - Returns: A diagram element representing the grouped item.
	///
	/// - Example: `Group(A, label: "identifier")` represents the same pattern as `A`, but labeled,
	///   conceptually similar to named groups in regex like `(?<identifier>A)`.
	static func Group(item: Self, label: String) -> Self

	/// Creates the starting point of a railroad diagram.
	///
	/// This represents the entry point of a grammar rule or pattern.
	///
	/// ```
	/// Label
	/// ├┼───
	/// ```
	///
	/// - Parameter label: An optional label for the start point.
	/// - Returns: A diagram element representing the start.
	///
	/// - Example: `Start(label: "begin")` marks the beginning of a pattern, analogous to the start
	///   of a regex string.
	static func Start(label: String?) -> Self

	/// Creates the ending point of a railroad diagram.
	///
	/// This represents the exit point or conclusion of a grammar rule or pattern.
	///
	/// ```
	/// ─┼┤
	/// ```
	///
	/// - Parameter label: An optional label for the end point.
	/// - Returns: A diagram element representing the end.
	///
	/// - Example: `End(label: "finish")` marks the end of a pattern, analogous to the end
	///   of a regex string.
	static func End(label: String?) -> Self

	/// Creates a terminal element representing literal text that must match exactly.
	///
	/// This represents fixed strings or characters in the grammar that are matched literally.
	/// Usually represented with a circle.
	///
	/// ```
	/// ╭───╮
	/// │ A │
	/// ╰───╯
	/// ```
	///
	/// - Parameter text: The literal text to match.
	/// - Returns: A diagram element representing the terminal.
	///
	/// - Example: `Terminal("hello")` represents the literal string `"hello"`, equivalent to the regex `hello`.
	static func Terminal(text: String) -> Self

	/// Creates a non-terminal element referencing another grammar rule.
	///
	/// This represents a reference to a named rule or sub-pattern defined elsewhere in the grammar.
	/// Usually represented with a square or rectangle.
	///
	/// ```
	/// ┌──────────┐
	/// │ Rulename │
	/// └──────────┘
	/// ```
	///
	/// - Parameter text: The name of the referenced rule.
	/// - Returns: A diagram element representing the non-terminal reference.
	///
	/// - Example: `NonTerminal("identifier")` references a rule named `identifier`, similar to
	///   calling a subroutine in regex patterns or using rule names in grammars.
	static func NonTerminal(text: String) -> Self

	/// Creates a comment element for annotations in the diagram.
	///
	/// This adds explanatory text to the diagram without affecting the pattern itself.
	/// Not typically rendered with any surrounding border.
	///
	/// - Parameter text: The comment text.
	/// - Returns: A diagram element representing the comment.
	///
	/// - Example: `Comment("This matches a number")` adds a note, not part of the regex pattern.
	static func Comment(text: String) -> Self

	/// Creates a skip element representing an empty or null operation.
	///
	/// This can represent optional whitespace, empty productions, or points where no action is taken.
	///
	/// - Returns: A diagram element representing a skip.
	///
	/// - Example: `Skip()` represents an empty match, equivalent to an empty string in regex `""`.
	static func Skip() -> Self
}

extension RailroadDiagramProtocol {
	/// Convenience method for creating a sequence with variadic arguments.
	///
	/// - Parameter label: The label to use on the start element.
	/// - Parameter items: The elements to sequence.
	/// - Returns: A diagram element representing the ordered sequence.
	///
	/// - SeeAlso: `Sequence(items:)`
	static func Diagram(label: String = "",_ items: Self...) -> Self {
		Self.Diagram(start: Self.Start(label: label), sequence: items, end: Self.End(label: ""))
	}

	/// Convenience method for creating a sequence with variadic arguments.
	///
	/// - Parameter items: The elements to sequence.
	/// - Returns: A diagram element representing the ordered sequence.
	///
	/// - SeeAlso: `Sequence(items:)`
	static func Sequence(_ items: Self...) -> Self {
		Self.Sequence(items: items)
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `Stack(items:)`
	static func Stack(_ items: Self...) -> Self {
		Self.Stack(items: items)
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `Stack(items:)`
	static func OptionalSequence(_ items: Self...) -> Self {
		Self.OptionalSequence(items: items);
	}

	/// Convenience method for creating an AlternatingSequence with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `AlternatingSequence(items:)`
	static func AlternatingSequence(_ items: Self...) -> Self {
		Self.AlternatingSequence(items: items);
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `Choice(items:)`
	static func Choice(_ items: Self...) -> Self {
		Self.Choice(items: items);
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `HorizontalChoice(items:)`
	static func HorizontalChoice(_ items: Self...) -> Self {
		Self.HorizontalChoice(items: items);
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `MultipleChoice(normal:items:)`
	static func MultipleChoice(normal: Int = 0, _ items: Self...) -> Self {
		Self.MultipleChoice(normal: normal, items: items);
	}

	/// An shorthand for ``OneOrMore(item:separator:max:)``
	public static func OneOrMore(_ item: Self, separator: Self? = nil, max: String = "") -> Self {
		Loop(item: item, separator: separator, max: max)
	}
}

public indirect enum RailroadNode: RailroadDiagramProtocol, Hashable {
	case Diagram(start: RailroadNode, sequence: [RailroadNode], end: RailroadNode)
	case Sequence(items: [RailroadNode])
	case Stack(items: [RailroadNode])
	case OptionalSequence(items: [RailroadNode])
	case AlternatingSequence(items: [RailroadNode])
	case Choice(items: [RailroadNode])
	case HorizontalChoice(items: [RailroadNode])
	case MultipleChoice(normal: Int, items: [RailroadNode])
	case Group(item: RailroadNode, label: String)
	case Optional(item: RailroadNode)
	case ZeroOrMore(item: RailroadNode, separator: RailroadNode?)
	case Loop(item: RailroadNode, separator: RailroadNode?, max: String)
	case Start(label: String?)
	case End(label: String?)
	case Terminal(text: String)
	case NonTerminal(text: String)
	case Comment(text: String)
	case Skip
	public static func Skip() -> RailroadNode { .Skip }
}
