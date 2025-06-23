import SwiftUI
import FSM

struct RegexContentView: View {
	@Binding var rule_fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>?
	@State private var regexDescription: String?
	@State private var error: String?

	var body: some View {
		Group {
			if let regexDescription = regexDescription {
				Text(regexDescription)
					.textSelection(.enabled)
					.border(Color.gray, width: 1)
			} else if let error = error {
				Text("Error: \(error)")
					.foregroundColor(.red)
			} else {
				Text("Building...")
					.foregroundColor(.gray)
			}
		}
		.onAppear { computeRegexDescription() }
		.onChange(of: rule_fsm) { computeRegexDescription() }
	}

	private func computeRegexDescription() {
		regexDescription = nil
		error = nil
		guard let fsm = rule_fsm else {
			return
		}
		Task.detached(priority: .utility) {
			let regex: REPattern<UInt32> = fsm.toPattern()
			let description = regex.description
			await MainActor.run {
				regexDescription = description
				error = nil
			}
		}
	}
}
