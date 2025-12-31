import FSM;
import Foundation;
private typealias Symbol = UInt32;

func abnf_to_railroad_svg_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-railroad-svg")) <filepath> <expression>");
	print("\tReads <filepath> and converts <rulename> to a railroad script for railroad.js");
}

/// Convert an ABNF file to a railroad diagram.
///
/// Command line arguments:
/// - `filepath`: Filename to read from
/// - `expression`: Rule name to render
func abnf_to_railroad_svg_args(arguments: Array<String>) -> Int32 {
	// TODO: Command line arguments:
	// - Expand rule names with definitions
	// - Expand core names with definitions
	// - Place subexpressions in an outlined Group
	// - Highlight paths for a certain input
	guard arguments.count == 4 else {
		print(arguments.count);
		abnf_to_railroad_svg_help(arguments: arguments);
		return 1;
	}
	let imported: Data? = getInput(filename: arguments[2]);
	guard let imported else { return 1 }
	// builtins will be copied to the output
	let dereferencedRulelist: ABNFRulelist<Symbol>
	do {
		let importedRulelist = try ABNFRulelist<Symbol>.parse(imported);
		func dereference(filename: String) throws -> ABNFRulelist<Symbol> {
			let filePath = FileManager.default.currentDirectoryPath + "/catalog/" + filename
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
			return try ABNFRulelist<Symbol>.parse(content.utf8)
		}
		dereferencedRulelist = try dereferenceABNFRulelist(importedRulelist, dereference: dereference).rules;
	} catch {
		print("Could not parse input")
		print(error)
		return 2;
	}
	let rule = dereferencedRulelist.dictionary[arguments[3].lowercased()];
	guard let rule else {
		print(stderr, "Error: No such rule: \(arguments[3])");
		exit(1);
	}
	let rr: RailroadNode = rule.toRailroad()
	print(toContainerNode(rr).toSVGNode(offset: .init(x: 0, y: 0)).toSVG())
	return 0;
}

func toContainerNode(_ node: RailroadNode) -> RRContainerProtocol {
	return switch node {
		case .Diagram(start: let start, sequence: let sequence, end: let end, attributes: _):
			RRContainerDiagram(sequence: ([start] + sequence + [end]).map(toContainerNode));
		case .Sequence(items: let items, attributes: _):
			RRContainerSequence(sequence: items.map(toContainerNode))
		case .Stack(items: let items, attributes: _):
			fatalError(); //RRContainerSequence(sequence: items.map(toContainerNode))
		case .OptionalSequence(items: let items, attributes: _):
			fatalError(); //RRContainerSequence(sequence: items.map(toContainerNode))
		case .AlternatingSequence(items: let items, attributes: _):
			fatalError(); //RRContainerSequence(sequence: items.map(toContainerNode))
		case .Choice(items: let items, attributes: _):
			RRContainerChoice(items: items.map(toContainerNode))
		case .HorizontalChoice(items: let items, attributes: _):
			fatalError(); //RRContainerChoice(sequence: items.map(toContainerNode))
		case .MultipleChoice(normal: _, items: let items, attributes: _):
			fatalError(); //RRContainerChoice(sequence: items.map(toContainerNode))
		case .Group(item: let item, label: _, attributes: _):
			RRContainerGroup(item: toContainerNode(item))
		case .Optional(item: let item, attributes: _):
			RRContainerChoice(items: [
				RRContainerSkip(),
				toContainerNode(item)
			]);
		case .ZeroOrMore(item: let item, separator: _, attributes: _):
			RRContainerChoice(items: [
				RRContainerSkip(),
				RRContainerLoop(item: toContainerNode(item)),
			]);
		case .Loop(item: let item, separator: let separator, max: _, attributes: _):
			RRContainerLoop(item: toContainerNode(item))
		case .Start(label: let l, attributes: _):
			RRContainerStart(text: l ?? "")
		case .End(label: let l, attributes: _):
			RRContainerEnd(text: l ?? "")
		case .Terminal(text: let s, attributes: _):
			RRContainerTerminal(text: s)
		case .NonTerminal(text: let s, attributes: _):
			RRContainerNonTerminal(text: s)
		case .Comment(text: let s, attributes: _):
			RRContainerComment(text: s)
		case .Skip(attributes: _):
			RRContainerComment(text: "")
		default:
			fatalError()
	}
}

public protocol RRContainerProtocol {
	// The bounding box (that other items must not impede) is from (0, 0) to (width, height).
	var size: CGSize { get };
	// The in and out points should be on the border of the bounding box.
	var inPoint: CGPoint { get }
	var outPoint: CGPoint { get }
	func toSVGNode(offset: CGPoint) -> RailroadSVGNode
}

public struct RRContainerDiagram: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let sequence: RRContainerSequence;
	init(sequence: [RRContainerProtocol]) {
		self.sequence = RRContainerSequence(sequence: sequence);
		self.size = CGSize(
			// Sum the widths of sequence together
			width: 40 + self.sequence.size.width,
			// Find the maximum height in sequence
			height: 40 + self.sequence.size.height,
		);
		self.inPoint = .init(x: 0, y: self.size.height/2);
		self.outPoint = .init(x: self.size.width, y: self.size.height/2);
	}
	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		.init(
			elementName: "svg",
			className: ["railroad-diagram"],
			attributes: [
				"xmlns": "http://www.w3.org/2000/svg",
				"xmlns:xlink": "http://www.w3.org/1999/xlink",
				"width": String(Float(size.width)),
				"height": String(Float(size.height)),
				"viewBox": "0 0 \(size.width) \(size.height)"
			],
			children: [
				RailroadSVGNode(
					elementName: "g",
					attributes: ["transform": "translate(.5 .5)"],
					children: [
						sequence.toSVGNode(offset: CGPoint(x: 20, y: 20)),
					]
				),
				RailroadSVGNode(elementName: "style", cdata: RRContainerDiagram.css)
			],
		);
	}

	// This comes from <https://github.com/tabatkins/railroad-diagrams>
	static var css: String = """

		svg {
			background-color: hsl(30,20%,95%);
		}
		path {
			stroke-width: 3;
			stroke: black;
			fill: rgba(0,0,0,0);
		}
		text {
			font: bold 14px monospace;
			text-anchor: middle;
			white-space: pre;
		}
		text.diagram-text {
			font-size: 12px;
		}
		text.diagram-arrow {
			font-size: 16px;
		}
		text.label {
			text-anchor: start;
		}
		text.comment {
			font: italic 12px monospace;
		}
		g.non-terminal text {
			font-style: italic;
		}
		rect {
			stroke-width: 3;
			stroke: black;
			fill: hsl(120,100%,90%);
		}
		rect.group-box {
			stroke: gray;
			stroke-dasharray: 10 5;
			fill: none;
		}
		path.diagram-text {
			stroke-width: 3;
			stroke: black;
			fill: white;
			cursor: help;
		}
		g.diagram-text:hover path.diagram-text {
			fill: #eee;
		}
	""";

}

public struct RRContainerSequence: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let sequence: Array<RRContainerProtocol>;
	static let padding: CGFloat = 10;
	init(sequence: Array<RRContainerProtocol>) {
		self.size = .init(
			// Sum the widths of sequence together
//			width: (sequence.reduce(0) { $0 + $1.size.width }) + 20,
			width: (sequence.reduce(0) { $0 + $1.outPoint.x - $1.inPoint.x + Self.padding }) - Self.padding,
			// Find the maximum height in sequence
			height: (sequence.map(\.size.height).max() ?? 0),
		);
		self.inPoint = .init(x: 0, y: sequence.first!.inPoint.y);
		self.outPoint = .init(x: self.size.width, y: sequence.last!.outPoint.y);
		self.sequence = sequence
	}
	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		var children: Array<RailroadSVGNode> = [];
		// Set the initial out-point so that all of the items in the sequence fit inside the geometry
		var previousOut = CGPoint(x: offset.x, y: offset.y + (sequence.map(\.inPoint.y).max() ?? 0));
		for item in sequence {
			// Align the item so that its in point is 10px to the right of the previous out point
			// TODO: Or align the item so the bounding box is at least 10px away from the previous bounding box, whichever is greater.
			let position = previousOut - item.inPoint
			if !children.isEmpty {
				// This is .left() because the "previous outPoint" actually includes the padding
				children.append(SVGPath(previousOut).left(Self.padding).node);
			}
			// Align the next in point to be 10px to the right of this out point
			children.append(item.toSVGNode(offset: CGPoint(x: position.x, y: position.y)))

			previousOut = .init(x: position.x + item.outPoint.x +  Self.padding, y: position.y + item.outPoint.y);
		}

		// TODO: When figuring out how to lay out the y-position,
		// first, the tallest item gets laid out first.
		// Then, the items before it and after it get laid out separately.
		// The items before it get justified at the top.
		// The items after it get justified at the bottom.
		// Left to right, it flows top down whenever possible.

		return .init(
			elementName: "g",
			attributes: [
				"data-updown": "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)",
				"data-type": "sequence",
			],
			children: children,
		);
	}
}

public struct RRContainerChoice: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let items: Array<RRContainerProtocol>;
	static let separation: CGFloat = 8;
	static let padding: CGFloat = 16;
	init(items: Array<RRContainerProtocol>) {
		self.size = .init(
			// Find the maximum height in sequence
			// Add 10 on each side for railroads
			width: (items.map(\.size.width).max() ?? 0) + Self.padding * 2,
			// Sum the widths of sequence together
			// Plus 5 in between
			height: items.reduce(0) { $0 + $1.size.height + Self.separation } - Self.separation,
		);
		// TODO: Allow user-selected alignment
		// Use first
		self.inPoint = .init(x: 0, y: items.first!.inPoint.y);
		self.outPoint = .init(x: self.size.width, y: items.first!.outPoint.y);
		// centered
//		self.inPoint = .init(x: 0, y: self.size.height/2);
//		self.outPoint = .init(x: self.size.width, y: self.size.height/2);
		// Use last
//		self.inPoint = .init(x: 0, y: items.last!.inPoint.y);
//		self.outPoint = .init(x: self.size.width, y: items.last!.outPoint.y);
		self.items = items;
	}
	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		var children: Array<RailroadSVGNode> = [];
		var currentHeight: CGFloat = 0;
		let maxWidth = self.size.width - Self.padding * 2;

		for item in items {
			// Draw tracks in
			children.append(
				SVGPath(CGPoint(x: offset.x + self.inPoint.x, y: offset.y + self.inPoint.y))
					.elevator(Self.padding, currentHeight + item.inPoint.y - self.inPoint.y)
					.node
					.attribute("data-type", "in")
			);

			// Draw tracks out
			children.append(
				SVGPath(CGPoint(x: offset.x + Self.padding + item.outPoint.x, y: offset.y + currentHeight + item.outPoint.y))
					.right(maxWidth - item.size.width)
					.elevator(Self.padding, self.outPoint.y - item.outPoint.y - currentHeight)
					.node.attribute("data-type", "out")
			);

			// Draw railroad out
			//children.append(SVGPath(previousOut).right(10).node);

			// Draw item
			children.append(item.toSVGNode(offset: CGPoint(x: offset.x + Self.padding, y: offset.y + currentHeight)))

			currentHeight += item.size.height + Self.separation;
		}

		// TODO: When figuring out how to lay out the y-position,
		// first, the tallest item gets laid out first.
		// Then, the items before it and after it get laid out separately.
		// The items before it get justified at the top.
		// The items after it get justified at the bottom.
		// Left to right, it flows top down whenever possible.
		//

		return .init(
			elementName: "g",
			attributes: [
				"data-updown": "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)",
				"data-type": "choice",
			],
			children: children,
		);
	}
}

public struct RRContainerLoop: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let item: RRContainerProtocol;
	public let rep: RRContainerProtocol;

	static let separation: CGFloat = 8;
	static let radius: Double = 10;

	init(item: RRContainerProtocol, rep: RRContainerProtocol = RRContainerSkip()) {
		self.size = .init(
			width: max(item.size.width, rep.size.width) + Self.radius * 2,
			height: item.size.height + Self.separation,
		);
		self.inPoint = .init(x: 0, y: item.inPoint.y);
		self.outPoint = .init(x: self.size.width, y: item.outPoint.y);
		self.item = item
		self.rep = rep
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		let ar: Double = Self.radius
		var children: [RailroadSVGNode] = []
		let x = offset.x
		let y = offset.y
		// Draw item
		children.append(SVGPath(offset + self.inPoint).right(ar).node)
		let itemNode = item.toSVGNode(offset: CGPoint(x: x + ar, y: y))
		children.append(itemNode)
		children.append(SVGPath(offset + self.outPoint).left(ar).node)

		// Draw loop
		children.append(SVGPath(x: offset.x + Self.radius + item.outPoint.x, y: offset.y + item.outPoint.y)
			.arc(.n, .e)
			.down(item.size.height - item.outPoint.y + Self.separation - Self.radius*2)
			.arc(.e, .s)
			.left(item.size.width)
			.arc(.s, .w)
			.up(item.size.height - item.inPoint.y + Self.separation - Self.radius*2)
			.arc(.w, .n)
			.node
		)
		// TODO: Draw the loop through `rep`
		// which is supposed to be a Terminal that specifies a delimiter that goes in between repetitions.

		return RailroadSVGNode(
			elementName: "g",
			attributes: [
				"data-updown": "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)",
				"data-type": "oneormore",
			],
			children: children,
		)
	}
}

public struct RRContainerGroup: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let item: RRContainerProtocol;
	public let label: String;
	static let padding: Double = 0;
	static let radius: Double = 6;
	init(item: RRContainerProtocol, label: String = "") {
		self.size = .init(
			width: item.size.width + Self.padding*2,
			height: item.size.height + Self.padding*2,
		);
		self.inPoint = .init(x: 0 + Self.padding, y: item.inPoint.y + Self.padding);
		self.outPoint = .init(x: self.size.width - Self.padding, y: item.outPoint.y + Self.padding);
		self.item = item
		self.label = label
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		.init(
			elementName: "g",
			attributes: [
				"x": "\(offset.x)",
				"y": "\(offset.y)",
				"width": "\(self.item.size.width)",
				"height": "\(self.item.size.height + Self.padding*2)",
				"rx": "\(Self.radius)",
				"ry": "\(Self.radius)",
				"data-updown": "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)",
				"data-type": "group",
			],
			children: [
				.init(
					elementName: "rect",
					className: ["group-box"],
					attributes: [
						"x": "\(offset.x)",
						"y": "\(offset.y)",
						"width": "\(self.item.size.width)",
						"height": "\(self.item.size.height)",
						"rx": "\(Self.radius)",
						"ry": "\(Self.radius)",
					],
					children: [
						item.toSVGNode(offset: CGPoint(x: offset.x + Self.padding, y: offset.y + Self.padding)),
					],
				),
				item.toSVGNode(offset: CGPoint(x: offset.x + Self.padding, y: offset.y + Self.padding)),
			] + (self.label.isEmpty ? [] : [
				RailroadSVGNode(
					elementName: "text",
					attributes: [
						"x": "\(offset.x+size.width/2)",
						"y": "\(offset.y+size.height/2 + 4)",
					],
					cdata: label,
				)
			]),
		);
	}
}

public struct RRContainerStart: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let text: String;
	init(text: String) {
		self.size = .init(
			width: max(10 + 8.5 * Double(text.count), 20), // Varible by character count, but at least 20
			height: text.isEmpty ? 20 : 30, // Add an extra 10 for text, if present
		);
		self.inPoint = .init(x: 0, y: text.isEmpty ? 10 : 20);
		self.outPoint = .init(x: self.size.width, y: text.isEmpty ? 10 : 20);

		self.text = text
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		.init(
			elementName: "g",
			attributes: [
				"data-updown": "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)",
				"data-type": "start",
			],
			children: [
				SVGPath(offset + self.inPoint + CGPoint(x: 0, y: -10))
					.down(20)
					.m(10, -20)
					.down(20)
					.m(-10, -10)
					.right(size.width)
					.node,
				.init(
					elementName: "text",
					attributes: [
						"x": "\(offset.x)",
						"y": "\(offset.y+5)",
						"style": "text-anchor:start",
					],
					cdata: text,
				),
			],
		);
	}
}

public struct RRContainerEnd: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let text: String;
	init(text: String) {
		self.size = .init(width: 20, height: 20);
		self.inPoint = .init(x: 0, y: 10);
		self.outPoint = .init(x: self.size.width, y: 10);
		self.text = text
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		SVGPath(offset + self.inPoint)
			.right(20)
			.m(-10, -10)
			.down(20)
			.m(10, -20)
			.down(20)
			.node
			.attribute("data-updown", "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)")
			.attribute("data-type", "end");
	}
}

public struct RRContainerTerminal: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let text: String;
	public let href: String?;

	init(text: String, href: String?) {
		self.size = .init(
			width: 20 + 8.5 * Double(text.count),
			height: 22,
		);
		self.inPoint = .init(x: 0, y: self.size.height/2);
		self.outPoint = .init(x: self.size.width, y: self.size.height/2);

		self.text = text
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		.init(
			elementName: "g",
			className: ["terminal"],
			attributes: [
				"data-updown": "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)",
				"data-type": "terminal",
			],
			children: [
				.init(
					elementName: "rect",
					attributes: [
						"x": "\(offset.x)",
						"y": "\(offset.y)",
						"width": "\(size.width)",
						"height": "\(size.height)",
						"rx": "\(size.height/2)",
						"ry": "\(size.height/2)",
					],
				),
				.init(
					elementName: "text",
					attributes: [
						"x": "\(offset.x+size.width/2)",
						"y": "\(offset.y+size.height/2 + 4)",
					],
					cdata: text,
				),
			],
		);
	}
}

public struct RRContainerNonTerminal: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let text: String;
	init(text: String) {
		self.size = .init(
			width: 20 + 8.5 * Double(text.count),
			height: 22,
		);
		self.inPoint = .init(x: 0, y: self.size.height/2);
		self.outPoint = .init(x: self.size.width, y: self.size.height/2);

		self.text = text
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		.init(
			elementName: "g",
			className: ["non-terminal"],
			attributes: [
				"data-updown": "\(inPoint.y) \(outPoint.y-inPoint.y) \(size.height-inPoint.y)",
				"data-type": "nonterminal",
			],
			children: [
				.init(
					elementName: "rect",
					attributes: [
						"x": "\(offset.x)",
						"y": "\(offset.y)",
						"width": "\(size.width)",
						"height": "\(size.height)",
					],
				),
				.init(
					elementName: "text",
					attributes: [
						"x": "\(offset.x+size.width/2)",
						"y": "\(offset.y+size.height/2 + 4)",
					],
					cdata: text,
				)
				.link(href: text+".html")
			],
		);
	}
}

/// Forms a single point
public struct RRContainerSkip: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	init() {
		self.size = CGSize(width: 0, height: 0);
		self.inPoint = CGPoint(x: 0, y: 0);
		self.outPoint = CGPoint(x: 0, y: 0);
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		.init(
			elementName: "g",
			attributes: [:],
		);
	}
}

public struct RRContainerComment: RRContainerProtocol {
	public let size: CGSize
	public var inPoint: CGPoint
	public var outPoint: CGPoint
	public let text: String;
	init(text: String) {
		self.size = .init(
			width: 10 + 9 * Double(text.count),
			height: 20,
		);
		self.inPoint = .init(x: 0, y: 0);
		self.outPoint = .init(x: 0, y: 0);

		self.text = text
	}

	public func toSVGNode(offset: CGPoint) -> RailroadSVGNode {
		.init(
			elementName: "text",
			attributes: [
				"x": "\(offset.x-size.width/2)",
				"y": "\(offset.y-size.height/2)",
				"style": "text-anchor:start",
			],
			cdata: text,
		);
	}
}

public struct RailroadSVGNode: Hashable {
	var elementName: String;
	var attributes: Dictionary<String, String>;
	var id: String;
	var className: Array<String>;
	var comment: String;
	var cdata: String;
	var children: [RailroadSVGNode];

	static let attributeOrder = ["class", "data-updown", "data-type", "d", "x", "y", "width", "height", "rx", "ry", "stroke", "fill", "style", "viewBox", "transform", "xmlns", "xmlns:xlink", "data", "xlink:href"];

	public init(elementName: String, id: String = "", className: Array<String> = [], attributes: Dictionary<String, String> = [:], comment: String = "", cdata: String = "", children: Array<RailroadSVGNode> = []) {
		self.elementName = elementName;
		self.id = id;
		self.className = className;
		self.attributes = attributes;
		self.comment = comment;
		self.cdata = cdata;
		self.children = children;
	}
	public func toSVG() -> String {
		"<" + elementName
		+ (id.isEmpty ? "" : " id=\"\(id)\"")
		+ (className.isEmpty ? "" : " class=\"\(className.joined(separator: " "))\"")
		+ String(Self.attributeOrder.map {
			(k) in
			if let v=attributes[k] { return " \(k)=\"\(v)\"" } else { return "" }
			}.joined(separator: ""))
		+ ">"
		+ (comment.isEmpty ? "" : "\n<!-- \(comment) -->")
		+ (children.isEmpty ? "" : "\n")
		+ cdata
		+ children.map{$0.toSVG()+"\n"}.joined(separator: "")
		+ "</"
		+ elementName
		+ ">";
	}
	public func attribute(_ key: String, _ value: String) -> Self {
		var attrs = attributes;
		attrs[key] = value;
		return Self(elementName: elementName, id: id, className: className, attributes: attrs, comment: comment, cdata: cdata, children: children);
	}
	public func link(href: String?) -> Self {
		guard let href else { return self }
		return Self(
			elementName: "a",
			attributes: [ "xlink:href": href ],
			children: [ self ],
		)
	}
}

public struct SVGPath {
	var value: String;
	public init (x: Float, y: Float) {
		self.value = "M\(x) \(y)";
	}
	public init (x: Double, y: Double) {
		self.value = "M\(x) \(y)";
	}
	public init (_ pt: CGPoint) {
		self.value = "M\(pt.x) \(pt.y)";
	}
	init(value: String) {
		self.value = value;
	}

	public func m(_ dx: Double, _ dy: Double) -> Self {
		SVGPath(value: value + "m\(dx) \(dy)")
	}
	public func m(_ pt: CGPoint) -> Self {
		SVGPath(value: value + "m\(pt.x) \(pt.y)")
	}

	public func h(_ val: Double) -> Self {
		SVGPath(value: value + "h\(val)")
	}
	public func right(_ val: Double) -> Self {
		h(max(0, val))
	}
	public func left(_ val: Double) -> Self {
		h(-max(0, val))
	}
	public func down(_ by: Double) -> Self {
		v(max(0, by))
	}
	public func up(_ by: Double) -> Self {
		v(-max(0, by))
	}
	public func v(_ val: Double) -> Self {
		SVGPath(value: value + "v\(val)")
	}
	public func arc(_ from: Direction, _ to: Direction, ar: Double = 10) -> Self {
		var x = ar;
		var y = ar;
		if from == .e || to == .w { x *= -1 }
		if from == .s || to == .n { y *= -1 }
		let cw: Int = switch (from, to) {
			case (.n, .e), (.e, .s), (.s, .w), (.w, .n): 1;
			default: 0;
		}
		return SVGPath(value: value + "a\(ar) \(ar) 0 0 \(cw) \(x) \(y)")
	}
	public func l(_ x: Float, _ y: Float) -> Self {
		SVGPath(value: value + "l\(x) \(y)")
	}
	public func elevator(_ dx: Double, _ dy: Double) -> Self {
		let ar = abs(dx)/2;
		if dy < 0 {
			return self.arc(.s, .e, ar: ar).up(-dy-dx).arc(.w, .n, ar: ar)
		} else if dy == 0 {
			return self.h(dx)
		} else if dy > 0 {
			return self.arc(.n, .e, ar: ar).down(dy-dx).arc(.w, .s, ar: ar)
		}
		fatalError()
	}
	var node: RailroadSVGNode {
		RailroadSVGNode(
			elementName: "path",
			attributes: ["d": value],
		)
	}

	/// The position on the circle where to perform the stroke.
	/// If tracing south then turning east, you would use a W-S arc: ╰
	public enum Direction { case n; case e; case s; case w; }
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
	CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

private func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
	CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}
