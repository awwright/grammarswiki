// A SwiftUI View for rendering railroad diagrams
import FSM
import SwiftUI

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
	}
}

struct RREnd: View {
	let text: String
	var body: some View {
		Text("┿┥")
			.fixedSize()
			.monospaced()
	}
}

struct RRSequence: View {
	let items: [RailroadNode]
	var body: some View {
		if items.isEmpty {
			RRSkip()
		} else {
			HStack {
				ForEach(items, id: \.self) { node in
					AnyView(RRView.render(node))
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
	}
}

struct RRSkip: View {
	var body: some View {
		Color.clear.frame(width: 10, height: 10)
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
	}
}
