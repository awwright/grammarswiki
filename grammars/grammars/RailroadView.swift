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
			HStack {
				AnyView(render(start));
				ForEach(seq, id: \.self) { node in
					AnyView(self.render(node))
				}
				AnyView(render(end))
			}
		case .Start(label: let text):
			VStack {
				if let text { RRComment(text: text); }
				Text("┝┿");
			}
		case .End(label: let text):
			VStack {
				if let text { RRComment(text: text); }
				Text("┿┥");
			}
		case .Sequence(items: let seq):
			HStack {
				ForEach(seq, id: \.self) { node in
					AnyView(self.render(node))
				}
			}
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

struct RRTerminal: View {
	let text: String
	var body: some View {
		Text(text)
			.fixedSize()
			.monospaced()
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(
				RoundedRectangle(cornerRadius: 8)
					.stroke(Color.black, lineWidth: 2)
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
					.stroke(Color.black, lineWidth: 2)
			)
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
