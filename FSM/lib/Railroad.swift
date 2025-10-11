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
	///   ╭───╮
	///╮──│ 1 │──╭
	///│  ╰───╯  │
	///│         │
	///│  ╭───╮  │
	///╰──│ 2 │──╯
	///   ╰───╯

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
	static func OneOrMore(item: Self, separator: Self?, max: String) -> Self

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
		OneOrMore(item: item, separator: separator, max: max)
	}
}

/// Generate text-art railroad diagrams using box-drawing characters
/// Ported from <http://github.com/tabatkins/railroad-diagrams>
public struct RailroadTextNode: RailroadDiagramProtocol {
	public let entry: Int;
	public let exit: Int;
	public let height: Int;
	public let lines: Array<String>
	public let needsSpace: Bool
	public var width: Int { lines.first?.count ?? 0 }
	public var text: String { lines.joined(separator: "\n") }

	static let part_cross_diag = "\u{2573}";
	static let part_cross = "\u{253c}";
	static let part_line = "\u{2500}";
	static let part_line_vertical = "\u{2502}";
	static let part_multi_repeat = "\u{21ba}";
	static let part_separator = "\u{2500}";
	static let part_tee_left = "\u{2524}";
	static let part_tee_right = "\u{251c}";

	struct BoxChars {
		let top_left: String;
		let top_right: String;
		let bot_left: String;
		let bot_right: String;
		let top: String;
		let bot: String;
		let left: String;
		let right: String;
	}
	static let box_rect = BoxChars(top_left: "\u{250c}", top_right: "\u{2510}", bot_left: "\u{2514}", bot_right: "\u{2518}", top: "\u{2500}", bot: "\u{2500}", left: "\u{2502}", right: "\u{2502}")
	static let box_rect_dashed = BoxChars(top_left: "\u{250c}", top_right: "\u{2510}", bot_left: "\u{2514}", bot_right: "\u{2518}", top: "\u{2504}", bot: "\u{2504}", left: "\u{2506}", right: "\u{2506}")
	static let box_roundrect = BoxChars(top_left: "\u{256d}", top_right: "\u{256e}", bot_left: "\u{2570}", bot_right: "\u{256f}", top: "\u{2500}", bot: "\u{2500}", left: "\u{2502}", right: "\u{2502}")
	static let box_roundrect_dashed = BoxChars(top_left: "\u{256d}", top_right: "\u{256e}", bot_left: "\u{2570}", bot_right: "\u{256f}", top: "\u{2504}", bot: "\u{2504}", left: "\u{2506}", right: "\u{2506}")

	init(entry: Int, exit: Int, lines: Array<String>, needsSpace: Bool = false) {
		self.entry = entry
		self.exit = exit
		self.height = lines.count
		self.lines = lines
		self.needsSpace = needsSpace
		precondition(entry <= lines.count);
		precondition(exit <= lines.count);
		for line in lines {
			precondition(line.count >= 0);
			precondition(line.count == lines[0].count);
		}
	}

	func alter(entry: Int? = nil, exit: Int? = nil, lines: Array<String>? = nil) -> Self {
		let newEntry = entry ?? self.entry
		let newExit = exit ?? self.exit
		let newLines = lines ?? self.lines
		return Self(entry: newEntry, exit: newExit, lines: Array(newLines))
	}

	func appendBelow(_ item: Self, _ linesBetween: Array<String>, moveEntry: Bool = false, moveExit: Bool = false) -> Self {
		let newWidth = max(self.width, item.width)
		var newLines: Array<String> = []
		let centeredSelf = self.center(newWidth, " ")
		for line in centeredSelf.lines {
			newLines.append(line)
		}
		for line in linesBetween {
			newLines.append(Self._padR(line, newWidth, " "))
		}
		let centeredItem = item.center(newWidth, " ")
		for line in centeredItem.lines {
			newLines.append(line)
		}
		let newEntry = moveEntry ? self.height + linesBetween.count + item.entry : self.entry
		let newExit = moveExit ? self.height + linesBetween.count + item.exit : self.exit
		return Self(entry: newEntry, exit: newExit, lines: newLines)
	}

	func appendRight(_ item: Self, _ charsBetween: String) -> Self {
		let joinLine = max(self.exit, item.entry)
		let newHeight = max(self.height - self.exit, item.height - item.entry) + joinLine
		let leftTopAdd = joinLine - self.exit
		let leftBotAdd = newHeight - self.height - leftTopAdd
		let rightTopAdd = joinLine - item.entry
		let rightBotAdd = newHeight - item.height - rightTopAdd
		let left = self.expand(0, 0, leftTopAdd, leftBotAdd)
		let right = item.expand(0, 0, rightTopAdd, rightBotAdd)
		var newLines: Array<String> = []
		for i in 0..<newHeight {
			let sep = (i != joinLine) ? String(repeating: " ", count: charsBetween.count) : charsBetween
			newLines.append(left.lines[i] + sep + right.lines[i])
		}
		let newEntry = self.entry + leftTopAdd
		let newExit = item.exit + rightTopAdd
		return Self(entry: newEntry, exit: newExit, lines: newLines)
	}

	func center(_ width: Int, _ pad: String) -> Self {
		precondition(width >= self.width, "Cannot center into smaller width")
		if width == self.width {
			return self.copy()
		} else {
			let totalPadding = width - self.width
			let leftWidth = totalPadding / 2
			var left: Array<String> = []
			for _ in 0..<self.height {
				left.append(String(repeating: pad, count: leftWidth))
			}
			var right: Array<String> = []
			for _ in 0..<self.height {
				right.append(String(repeating: pad, count: totalPadding - leftWidth))
			}
			let newLines = Self._encloseLines(self.lines, left, right)
			return Self(entry: self.entry, exit: self.exit, lines: newLines)
		}
	}

	func copy() -> Self {
		return Self(entry: self.entry, exit: self.exit, lines: Array(self.lines))
	}

	func expand(_ left: Int, _ right: Int, _ top: Int, _ bottom: Int) -> Self {
		precondition(left >= 0 && right >= 0 && top >= 0 && bottom >= 0, "Expansion values cannot be negative")
		if left + right + top + bottom == 0 {
			return self.copy()
		} else {
			let line = Self.part_line
			var newLines: Array<String> = []
			for _ in 0..<top {
				newLines.append(String(repeating: " ", count: self.width + left + right))
			}
			for i in 0..<self.height {
				let leftExpansion = (i == self.entry) ? line : " "
				let rightExpansion = (i == self.exit) ? line : " "
				newLines.append(String(repeating: leftExpansion, count: left) + self.lines[i] + String(repeating: rightExpansion, count: right))
			}
			for _ in 0..<bottom {
				newLines.append(String(repeating: " ", count: self.width + left + right))
			}
			return Self(entry: self.entry + top, exit: self.exit + top, lines: newLines)
		}
	}

	static func _encloseLines(_ lines: Array<String>, _ lefts: Array<String>, _ rights: Array<String>) -> Array<String> {
		precondition(lines.count == lefts.count, "All arguments must be the same length")
		precondition(lines.count == rights.count, "All arguments must be the same length")
		var newLines: Array<String> = []
		for i in 0..<lines.count {
			newLines.append(lefts[i] + lines[i] + rights[i])
		}
		return newLines
	}

	static func _gaps(_ outerWidth: Int, _ innerWidth: Int) -> (Int, Int) {
		let diff = outerWidth - innerWidth
		// Assuming center alignment, as in JS default
		let left = diff / 2
		let right = diff - left
		return (left, right)
	}

	static func _maxWidth(_ args: Any...) -> Int {
		var maxWidth = 0
		for arg in args {
			var width = 0
			if let td = arg as? Self {
				width = td.width
			} else if let arr = arg as? Array<String> {
				width = arr.map { $0.count }.max() ?? 0
			} else if let num = arg as? Int {
				width = String(num).count
			} else if let str = arg as? String {
				width = str.count
			}
			maxWidth = max(maxWidth, width)
		}
		return maxWidth
	}

	static func _padL(_ string: String, _ width: Int, _ pad: String) -> String {
		let gap = width - string.count
		precondition(gap % pad.count == 0, "Gap \(gap) must be a multiple of pad string '\(pad)'")
		return String(repeating: pad, count: gap / pad.count) + string
	}

	static func _padR(_ string: String, _ width: Int, _ pad: String) -> String {
		let gap = width - string.count
		precondition(gap % pad.count == 0, "Gap \(gap) must be a multiple of pad string '\(pad)'")
		return string + String(repeating: pad, count: gap / pad.count)
	}

	static func rect(_ rectType: BoxChars, _ data: Any, inlet: Bool = false, outlet: Bool = false) -> Self {
		let topLeft = rectType.top_left;
		let ctrLeft = rectType.left;
		let botLeft = rectType.bot_left;
		let topRight = rectType.top_right;
		let ctrRight = rectType.right;
		let botRight = rectType.bot_right;
		let topHoriz = rectType.top;
		let botHoriz = rectType.bot;
		let line = Self.part_line;
		let cross = Self.part_cross;

		let itemWasFormatted = data is Self
		let itemTD: Self
		if itemWasFormatted {
			itemTD = data as! Self
		} else {
			itemTD = Self(entry: 0, exit: 0, lines: [data as! String])
		}

		var lines: Array<String> = []
		lines.append(String(repeating: topHoriz, count: itemTD.width + 2))
		if itemWasFormatted {
			lines += itemTD.expand(1, 1, 0, 0).lines
		} else {
			for line in itemTD.lines {
				lines.append(" " + line + " ")
			}
		}
		lines.append(String(repeating: botHoriz, count: itemTD.width + 2))

		let entry = itemTD.entry + 1
		let exit = itemTD.exit + 1

		let leftMaxWidth = _maxWidth(topLeft, ctrLeft, botLeft)
		var lefts: Array<String> = []
		lefts.append(_padR(topLeft, leftMaxWidth, topHoriz))
		for _ in 1..<(lines.count - 1) {
			lefts.append(_padR(ctrLeft, leftMaxWidth, " "))
		}
		lefts.append(_padR(botLeft, leftMaxWidth, botHoriz))
		if itemWasFormatted {
			lefts[entry] = cross
		}

		let rightMaxWidth = _maxWidth(topRight, ctrRight, botRight)
		var rights: Array<String> = []
		rights.append(_padL(topRight, rightMaxWidth, topHoriz))
		for _ in 1..<(lines.count - 1) {
			rights.append(_padL(ctrRight, rightMaxWidth, " "))
		}
		rights.append(_padL(botRight, rightMaxWidth, botHoriz))
		if itemWasFormatted {
			rights[exit] = cross
		}

		lines = _encloseLines(lines, lefts, rights)

		lefts = []
		for _ in 0..<lines.count {
			lefts.append(" ")
		}
		lefts[entry] = line
		rights = []
		for _ in 0..<lines.count {
			rights.append(" ")
		}
		rights[exit] = line
		lines = _encloseLines(lines, lefts, rights)

		return Self(entry: entry, exit: exit, lines: lines)
	}

	// Protocol conformance
	public static func Diagram(start: Self, sequence: [Self], end: Self) -> Self {
		let items = [start] + sequence + [end]
		return Diagram(sequence: items)
	}
	public static func Diagram(sequence: [Self]) -> Self {
		precondition(sequence.count > 0)
		let separator = Self.part_separator
		var diagramTD = sequence[0]
		for item in sequence[1...] {
			var itemTD = item
			if item.needsSpace {
				itemTD = itemTD.expand(1, 1, 0, 0)
			}
			diagramTD = diagramTD.appendRight(itemTD, separator)
		}
		return diagramTD
	}

	public static func Sequence(items: [Self]) -> Self {
		let separator = Self.part_separator
		var diagramTD = Self(entry: 0, exit: 0, lines: [""])
		for item in items {
			var itemTD = item
			if item.needsSpace {
				itemTD = itemTD.expand(1, 1, 0, 0)
			}
			diagramTD = diagramTD.appendRight(itemTD, separator)
		}
		return diagramTD
	}

	public static func Stack(items: [Self]) -> Self {
		let corner_bot_left = Self.box_rect.bot_left
		let corner_bot_right = Self.box_rect.bot_right
		let corner_top_left = Self.box_rect.top_left
		let corner_top_right = Self.box_rect.top_right
		let line = Self.part_line
		let line_vertical = Self.part_line_vertical
		let itemTDs = items
		let maxWidth = itemTDs.map { $0.width }.max() ?? 0
		let separatorTD = Self(entry: 0, exit: 0, lines: [String(repeating: line, count: maxWidth)])
		var leftLines: [String] = []
		var rightLines: [String] = []
		var diagramTD: Self = .init(entry: 0, exit: 0, lines: [])
		for (itemNum, itemTD) in itemTDs.enumerated() {
			if itemNum == 0 {
				leftLines.append(line + line)
				for _ in 0..<(itemTD.height - itemTD.entry - 1) {
					leftLines.append("  ")
				}
			} else {
				diagramTD = diagramTD.appendBelow(separatorTD, [])
				leftLines.append(corner_top_left + line)
				for _ in 0..<itemTD.entry {
					leftLines.append(line_vertical + " ")
				}
				leftLines.append(corner_bot_left + line)
				for _ in 0..<(itemTD.height - itemTD.entry - 1) {
					leftLines.append("  ")
				}
				for _ in 0..<itemTD.exit {
					rightLines.append("  ")
				}
			}
			if itemNum < itemTDs.count - 1 {
				rightLines.append(line + corner_top_right)
				for _ in 0..<(itemTD.height - itemTD.exit - 1) {
					rightLines.append(" " + line_vertical)
				}
				rightLines.append(line + corner_bot_right)
			} else {
				rightLines.append(line + line)
			}
			let (leftPad, rightPad) = Self._gaps(maxWidth, itemTD.width)
			let expandedItemTD = itemTD.expand(leftPad, rightPad, 0, 0)
			if itemNum == 0 {
				diagramTD = expandedItemTD
			} else {
				diagramTD = diagramTD.appendBelow(expandedItemTD, [])
			}
		}
		let leftTD = Self(entry: 0, exit: 0, lines: leftLines)
		var resultTD = leftTD.appendRight(diagramTD, "")
		let rightTD = Self(entry: 0, exit: rightLines.count - 1, lines: rightLines)
		resultTD = resultTD.appendRight(rightTD, "")
		return resultTD
	}

	public static func OptionalSequence(items: [Self]) -> Self {
		let line = Self.part_line
		let line_vertical = Self.part_line_vertical
		let roundcorner_bot_left = Self.box_roundrect.bot_left
		let roundcorner_bot_right = Self.box_roundrect.bot_right
		let roundcorner_top_left = Self.box_roundrect.top_left
		let roundcorner_top_right = Self.box_roundrect.top_right
		let itemTDs = items
		let diagramEntry = itemTDs.map { $0.entry }.max() ?? 0
		let SOILHeight = itemTDs.dropLast().map { $0.entry }.max() ?? 0
		let topToSOIL = diagramEntry - SOILHeight
		var lines: [String] = []
		for _ in 0..<topToSOIL {
			lines.append("  ")
		}
		lines.append(roundcorner_top_left + line)
		for _ in 0..<SOILHeight {
			lines.append(line_vertical + " ")
		}
		lines.append(roundcorner_bot_right + line)
		var diagramTD = Self(entry: lines.count - 1, exit: lines.count - 1, lines: lines)
		for (itemNum, itemTD) in itemTDs.enumerated() {
			if itemNum > 0 {
				lines = []
				for _ in 0..<topToSOIL {
					lines.append("  ")
				}
				lines.append(line + line)
				for _ in 0..<(diagramTD.exit - topToSOIL - 1) {
					lines.append("  ")
				}
				lines.append(line + roundcorner_top_right)
				for _ in 0..<(itemTD.height - itemTD.entry - 1) {
					lines.append(" " + line_vertical)
				}
				lines.append(" " + roundcorner_bot_left)
				let skipDownTD = Self(entry: diagramTD.exit, exit: diagramTD.exit, lines: lines)
				diagramTD = diagramTD.appendRight(skipDownTD, "")
				lines = []
				for _ in 0..<topToSOIL {
					lines.append("  ")
				}
				let lineToNextItem = itemNum < itemTDs.count - 1 ? line : " "
				lines.append(line + roundcorner_top_right + lineToNextItem)
				for _ in 0..<(diagramTD.exit - topToSOIL - 1) {
					lines.append(" " + line_vertical + " ")
				}
				lines.append(line + roundcorner_bot_left + line)
				for _ in 0..<(itemTD.height - itemTD.entry - 1) {
					lines.append("   ")
				}
				lines.append(line + line + line)
				let entryTD = Self(entry: diagramTD.exit, exit: diagramTD.exit, lines: lines)
				diagramTD = diagramTD.appendRight(entryTD, "")
			}
			var partTD = Self(entry: 0, exit: 0, lines: [])
			if itemNum < itemTDs.count - 1 {
				lines = []
				lines.append(String(repeating: line, count: itemTD.width))
				for _ in 0..<(SOILHeight - itemTD.entry) {
					lines.append(String(repeating: " ", count: itemTD.width))
				}
				let SOILSegment = Self(entry: 0, exit: 0, lines: lines)
				partTD = partTD.appendBelow(SOILSegment, [])
			}
			partTD = partTD.appendBelow(itemTD, [], moveEntry: true, moveExit: true)
			if itemNum > 0 {
				let SUILSegment = Self(entry: 0, exit: 0, lines: [String(repeating: line, count: itemTD.width)])
				partTD = partTD.appendBelow(SUILSegment, [])
			}
			diagramTD = diagramTD.appendRight(partTD, "")
			if itemNum > 0 {
				lines = []
				for _ in 0..<topToSOIL {
					lines.append("  ")
				}
				let skipOverChar = itemNum < itemTDs.count - 1 ? line : " "
				lines.append(String(repeating: skipOverChar, count: 2))
				for _ in 0..<(diagramTD.exit - topToSOIL - 1) {
					lines.append("  ")
				}
				lines.append(line + roundcorner_top_left)
				for _ in 0..<(partTD.height - partTD.exit - 2) {
					lines.append(" " + line_vertical)
				}
				lines.append(line + roundcorner_bot_right)
				let skipUpTD = Self(entry: diagramTD.exit, exit: diagramTD.exit, lines: lines)
				diagramTD = diagramTD.appendRight(skipUpTD, "")
			}
		}
		return diagramTD
	}

	public static func AlternatingSequence(items: [Self]) -> Self {
		precondition(!items.isEmpty)
		precondition(items.count < 2, "AlternatingSequence must have 1-2 elements")
		if items.count == 1 { return items[0] }
		let cross_diag = Self.part_cross_diag
		let corner_bot_left = Self.box_rect.bot_left
		let corner_bot_right = Self.box_rect.bot_right
		let corner_top_left = Self.box_rect.top_left
		let corner_top_right = Self.box_rect.top_right
		let line = Self.part_line
		let line_vertical = Self.part_line_vertical
		let tee_left = Self.part_tee_left
		let tee_right = Self.part_tee_right

		let firstTD = items[0]
		let secondTD = items[1]
		let maxWidth = Self._maxWidth(firstTD, secondTD)
		let (leftWidth, rightWidth) = Self._gaps(maxWidth, 0)
		var leftLines: [String] = []
		var rightLines: [String] = []
		var separator: [String] = []
		let (leftSize, rightSize) = Self._gaps(firstTD.width, 0)
		var diagramTD = firstTD.expand(leftWidth - leftSize, rightWidth - rightSize, 0, 0)
		for _ in 0..<diagramTD.entry {
			leftLines.append("  ")
		}
		leftLines.append(corner_top_left + line)
		for _ in 0..<(diagramTD.height - diagramTD.entry - 1) {
			leftLines.append(line_vertical + " ")
		}
		leftLines.append(corner_bot_left + line)
		for _ in 0..<diagramTD.exit {
			rightLines.append("  ")
		}
		rightLines.append(line + corner_top_right)
		for _ in 0..<(diagramTD.height - diagramTD.exit - 1) {
			rightLines.append(" " + line_vertical)
		}
		rightLines.append(line + corner_bot_right)
		separator.append(String(repeating: line, count: leftWidth - 1) + corner_top_right + " " + corner_top_left + String(repeating: line, count: rightWidth - 2))
		separator.append(String(repeating: " ", count: leftWidth - 1) + " " + cross_diag + " " + String(repeating: " ", count: rightWidth - 2))
		separator.append(String(repeating: line, count: leftWidth - 1) + corner_bot_right + " " + corner_bot_left + String(repeating: line, count: rightWidth - 2))
		leftLines.append("  ")
		rightLines.append("  ")
		let (leftSize2, rightSize2) = Self._gaps(secondTD.width, 0)
		let secondTDExpanded = secondTD.expand(leftWidth - leftSize2, rightWidth - rightSize2, 0, 0)
		diagramTD = diagramTD.appendBelow(secondTDExpanded, separator, moveEntry: true, moveExit: true)
		leftLines.append(corner_top_left + line)
		for _ in 0..<secondTD.entry {
			leftLines.append(line_vertical + " ")
		}
		leftLines.append(corner_bot_left + line)
		rightLines.append(line + corner_top_right)
		for _ in 0..<secondTD.exit {
			rightLines.append(" " + line_vertical)
		}
		rightLines.append(line + corner_bot_right)
		diagramTD = diagramTD.alter(entry: firstTD.height + separator.count / 2, exit: firstTD.height + separator.count / 2)
		let leftTD = Self(entry: firstTD.height + separator.count / 2, exit: firstTD.height + separator.count / 2, lines: leftLines)
		let rightTD = Self(entry: firstTD.height + separator.count / 2, exit: firstTD.height + separator.count / 2, lines: rightLines)
		diagramTD = leftTD.appendRight(diagramTD, "").appendRight(rightTD, "")
		diagramTD = Self(entry: 1, exit: 1, lines: [corner_top_left, tee_left, corner_bot_left]).appendRight(diagramTD, "").appendRight(Self(entry: 1, exit: 1, lines: [corner_top_right, tee_right, corner_bot_right]), "")
		return diagramTD
	}

	public static func Choice(items: [Self]) -> Self {
		let cross = Self.part_cross
		let line = Self.part_line
		let line_vertical = Self.part_line_vertical
		let roundcorner_bot_left = Self.box_roundrect.bot_left
		let roundcorner_bot_right = Self.box_roundrect.bot_right
		let roundcorner_top_left = Self.box_roundrect.top_left
		let roundcorner_top_right = Self.box_roundrect.top_right
		let itemTDs = items.map { $0.expand(1, 1, 0, 0) }
		let max_item_width = itemTDs.map { $0.width }.max() ?? 0
		var diagramTD = Self(entry: 0, exit: 0, lines: [])
		let normal = 0 // assume first is normal
		for (itemNum, itemTD) in itemTDs.enumerated() {
			let (leftPad, rightPad) = Self._gaps(max_item_width, itemTD.width)
			let itemTDExpanded = itemTD.expand(leftPad, rightPad, 0, 0)
			var hasSeparator = true
			var leftLines = Array(repeating: line_vertical, count: itemTDExpanded.height)
			var rightLines = Array(repeating: line_vertical, count: itemTDExpanded.height)
			var moveEntry = false
			var moveExit = false
			if itemNum <= normal {
				leftLines[itemTDExpanded.entry] = roundcorner_top_left
				rightLines[itemTDExpanded.exit] = roundcorner_top_right
				if itemNum == 0 {
					hasSeparator = false
					for i in 0..<itemTDExpanded.entry {
						leftLines[i] = " "
					}
					for i in 0..<itemTDExpanded.exit {
						rightLines[i] = " "
					}
				}
			}
			if itemNum >= normal {
				leftLines[itemTDExpanded.entry] = roundcorner_bot_left
				rightLines[itemTDExpanded.exit] = roundcorner_bot_right
				if itemNum == 0 {
					hasSeparator = false
				}
				if itemNum == items.count - 1 {
					for i in (itemTDExpanded.entry + 1)..<itemTDExpanded.height {
						leftLines[i] = " "
					}
					for i in (itemTDExpanded.exit + 1)..<itemTDExpanded.height {
						rightLines[i] = " "
					}
				}
			}
			if itemNum == normal {
				leftLines[itemTDExpanded.entry] = cross
				rightLines[itemTDExpanded.exit] = cross
				moveEntry = true
				moveExit = true
				if itemNum == 0 && itemNum == items.count - 1 {
					leftLines[itemTDExpanded.entry] = line
					rightLines[itemTDExpanded.exit] = line
				} else if itemNum == 0 {
					leftLines[itemTDExpanded.entry] = roundcorner_top_right
					rightLines[itemTDExpanded.exit] = roundcorner_top_left
				} else if itemNum == items.count - 1 {
					leftLines[itemTDExpanded.entry] = roundcorner_bot_right
					rightLines[itemTDExpanded.exit] = roundcorner_bot_left
				}
			}
			let leftJointTD = Self(entry: itemTDExpanded.entry, exit: itemTDExpanded.entry, lines: leftLines)
			let rightJointTD = Self(entry: itemTDExpanded.exit, exit: itemTDExpanded.exit, lines: rightLines)
			let itemTDJoined = leftJointTD.appendRight(itemTDExpanded, "").appendRight(rightJointTD, "")
			let separator = hasSeparator ? [line_vertical + String(repeating: " ", count: Self._maxWidth(diagramTD, itemTDJoined) - 2) + line_vertical] : []
			diagramTD = diagramTD.appendBelow(itemTDJoined, separator, moveEntry: moveEntry, moveExit: moveExit)
		}
		return diagramTD
	}

	public static func HorizontalChoice(items: [Self]) -> Self {
		precondition(items.count > 0);
		if items.count == 1 { return items[0] }
		let line = Self.part_line;
		let line_vertical = Self.part_line_vertical;
		let box = Self.box_roundrect;
		// Format all the child items, so we can know the maximum entry, exit, and height.
		let itemTDs = items
		// diagramEntry: distance from top to lowest entry, aka distance from top to diagram entry, aka final diagram entry and exit.
		let diagramEntry = itemTDs.map { $0.entry }.max() ?? 0
		// SOILToBaseline: distance from top to lowest entry before rightmost item, aka distance from skip-over-items line to rightmost entry, aka SOIL height.
		let SOILToBaseline = itemTDs.dropLast().map { $0.entry }.max() ?? 0
		// topToSOIL: distance from top to skip-over-items line.
		let topToSOIL = diagramEntry - SOILToBaseline
		// baselineToSUIL: distance from lowest entry or exit after leftmost item to bottom, aka distance from entry to skip-under-items line, aka SUIL height.
		let baselineToSUIL = itemTDs.dropFirst().map { $0.height - min($0.entry, $0.exit) - 1 }.max() ?? 0
		// The diagram starts with a line from its entry up to skip-over-items line
		var lines: [String] = []
		for _ in 0..<topToSOIL {
			lines.append("  ")
		}
		lines.append(box.top_left + line)
		for _ in 0..<SOILToBaseline {
			lines.append(line_vertical + " ")
		}
		lines.append(box.bot_right + line)
		var diagramTD = Self(entry: lines.count - 1, exit: lines.count - 1, lines: lines)
		for (itemNum, itemTD) in itemTDs.enumerated() {
			if itemNum > 0 {
				// All items except the leftmost start with a line from the skip-over-items line down to their entry,
				// with a joining-line across at the skip-under-items line
				lines = []
				for _ in 0..<topToSOIL {
					lines.append("  ")
				}
				// All such items except the rightmost also have a continuation of the skip-over-items line {
				let lineToNextItem = itemNum == itemTDs.count - 1 ? " " : line
				lines.append(box.top_right + lineToNextItem)
				for _ in 0..<SOILToBaseline {
					lines.append(line_vertical + " ")
				}
				lines.append(box.bot_left + line)
				for _ in 0..<baselineToSUIL {
					lines.append(line_vertical + " ")
				}
				lines.append(line + line)
				let entryTD = Self(entry: diagramTD.exit, exit: diagramTD.exit, lines: lines)
				diagramTD = diagramTD.appendRight(entryTD, "")
			}
			var partTD = Self(entry: 0, exit: 0, lines: [])
			if itemNum < itemTDs.count - 1 {
				// All items except the rightmost start with a segment of the skip-over-items line at the top.
				// followed by enough blank lines to push their entry down to the previous item's exit {
				lines = []
				lines.append(String(repeating: line, count: itemTD.width))
				for _ in 0..<(SOILToBaseline - itemTD.entry) {
					lines.append(String(repeating: " ", count: itemTD.width))
				}
				let SOILSegment = Self(entry: 0, exit: 0, lines: lines)
				partTD = partTD.appendBelow(SOILSegment, [])
			}
			partTD = partTD.appendBelow(itemTD, [], moveEntry: true, moveExit: true)
			if itemNum > 0 {
				// All items except the leftmost end with enough blank lines to pad down to the skip-under-items
				// line, followed by a segment of the skip-under-items line {
				lines = []
				for _ in 0..<(baselineToSUIL - (itemTD.height - itemTD.entry) + 1) {
					lines.append(String(repeating: " ", count: itemTD.width))
				}
				lines.append(String(repeating: line, count: itemTD.width))
				let SUILSegment = Self(entry: 0, exit: 0, lines: lines)
				partTD = partTD.appendBelow(SUILSegment, [])
			}
			diagramTD = diagramTD.appendRight(partTD, "")
			if itemNum < itemTDs.count - 1 {
				// All items except the rightmost have a line from their exit down to the skip-under-items line,
				// with a joining-line across at the skip-over-items line {
				lines = []
				for _ in 0..<topToSOIL {
					lines.append("  ")
				}
				lines.append(line + line)
				for _ in 0..<(diagramTD.exit - topToSOIL - 1) {
					lines.append("  ")
				}
				lines.append(line + box.top_right)
				for _ in 0..<(baselineToSUIL - (diagramTD.exit - diagramTD.entry)) {
					lines.append(" " + line_vertical)
				}
				// All such items except the leftmost also have are continuing of the skip-under-items line from the previous item {
				let lineFromPrevItem = itemNum > 0 ? line : " "
				lines.append(lineFromPrevItem + box.bot_left)
				let entry = diagramEntry + 1 + (diagramTD.exit - diagramTD.entry)
				let exitTD = Self(entry: entry, exit: diagramEntry + 1, lines: lines)
				diagramTD = diagramTD.appendRight(exitTD, "")
			} else {
				// The rightmost item has a line from the skip-under-items line and from its exit up to the diagram exit {
				lines = []
				let lineFromExit = diagramTD.exit != diagramTD.entry ? " " : line
				lines.append(lineFromExit + box.top_left)
				for _ in 0..<max(diagramTD.exit - diagramTD.entry - 1, 0) {
					lines.append(" " + line_vertical)
				}
				if diagramTD.exit != diagramTD.entry {
					lines.append(line + box.bot_right)
				}
				for _ in 0..<(baselineToSUIL - (diagramTD.exit - diagramTD.entry)) {
					lines.append(" " + line_vertical)
				}
				lines.append(line + box.bot_right)
				let exitTD = Self(entry: diagramTD.exit - diagramTD.entry, exit: 0, lines: lines)
				diagramTD = diagramTD.appendRight(exitTD, "")
			}
		}
		return diagramTD
	}

	public static func MultipleChoice(normal: Int, items: [Self]) -> Self {
		let multi_repeat = Self.part_multi_repeat
		let anyAll = Self.rect(Self.box_rect, "1+") // assume any
		var diagramTD = Choice(items: items)
		diagramTD = anyAll.appendRight(diagramTD, "")
		let repeatTD = Self.rect(Self.box_rect, multi_repeat)
		diagramTD = diagramTD.appendRight(repeatTD, "")
		return diagramTD
	}

	public static func Optional(item: Self) -> Self {
		return Choice(items: [Skip(), item])
	}

	public static func OneOrMore(item: Self, separator: Self?, max: String = "") -> Self {
		let line = Self.part_line
		let repeat_top_left = Self.box_roundrect.top_left
		let repeat_left = Self.box_roundrect.left
		let repeat_bot_left = Self.box_roundrect.bot_left
		let repeat_top_right = Self.box_roundrect.top_right
		let repeat_right = Self.box_roundrect.right
		let repeat_bot_right = Self.box_roundrect.bot_right
		let itemTD = item
		let repeatTD = Skip()
		let fIRWidth = Self._maxWidth(itemTD, repeatTD)
		let repeatTDExpanded = repeatTD.expand(0, fIRWidth - repeatTD.width, 0, 0)
		let itemTDExpanded = itemTD.expand(0, fIRWidth - itemTD.width, 0, 0)
		let itemAndRepeatTD = itemTDExpanded.appendBelow(repeatTDExpanded, [])
		var leftLines: [String] = []
		leftLines.append(repeat_top_left + line)
		for _ in 0..<((itemTDExpanded.height - itemTDExpanded.entry) + repeatTDExpanded.entry - 1) {
			leftLines.append(repeat_left + " ")
		}
		leftLines.append(repeat_bot_left + line)
		var leftTD = Self(entry: 0, exit: 0, lines: leftLines)
		leftTD = leftTD.appendRight(itemAndRepeatTD, "")
		var rightLines: [String] = []
		rightLines.append(line + repeat_top_right)
		for _ in 0..<((itemTDExpanded.height - itemTDExpanded.exit) + repeatTDExpanded.exit - 1) {
			rightLines.append(" " + repeat_right)
		}
		rightLines.append(line + repeat_bot_right)
		let rightTD = Self(entry: 0, exit: 0, lines: rightLines)
		let diagramTD = leftTD.appendRight(rightTD, "")
		return diagramTD
	}

	public static func ZeroOrMore(item: Self, separator: Self?) -> Self {
		return Optional(item: OneOrMore(item, separator: separator))
	}

	public static func Group(item: Self, label: String) -> Self {
		var diagramTD = Self.rect(Self.box_roundrect_dashed, item)
		if !label.isEmpty {
			let labelTD = Comment(text: label)
			diagramTD = labelTD.appendBelow(diagramTD, [], moveEntry: true, moveExit: true).expand(0, 0, 1, 0)
		}
		return diagramTD
	}

	public static func Start(label: String?) -> Self {
		let cross = Self.part_cross
		let line = Self.part_line
		let tee_right = Self.part_tee_right
		let start = tee_right + cross + line;
		var labelTD = Self(entry: 0, exit: 0, lines: [])
		if let label = label {
			labelTD = Self(entry: 0, exit: 0, lines: [label])
			let startPadded = Self._padR(start, labelTD.width, line)
			let startTD = Self(entry: 0, exit: 0, lines: [startPadded])
			return labelTD.appendBelow(startTD, [], moveEntry: true, moveExit: true)
		} else {
			let startTD = Self(entry: 0, exit: 0, lines: [start])
			return labelTD.appendBelow(startTD, [], moveEntry: true, moveExit: true)
		}
	}

	public static func End(label: String?) -> Self {
		let end = self.part_line + self.part_cross + self.part_tee_left
		return Self(entry: 0, exit: 0, lines: [end])
	}

	public static func Terminal(text: String) -> Self {
		return Self.rect(Self.box_roundrect, text)
	}

	public static func NonTerminal(text: String) -> Self {
		return Self.rect(Self.box_rect, text)
	}

	public static func Comment(text: String) -> Self {
		return Self(entry: 0, exit: 0, lines: [text])
	}

	public static func Skip() -> Self {
		return Self(entry: 0, exit: 0, lines: [Self.part_line])
	}
}
