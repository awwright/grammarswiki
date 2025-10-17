// A SwiftUI View for rendering railroad diagrams
import FSM
import SwiftUI

struct RRIO: Hashable, Equatable {
	let i: UnitPoint;
	let o: UnitPoint;

	struct Preference: PreferenceKey {
		typealias Value = [RRIO]
		static var defaultValue: Value = []
		static func reduce(value: inout Value, nextValue: () -> Value) {
			 value += nextValue()
		}
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
		Text("┝┿")
			.fixedSize()
			.monospaced()
			.preference(key: RRIO.Preference.self, value: [RRIO(i: UnitPoint.leading, o: UnitPoint.trailing)])
	}
}

struct RREnd: View {
	let text: String
	var body: some View {
		Text("┿┥")
			.fixedSize()
			.monospaced()
			.preference(key: RRIO.Preference.self, value: [RRIO(i: UnitPoint.leading, o: UnitPoint.trailing)])
	}
}

struct RRSequence: View {
	let items: [RailroadNode]
	@State private var point: RRIO? = nil

	struct OverlayedView: View {
		let node: RailroadNode
		@State private var points: [RRIO] = []
		var body: some View {
			ZStack {
				AnyView(RRView.render(node))
				ForEach(points, id: \.self) { rr in
					GeometryReader { geo in
						Circle().fill(Color.green).frame(width: 10, height: 10)
							.position(x: geo.size.width * rr.i.x, y: geo.size.height * rr.i.y)
						Circle().fill(Color.red).frame(width: 10, height: 10)
							.position(x: geo.size.width * rr.o.x, y: geo.size.height * rr.o.y)
					}
				}
			}
			.onPreferenceChange(RRIO.Preference.self) { self.points = $0 }
		}
	}

	var body: some View {
		if items.isEmpty {
			RRSkip()
		} else {
			HStack {
				ForEach(items, id: \.self) { node in
					OverlayedView(node: node)
				}
			}
			.onPreferenceChange(RRIO.Preference.self) { pointsArray in
				if pointsArray.isEmpty {
					point = RRIO(i: UnitPoint.center, o: UnitPoint.center)
				} else {
					let first = pointsArray[0]
					let last = pointsArray[pointsArray.count - 1]
					point = RRIO(i: first.i, o: last.o)
				}
			}
			.preference(key: RRIO.Preference.self, value: point.map { [$0] } ?? [])
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
			.preference(key: RRIO.Preference.self, value: [RRIO(i: UnitPoint.leading, o: UnitPoint.trailing)])
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
			.preference(key: RRIO.Preference.self, value: [RRIO(i: UnitPoint.leading, o: UnitPoint.trailing)])
	}
}

struct RRSkip: View {
	var body: some View {
		Color.clear.frame(width: 10, height: 10)
			.preference(key: RRIO.Preference.self, value: [RRIO(i: UnitPoint.leading, o: UnitPoint.trailing)])
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
			.preference(key: RRIO.Preference.self, value: [RRIO(i: UnitPoint.leading, o: UnitPoint.trailing)])
	}
}
