// A SwiftUI View for rendering railroad diagrams
import FSM
import SwiftUI

/// A struct representing the positional metadata of a Railroad View.
struct RRIO: Equatable, Hashable {
	/// The position of the "in point"
	let i: CGPoint;
	/// The position of the "out point"
	let o: CGPoint;

	init(i: CGPoint, o: CGPoint) {
		self.i = i;
		self.o = o;
	}

	init(_ geo: CGRect) {
		self.i = CGPoint(x: geo.minX, y: geo.midY);
		self.o = CGPoint(x: geo.maxX, y: geo.midY);
	}

	init(_ geo: CGRect, i: UnitPoint, o: UnitPoint) {
		self.i = CGPoint(x: geo.maxX * i.x, y: geo.maxY * i.y);
		self.o = CGPoint(x: geo.maxX * o.x, y: geo.maxY * o.y);
	}

	struct Preference: PreferenceKey {
		typealias Value = [RRIO]
		static var defaultValue: Value = []
		static func reduce(value: inout Value, nextValue: () -> Value) {
			value += nextValue()
		}
	}
}

struct RRGeometryPreference: PreferenceKey {
	typealias Value = [Int: CGRect]
	static var defaultValue: Value = [:]
	static func reduce(value: inout Value, nextValue: () -> Value) {
		value.merge(nextValue(), uniquingKeysWith: { $1 })
	}
}

struct DFARailroadView: View {
	typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	@Binding var rule_fsm: DFA?

	var body: some View {
		// TODO: Accept a given grammar or DFA and render it as a railroad diagram
		// Perhaps create a new protocol RailroadGeneratorProtocol that specifies how to transform
		// a given document into a RailroadDiagram. Then display it here.
		VStack {
			Text("Railroad Diagram").font(.headline);
			RRTerminal(text: "ALPHA");
			RRNonTerminal(text: "'x'")
		}
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
				GeometryReader { geo in
					Color.clear
						.preference(key: RRIO.Preference.self, value: [RRIO(geo.frame(in: .named("RRComposite")))])
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
				GeometryReader { geo in
					Color.clear
						.preference(key: RRIO.Preference.self, value: [RRIO(geo.frame(in: .named("RRComposite")))])
				}
			}
	}
}

struct RRSequence: View {
	let items: [RailroadNode]
	@State private var point: RRIO? = nil
	@State private var points: [RRIO] = []

	var body: some View {
		if items.isEmpty {
			RRSkip()
		} else {
			HStack(spacing: 50) {
				ForEach(items.indices, id: \.self) { index in
					AnyView(RRView.render(items[index]))
				}
			}.padding(5)
			.coordinateSpace(name: "RRComposite")
			.onPreferenceChange(RRIO.Preference.self) { newPoints in
				self.points = newPoints
				if newPoints.isEmpty {
					point = nil
				} else {
					let first = newPoints[0]
					let last = newPoints[newPoints.count - 1]
					point = RRIO(i: first.i, o: last.o)
				}
			}
			.background(
				RoundedRectangle(cornerRadius: 3)
					.stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
			)
			.overlay {
				if !points.isEmpty {
					Path { path in
						for i in 0..<(points.count-1) {
							path.move(to: points[i % points.count].o)
							path.addLine(to: points[(i+1) % points.count].i)
						}
					}
					.stroke(.foreground, lineWidth: 2)
				}
			}
			.preference(key: RRIO.Preference.self, value: point.map { [$0] } ?? [])
		}
	}
}

struct RRChoice: View {
	let items: [RailroadNode]
	@State private var point: RRIO? = nil
	@State private var points: [RRIO] = []

	var body: some View {
		if items.isEmpty {
			RRSkip()
		} else {

			VStack(spacing: 10) {
				ForEach(items.indices, id: \.self) { index in
					AnyView(RRView.render(items[index]))
				}
			}.padding(20)
			.coordinateSpace(name: "RRComposite")
			.onPreferenceChange(RRIO.Preference.self) { newPoints in
				self.points = newPoints
			}
			.background(
				RoundedRectangle(cornerRadius: 3)
					.stroke(Color.secondary, lineWidth: 2)
			)
			.overlay {
				if let point, !points.isEmpty {
					Path { path in
						for i in 0..<points.count {
							path.move(to: point.i)
							path.addLine(to: points[i].i)
							path.move(to: points[i].o)
							path.addLine(to: point.o)
						}
					}
					.stroke(Color.accentColor, lineWidth: 2)
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
				GeometryReader { geo in
					Color.clear
						.preference(key: RRIO.Preference.self, value: [RRIO(geo.frame(in: .named("RRComposite")))])
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
			.background {
				GeometryReader { geo in
					Color.clear
						.preference(key: RRIO.Preference.self, value: [RRIO(geo.frame(in: .named("RRComposite")))])
				}
			}
	}
}

struct RRSkip: View {
	var body: some View {
		Color.clear.frame(width: 10, height: 10)
			.background {
				GeometryReader { geo in
					Color.clear
						.preference(key: RRIO.Preference.self, value: [RRIO(geo.frame(in: .named("RRComposite")))])
				}
			}
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
			.background {
				GeometryReader { geo in
					Color.clear
						.preference(key: RRIO.Preference.self, value: [RRIO(geo.frame(in: .named("RRComposite")))])
				}
			}
	}
}

extension View {
	func showRRTerminals() -> some View {
		RRShowTerminals { self }
	}
}

struct RRShowTerminals<Content: View>: View {
	let content: () -> Content
	@State private var points: [RRIO] = []
	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}
	var body: some View {
		content()
			.onPreferenceChange(RRIO.Preference.self) { newPointPairs in
				self.points = newPointPairs
			}
			.overlay {
				print(points)
				return ZStack {
					ForEach(points, id: \.self) { point in
						Circle().fill(Color.green).frame(width: 10, height: 10).position(x: point.i.x, y: point.i.y)
						Circle().fill(Color.red).frame(width: 10, height: 10).position(x: point.o.x, y: point.o.y)
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
				.Terminal(text: "2"),
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
						.Terminal(text: "A"),
						.Terminal(text: "B"),
						.Terminal(text: "C"),
					]),
				]),
				.End(label: "O"),
			]));
		}
	}.padding(50)
}
