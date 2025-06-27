// A SwiftUI View accepting a FSM and producing a text area with GraphViz code
import FSM
import SwiftUI

struct FSMExportView: View {
	typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	var export_format: String? = nil

	@Binding var rule_alphabet: ClosedRangeAlphabet<UInt32>?
	@Binding var rule_fsm: DFA?
	@AppStorage("export_format_selected") private var exportFormatSelected: String = "graphviz"

	@State private var vizSource: String? = nil

	enum ExportFormat: String, CaseIterable, Identifiable {
		case graphviz = "GraphViz dot file"
		case swift = "Swift FSM object"

		var id: String { self.rawValue }
	}

	var body: some View {
		Group {
			Form {
				Section(header: Text("Format Options").font(.headline)) {
					Picker("Regex Dialect", selection: $exportFormatSelected) {
						ForEach(ExportFormat.allCases) { dialect in
							Text(dialect.rawValue).tag(dialect.rawValue)
						}
					}
					.pickerStyle(.menu) // Use a dropdown menu style
					.frame(width: 300)
				}
			}
			.padding()

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
		.onChange(of: exportFormatSelected) { computeVizSource() }
		.onAppear() { computeVizSource() }
	}

	private func computeVizSource() {
		guard let dfa = rule_fsm else {
			vizSource = nil
			return
		}
		// Take a copy of exportFormatSelected to read in a Task
		let exportFormatSelected = exportFormatSelected;
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
			let result: String;
			switch exportFormatSelected {
				case "GraphViz dot file":
					result = dfa.toViz();
				case "Swift FSM object":
					result = """
						FSM<>(
							states: [
						\(dfa.states.map { "\t\t[" + $0.map { "\($0.key): \($0.value)" }.joined() + "]," }.joined(separator: "\n"))
							],
							initial: \(dfa.initial),
							finals: \(dfa.finals)
						)
						""";
				default:
					result = "Unknown format: " + exportFormatSelected;
			}
			await MainActor.run {
				vizSource = result
			}
		}
	}
}
