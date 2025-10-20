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
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
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
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
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
			HStack(spacing: 50) {
				ForEach(items.indices, id: \.self) { index in
					AnyView(RRView.render(items[index]))
				}
			}
			.padding(10)
			.padding(.bottom, 20)
//				.onPreferenceChange(CGRectPreference.self) { newPoints in
//					self.points = newPoints
//					if newPoints.isEmpty {
//						point = nil
//					} else {
//						let first = newPoints[0]
//						let last = newPoints[newPoints.count - 1]
//						point = CGRect(i: first.i, o: last.o)
//					}
//				}
			.background(
				RoundedRectangle(cornerRadius: 3)
					.stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
			)
			.backgroundPreferenceValue(CGRectPreference.self) { preferences in
				GeometryReader { geo in
					if preferences.count <= 1 {
						EmptyView();
					} else {
						ZStack {
							ForEach(0..<preferences.count-1, id: \.self) { i in
								let rect0 = geo[preferences[i]]
								let rect1 = geo[preferences[i+1]]
								let from = CGPoint(x: rect0.maxX, y: rect0.maxY)
								let to = CGPoint(x: rect1.minX, y: rect1.minY)

								Path { path in
									path.move(to: from)
									path.addLine(to: to)
								}
								.stroke(Color.red, lineWidth: 2)
							}
						}
					}
				}
			}
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
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
					ZStack {
						ForEach(0..<preferences.count, id: \.self) { i in
							let rect = geo[preferences[i]]
							Path { path in
								path.move(to: CGPoint(x: 0, y: 0))
								path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
								path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
								path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
							}
							.stroke(Color.red, lineWidth: 2)
						}
					}
				}

			}
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
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
			.anchorPreference(key: CGRectPreference.self, value: .bounds) { [$0] }
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
		Section("Sequence") {
			RRView(diagram: .Sequence(items: [
				.Start(label: "O"),
				.Terminal(text: "1"),
				.NonTerminal(text: "2"),
				.Terminal(text: "3"),
				.End(label: "X"),
			]));
		}
		Section("Choice") {
			RRView(diagram: .Choice(items: [
				.Terminal(text: "1"),
				.Terminal(text: "2"),
				.Terminal(text: "3"),
			]));
		}
		Section("Sequence of Choice") {
			RRView(diagram: .Sequence(items: [
				.Choice(items: [
					.Terminal(text: "1"),
					.Terminal(text: "2"),
					.Terminal(text: "3"),
				]),
				.Choice(items: [
					.Terminal(text: "A"),
					.Terminal(text: "B"),
					.Terminal(text: "C"),
				]),
			]));
		}
		Section("Diagram") {
			RRView(diagram: .Sequence(items: [
				.Start(label: "O"),
				.Sequence(items: [
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
				]),
				.End(label: "O"),
			]));
		}
	}.padding(50)
}
