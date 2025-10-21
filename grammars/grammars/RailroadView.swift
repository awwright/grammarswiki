// A SwiftUI View for rendering railroad diagrams
import FSM
import SwiftUI

struct CGRectPreference: PreferenceKey {
	// The top left and bottom right represent the in and out points
	typealias Value = [Anchor<CGRect>]
	static var defaultValue: Value = []
	static func reduce(value: inout Value, nextValue: () -> Value) {
		value += nextValue()
	}
}

struct RRView: View {
	var diagram: RailroadNode

	var body: some View {
		// TODO: Accept a given grammar or DFA and render it as a railroad diagram
		// Perhaps create a new protocol RailroadGeneratorProtocol that specifies how to transform
		// a given document into a RailroadDiagram. Then display it here.
		AnyView(Self.render(self.diagram));
	}

	static func render(_ node: RailroadNode) -> any View {
		return switch node {
		case .Diagram(start: let start, sequence: let seq, end: let end):
			AnyView(render(.Sequence(items: [start] + seq + [end])));
		case .Start(label: let text):
			RRStart(text: text ?? "")
		case .End(label: let text):
			RREnd(text: text ?? "")
		case .Sequence(items: let seq):
			RRSequence(items: seq)
		case .Choice(items: let seq):
			RRChoice(items: seq)
		case .Optional(item: let item):
			AnyView(self.render(item))
		case .Terminal(text: let text):
			RRTerminal(text: text);
		case .NonTerminal(text: let text):
			RRNonTerminal(text: text);
		case .Comment(text: let text):
			RRComment(text: text);
		default:
			RRComment(text: "Unknown node type: \(node)");
		}
	}
}

struct RRStart: View {
	let text: String
	var body: some View {
		Text(text)
			.fixedSize()
			.monospaced()
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(
				RoundedRectangle(cornerRadius: .infinity)
					.stroke(.foreground, lineWidth: 2)
			)
			.background {
				// See RRTerminal for how this works
				GeometryReader { geometry in
					Color.clear
						.frame(height: 0)
						.frame(maxWidth: .infinity)
						.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
						.position(x: geometry.size.width / 2, y: geometry.size.height / 2)
				}
			}
	}
}

struct RREnd: View {
	let text: String
	var body: some View {
		Text(text)
			.fixedSize()
			.monospaced()
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(
				RoundedRectangle(cornerRadius: .infinity)
					.stroke(.foreground, lineWidth: 2)
			)
			.background {
				// See RRTerminal for how this works
				GeometryReader { geometry in
					Color.clear
						.frame(height: 0)
						.frame(maxWidth: .infinity)
						.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
						.position(x: geometry.size.width / 2, y: geometry.size.height / 2)
				}
			}
	}
}

struct RRSequence: View {
	let items: [RailroadNode]
	@State private var point: CGRect? = nil
	@State private var points: [CGRect] = []

	var body: some View {
		if items.isEmpty {
			RRSkip()
		} else {
			HStack(spacing: 25) {
				ForEach(items.indices, id: \.self) { index in
					AnyView(RRView.render(items[index]))
				}
			}
			.backgroundPreferenceValue(CGRectPreference.self) { preferences in
				GeometryReader { geo in
					let rects = preferences.map { geo[$0] };
					if rects.count <= 1 {
						EmptyView();
					} else {
						ZStack {
							ForEach(0..<rects.count-1, id: \.self) { i in
								let rect0 = rects[i]
								let rect1 = rects[i+1]
								let from = CGPoint(x: rect0.maxX, y: rect0.maxY)
								let to = CGPoint(x: rect1.minX, y: rect1.minY)
								RRConnector(start: from, end: to).stroke(.foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
							}
						}
					}
					if !rects.isEmpty {
						// Pass up the first in point and last out point
						let inPoint = CGPoint(x: rects[0].minX, y: rects[0].minY)
						let outPoint = CGPoint(x: rects[rects.count-1].maxX, y: rects[rects.count-1].maxY)
						Color.clear
							.frame(width: outPoint.x - inPoint.x, height: outPoint.y - inPoint.y)
							.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
							.position(x: inPoint.x + (outPoint.x - inPoint.x)/2, y: inPoint.y + (outPoint.y - inPoint.y)/2)
					}
				}
			}
			.transformAnchorPreference(key: CGRectPreference.self, value: .bounds) { $0 = [$0.first ?? $1] }
			.padding(.horizontal, 20)
		}
	}
}

struct RRChoice: View {
	let items: [RailroadNode]
	@State private var point: CGRect? = nil
	@State private var points: [CGRect] = []

	var body: some View {
		if items.isEmpty {
			RRSkip()
		} else {
			VStack(spacing: 10) {
				ForEach(items.indices, id: \.self) { index in
					AnyView(RRView.render(items[index]))
				}
			}
			.padding(.horizontal, 30)
			.backgroundPreferenceValue(CGRectPreference.self) { preferences in
				GeometryReader { geo in
					if preferences.isEmpty {
						EmptyView()
					} else {
						let points = preferences.map { geo[$0] };
						let bounding = points.reduce(points[0]) { $0.union($1) }
						let inPoint = CGPoint(x: 0, y: bounding.minY)
						let outPoint = CGPoint(x: geo.size.width, y: bounding.maxY)
						ZStack {
							ForEach(points, id: \.self) { rect in
								RRConnector(start: inPoint, end: CGPoint(x: rect.minX, y: rect.minY)).stroke(.foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
								RRConnector(start: CGPoint(x: rect.maxX, y: rect.maxY), end: outPoint).stroke(.foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
							}
						}
						Color.clear
							.frame(width: outPoint.x - inPoint.x, height: outPoint.y - inPoint.y)
							.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
							.position(x: inPoint.x + (outPoint.x - inPoint.x)/2, y: inPoint.y + (outPoint.y - inPoint.y)/2)
					}
				}
			}
			// Clear the points received from children
			// The last preference will be the one that was added in backgroundPreferenceValue above
			// If there's no such preference, just take the bounding box, since this guarantees exactly one preference.
			// Note that backgroundPreferenceValue adds to the beginning, overlayPreferenceValue adds to the end.
			.transformAnchorPreference(key: CGRectPreference.self, value: .bounds) { $0 = [$0.first ?? $1] }
			// And add a new one
			.background {
				// Draw a rectangle behind the View and pass up the bounds of it as a preference.
				// This is a strange work around for the fact that you can't pass up an arbirtirary CGRect,
				// you have to draw it as a View first.
				// .position needs to go last so that it transforms the anchorPreference along with the rectangle.
				GeometryReader { geometry in
					if let point {
						// TODO: ... To here, position this to the CGRect from backgroundPreferenceValue above
						Color.clear
							.frame(width: 0, height: 0)
							.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
							.position(x: point.midX, y: point.midY)
					}
				}
			}
		}
	}
}

struct RRTerminal: View {
	let text: String
	var body: some View {
		Text(text)
			.fixedSize()
			.monospaced()
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(
				RoundedRectangle(cornerRadius: .infinity)
					.stroke(.foreground, lineWidth: 2)
			)
			.background {
				// Draw a rectangle behind the View and pass up the bounds of it as a preference.
				// This is a strange work around for the fact that you can't pass up an arbirtirary CGRect,
				// you have to draw it as a View first.
				GeometryReader { geometry in
					Color.clear
						.frame(width: geometry.size.width, height: 0)
						.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
						.position(x: geometry.size.width / 2, y: geometry.size.height / 2)
				}
			}
	}
}

struct RRNonTerminal: View {
	let text: String
	var body: some View {
		Text(text)
			.fixedSize()
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(
				Rectangle()
					.stroke(.foreground, lineWidth: 2)
			)
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
	}
}

struct RRSkip: View {
	var body: some View {
		Color.clear.frame(width: 10, height: 10)
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
	}
}

struct RRComment: View {
	let text: String
	var body: some View {
		Text(text)
			.fixedSize()
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.font(.caption)
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
	}
}

struct RRConnector: Shape {
	var start: CGPoint
	var end: CGPoint
	var radius: CGFloat = 10.0

	func path(in rect: CGRect) -> Path {
		var path = Path()
		let dx = end.x - start.x
		let dy = end.y - start.y

		// Reduce radius for points very close together
		// TODO: In the future, draw a partial arc instead of the full 1/4 circle arc
		let radius = min(min(abs(dx), abs(dy))/2, self.radius);
		if abs(dx) < 1 || abs(dy) < 1 {
			path.move(to: start)
			path.addLine(to: end)
			return path
		}

		// Determine directions
		let horizontalDirection: CGFloat = dx > 0 ? 1 : -1;
		let verticalDirection: CGFloat = dy > 0 ? 1 : -1;
		path.move(to: start)

		// First line
		let arc1Start = CGPoint(x: start.x + dx - 2 * radius, y: start.y)
		path.addLine(to: arc1Start)

		// First arc: Connect to vertical line direction
		let center1 = CGPoint(x: arc1Start.x, y: start.y + verticalDirection * radius)
		let startAngle1: Angle = .degrees(verticalDirection > 0 ? 270 : 90)
		let endAngle1: Angle = .degrees(horizontalDirection > 0 ? 0 : 180)
		let clockwise1 = (horizontalDirection * verticalDirection < 0)
		path.addArc(center: center1, radius: radius, startAngle: startAngle1, endAngle: endAngle1, clockwise: clockwise1)

		// Vertical line to the second arc
		let arc2Start = CGPoint(x: arc1Start.x + horizontalDirection * radius, y: end.y - verticalDirection * radius)
		path.addLine(to: arc2Start)

		// Second arc: Turn back to horizontal
		let center2 = CGPoint(x: arc2Start.x + horizontalDirection * radius, y: arc2Start.y)
		let startAngle2: Angle = .degrees(horizontalDirection > 0 ? 180 : 0)
		let endAngle2: Angle = .degrees(verticalDirection > 0 ? 90 : 270)
		let clockwise2 = (horizontalDirection * verticalDirection > 0)
		path.addArc(center: center2, radius: radius, startAngle: startAngle2, endAngle: endAngle2, clockwise: clockwise2)

		return path;
	}
}

extension View {
	func showRRTerminals() -> some View {
		RRShowTerminals { self }
	}
}

struct RRShowTerminals<Content: View>: View {
	let content: () -> Content
	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}
	var body: some View {
		content()
			.overlayPreferenceValue(CGRectPreference.self) { points in
				GeometryReader { geo in
					ZStack {
						ForEach(points, id: \.self) { point in
							Circle().fill(Color.green).frame(width: 10, height: 10).position(x: geo[point].minX, y: geo[point].minY)
							Circle().fill(Color.red).frame(width: 10, height: 10).position(x: geo[point].maxX, y: geo[point].maxY)
						}
					}
				}
			}
	}
}

#Preview {
	VStack(spacing: 20) {
		Section("Nodes") {
			HStack(spacing: 40) {
				RRStart(text: "RRStart").showRRTerminals();
				RRTerminal(text: "RRTerminal").showRRTerminals();
				RRNonTerminal(text: "RRNonTerminal").showRRTerminals();
				RRComment(text: "RRComment").showRRTerminals();
				RREnd(text: "RREnd").showRRTerminals();
			}
		}
		Section("Sequence") {
			RRView(diagram: .Sequence(items: [
				.Start(label: "O"),
				.Terminal(text: "1"),
				.NonTerminal(text: "2"),
				.Terminal(text: "3"),
				.End(label: "X"),
			])).showRRTerminals();
		}
		Section("Choice") {
			RRView(diagram: .Choice(items: [
				.Terminal(text: "1"),
				.Terminal(text: "2"),
				.Terminal(text: "3"),
			])).showRRTerminals();
		}
		Section("Sequence of Choice") {
			RRView(diagram: .Sequence(items: [
				.Choice(items: [
					.Terminal(text: "1"),
					.Terminal(text: "2"),
					.Terminal(text: "3"),
				]),
				.Choice(items: [
					.NonTerminal(text: "A"),
					.NonTerminal(text: "B"),
					.NonTerminal(text: "C"),
				]),
			])).showRRTerminals();
		}
		Section("Choice of Sequence Diagram") {
			RRView(diagram: .Sequence(items: [
				.Start(label: "Start"),
				.Choice(items: [
					.Sequence(items: [
						.Terminal(text: "1"),
						.Terminal(text: "2"),
						.Terminal(text: "3"),
					]),
					.Sequence(items: [
						.NonTerminal(text: "A"),
						.NonTerminal(text: "B"),
						.NonTerminal(text: "C"),
					]),
				]),
				.End(label: "End"),
			])).showRRTerminals();
		}
		Section("Arc") {
			HStack(spacing: 10) {
				RRConnector(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 30))
					.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
					.frame(width: 100, height: 50)
				RRConnector(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 30))
					.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
					.frame(width: 100, height: 50)
				RRConnector(start: CGPoint(x: 0, y: 30), end: CGPoint(x: 100, y: 0))
					.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
					.frame(width: 100, height: 50)
				RRConnector(start: CGPoint(x: 0, y: 30), end: CGPoint(x: 0, y: 0))
					.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
					.frame(width: 100, height: 50)
			}
		}
	}.padding(50)
}
