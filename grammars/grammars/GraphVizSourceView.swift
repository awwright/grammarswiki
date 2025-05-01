// A SwiftUI View accepting a FSM and producing a text area with GraphViz code
import FSM
import SwiftUI

struct GraphVizSourceView: View {
	 @Binding var rule_alphabet: ClosedRangeSymbolClass<UInt32>?
	 @Binding var rule_fsm: DFA<UInt32>?
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
		  guard let alphabet = rule_alphabet, let fsm = rule_fsm else {
				vizSource = nil
				return
		  }
		  Task.detached(priority: .userInitiated) {
				let reducedAlphabetLanguage = DFA<UInt32>.union(alphabet.partitionLabels.map { DFA<UInt32>.symbol($0) }).star()
			  let expanded: DFA<String> = fsm.intersection(reducedAlphabetLanguage).mapSymbols { describeCharacterSet(alphabet.siblings(of: $0)) }
				let result = expanded.minimized().toViz()
				await MainActor.run {
					 vizSource = result
				}
		  }
	 }
}
