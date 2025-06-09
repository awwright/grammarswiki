// A SwiftUI View accepting a FSM and producing a text area with GraphViz code
import FSM
import SwiftUI

struct GraphVizSourceView: View {
	typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	@Binding var rule_alphabet: ClosedRangeAlphabet<UInt32>?
	@Binding var rule_fsm: DFA?
	@State private var vizSource: String? = nil

	var body: some View {
		Group {
			if let vizSource {
				Text(vizSource)
					.textSelection(.enabled)
					.border(Color.gray, width: 1)
			} else {
				Text("Building...")
					.foregroundColor(.gray)
			}
		}
		.onChange(of: rule_alphabet) { computeVizSource() }
		.onChange(of: rule_fsm) { computeVizSource() }
		.onAppear() { computeVizSource() }
	}

	private func computeVizSource() {
		guard let dfa = rule_fsm else {
			vizSource = nil
			return
		}
		Task.detached(priority: .userInitiated) {
//			var viz = "";
//			viz += "digraph G {\n";
//			viz += "\t_initial [shape=point];\n";
//			viz += "\t_initial -> \(dfa.initial);\n";
//			for source in dfa.states.indices {
//				let shape = dfa.finals.contains(source) ? "doublecircle" : "circle";
//				viz += "\t\(source) [label=\"\(source)\", shape=\"\(shape)\"];\n";
//				for (target, symbols) in dfa.targets(source: source) {
//					viz += "\t\(source) -> \(target) [label=\(graphvizLabelEscapedString(symbols.map { String(describing: $0) }.joined(separator: " ")))];\n";
//				}
//			}
//			viz += "}\n";
			let result = dfa.toViz();
			await MainActor.run {
				vizSource = result
			}
		}
	}
}
