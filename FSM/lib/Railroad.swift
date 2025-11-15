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
	static func Diagram(start: Self, sequence: [Self], end: Self, attributes: RRAttributeDict) -> Self

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
	static func Sequence(items: [Self], attributes: RRAttributeDict) -> Self

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
	static func Stack(items: [Self], attributes: RRAttributeDict) -> Self

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
	static func OptionalSequence(items: [Self], attributes: RRAttributeDict) -> Self

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
	static func AlternatingSequence(items: [Self], attributes: RRAttributeDict) -> Self

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
	static func Choice(items: [Self], attributes: RRAttributeDict) -> Self

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
	static func HorizontalChoice(items: [Self], attributes: RRAttributeDict) -> Self

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
	static func MultipleChoice(normal: Int, items: [Self], attributes: RRAttributeDict) -> Self

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
	static func Optional(item: Self, attributes: RRAttributeDict) -> Self

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
	static func Loop(item: Self, separator: Self?, max: String, attributes: RRAttributeDict) -> Self

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
	static func ZeroOrMore(item: Self, separator: Self?, attributes: RRAttributeDict) -> Self

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
	static func Group(item: Self, label: String, attributes: RRAttributeDict) -> Self

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
	static func Start(label: String?, attributes: RRAttributeDict) -> Self

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
	static func End(label: String?, attributes: RRAttributeDict) -> Self

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
	static func Terminal(text: String, attributes: RRAttributeDict) -> Self

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
	static func NonTerminal(text: String, attributes: RRAttributeDict) -> Self

	/// Creates a comment element for annotations in the diagram.
	///
	/// This adds explanatory text to the diagram without affecting the pattern itself.
	/// Not typically rendered with any surrounding border.
	///
	/// - Parameter text: The comment text.
	/// - Returns: A diagram element representing the comment.
	///
	/// - Example: `Comment("This matches a number")` adds a note, not part of the regex pattern.
	static func Comment(text: String, attributes: RRAttributeDict) -> Self

	/// Creates a skip element representing an empty or null operation.
	///
	/// This can represent optional whitespace, empty productions, or points where no action is taken.
	///
	/// - Returns: A diagram element representing a skip.
	///
	/// - Example: `Skip()` represents an empty match, equivalent to an empty string in regex `""`.
	static func Skip(attributes: RRAttributeDict) -> Self
}

extension RailroadDiagramProtocol {
	/// Convenience method for creating a sequence with variadic arguments.
	///
	/// - Parameter label: The label to use on the start element.
	/// - Parameter items: The elements to sequence.
	/// - Returns: A diagram element representing the ordered sequence.
	///
	/// - SeeAlso: ``Diagram(start:sequence:end:attributes:)``
	static func Diagram(label: String = "",_ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.Diagram(start: Self.Start(label: label, attributes: [:]), sequence: items, end: Self.End(label: "", attributes: [:]), attributes: attributes)
	}

	/// Convenience method for creating a sequence with variadic arguments.
	///
	/// - Parameter items: The elements to sequence.
	/// - Returns: A diagram element representing the ordered sequence.
	///
	/// - SeeAlso: ``Sequence(items:attributes:)``
	static func Sequence(_ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.Sequence(items: items, attributes: attributes)
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: ``Stack(items:attributes:)``
	static func Stack(_ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.Stack(items: items, attributes: attributes)
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `Stack(items:attributes:)`
	static func OptionalSequence(_ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.OptionalSequence(items: items, attributes: attributes);
	}

	/// Convenience method for creating an AlternatingSequence with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `AlternatingSequence(items:attributes:)`
	static func AlternatingSequence(_ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.AlternatingSequence(items: items, attributes: attributes);
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `Choice(items:)`
	static func Choice(_ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.Choice(items: items, attributes: attributes);
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `HorizontalChoice(items:)`
	static func HorizontalChoice(_ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.HorizontalChoice(items: items, attributes: attributes);
	}

	/// Convenience method for creating a stack with variadic arguments.
	///
	/// - Parameter items: The elements to stack.
	/// - Returns: A diagram element representing the vertical stack.
	///
	/// - SeeAlso: `MultipleChoice(normal:items:)`
	static func MultipleChoice(normal: Int = 0, _ items: Self..., attributes: RRAttributeDict = [:]) -> Self {
		Self.MultipleChoice(normal: normal, items: items, attributes: attributes);
	}

	/// An shorthand for ``Optional(item:attributes:)``
	static func Optional(_ item: Self, attributes: RRAttributeDict = [:]) -> Self {
		Self.Optional(item: item, attributes: attributes)
	}

	/// An shorthand for ``Loop(item:attributes:)``
	static func Loop(_ item: Self, separator: Self?, attributes: RRAttributeDict = [:]) -> Self {
		Self.Loop(item: item, separator: separator, max: "", attributes: attributes)
	}

	/// An shorthand for ``Group(item:attributes:)``
	static func Group(_ item: Self, label: String = "", attributes: RRAttributeDict = [:]) -> Self {
		Self.Group(item: item, label: label, attributes: attributes)
	}

	/// An shorthand for ``OneOrMore(item:separator:max:)``
	public static func OneOrMore(_ item: Self, separator: Self? = nil, max: String = "", attributes: RRAttributeDict = [:]) -> Self {
		Loop(item: item, separator: separator, max: max, attributes: attributes)
	}

	/// An shorthand for ``Start(label:attributes:)``
	public static func Start(_ label: String, attributes: RRAttributeDict = [:]) -> Self {
		Start(label: label, attributes: attributes)
	}

	/// An shorthand for ``End(label:attributes:)``
	public static func End(_ label: String, attributes: RRAttributeDict = [:]) -> Self {
		End(label: label, attributes: attributes)
	}

	/// An shorthand for ``Skip(text:attributes:)``
	public static func Terminal(_ text: String, attributes: RRAttributeDict = [:]) -> Self {
		Terminal(text: text, attributes: attributes)
	}

	/// An shorthand for ``NonTerminal(text:attributes:)``
	public static func NonTerminal(_ text: String, attributes: RRAttributeDict = [:]) -> Self {
		NonTerminal(text: text, attributes: attributes)
	}

	/// An shorthand for ``Skip(attributes:)``
	public static func Skip() -> Self {
		Skip(attributes: [:])
	}
}

public typealias RRAttributeDict = Dictionary<ObjectIdentifier, AnyHashable>;

//public func attribute<T: RailroadAttributeProtocol>(value: T) -> Self {
//	self
//}
//
//public subscript<T: RailroadAttributeProtocol>(_ key: T.Type) -> T {
//	get { attrs[ObjectIdentifier(key.self)] as! T }
//	set { attrs[ObjectIdentifier(key.self)] = newValue }
//}

public protocol RailroadAttributeProtocol {}

public indirect enum RailroadNode: RailroadDiagramProtocol, Hashable {
	case Diagram(start: RailroadNode, sequence: [RailroadNode], end: RailroadNode, attributes: RRAttributeDict)
	case Sequence(items: [RailroadNode], attributes: RRAttributeDict)
	case Stack(items: [RailroadNode], attributes: RRAttributeDict)
	case OptionalSequence(items: [RailroadNode], attributes: RRAttributeDict)
	case AlternatingSequence(items: [RailroadNode], attributes: RRAttributeDict)
	case Choice(items: [RailroadNode], attributes: RRAttributeDict)
	case HorizontalChoice(items: [RailroadNode], attributes: RRAttributeDict)
	case MultipleChoice(normal: Int, items: [RailroadNode], attributes: RRAttributeDict)
	case Group(item: RailroadNode, label: String, attributes: RRAttributeDict)
	case Optional(item: RailroadNode, attributes: RRAttributeDict)
	case ZeroOrMore(item: RailroadNode, separator: RailroadNode?, attributes: RRAttributeDict)
	case Loop(item: RailroadNode, separator: RailroadNode?, max: String, attributes: RRAttributeDict)
	case Start(label: String?, attributes: RRAttributeDict)
	case End(label: String?, attributes: RRAttributeDict)
	case Terminal(text: String, attributes: RRAttributeDict)
	case NonTerminal(text: String, attributes: RRAttributeDict)
	case Comment(text: String, attributes: RRAttributeDict)
	case Skip(attributes: RRAttributeDict)

	var attributes: RRAttributeDict {
		switch self {
			case
				.Diagram(_, _, _, let attribute),
				.Sequence(_, let attribute),
				.Stack(_, let attribute),
				.OptionalSequence(_, let attribute),
				.AlternatingSequence(_, let attribute),
				.Choice(_, let attribute),
				.HorizontalChoice(_, let attribute),
				.MultipleChoice(_, _, let attribute),
				.Group(_, _, let attribute),
				.Optional(_, let attribute),
				.ZeroOrMore(_, _, let attribute),
				.Loop(_, _, _, let attribute),
				.Start(_, let attribute),
				.End(_, let attribute),
				.Terminal(_, let attribute),
				.NonTerminal(_, let attribute),
				.Comment(_, let attribute),
				.Skip(let attribute):
				attribute;
		}
	}

	public subscript<T: RailroadAttributeProtocol>(_ key: T.Type) -> T {
		get { attributes[ObjectIdentifier(key.self)] as! T }
//		set { attributes[ObjectIdentifier(key.self)] = newValue }
	}
}
