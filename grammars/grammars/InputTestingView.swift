import SwiftUI
import FSM

// TODO: Show equivalent inputs
// TODO: Show a multi-line input if the pattern permits newlines
// TODO: Show an option for newline representation and character encoding

struct InputTestingView: View {
	@Binding var content_rulelist: ABNFRulelist<UInt32>?
	@Binding var selectedRule: String?
	@Binding var rule_alphabet: ClosedRangeSymbolClass<UInt32>?
	@Binding var rule_fsm: ClosedRangeDFA<UInt32>?
	@State private var testInput: String = ""
	@State private var fsm_test_result: Bool? = nil
	@State private var fsm_test_next: Array<ClosedRange<UInt32>>? = nil
	@State private var fsm_test_error: String? = nil

	var body: some View {
		Group {
			TextField("Enter test input", text: $testInput)
				.textFieldStyle(RoundedBorderTextFieldStyle())

			if let fsm_test_result {
				Text("Result: " + (fsm_test_result ? "Accepted" : fsm_test_error ?? "Rejected"))
					.foregroundColor(fsm_test_result == true ? .green : .red)
				if let fsm_test_next {
					Text("Next symbols: " + describeCharacterSet(fsm_test_next))
				} else {
					Text("Next symbols: Oblivion")
				}
			} else if let fsm_test_error {
				Text(fsm_test_error).foregroundColor(.red)
			}
		}
		.onAppear { updatedInput() }
		.onChange(of: selectedRule) { updatedInput() }
		.onChange(of: rule_fsm) { updatedInput() }
		.onChange(of: rule_alphabet) { updatedInput() }
		.onChange(of: testInput) { updatedInput() }
	}

	private func updatedInput() {
		fsm_test_result = nil
		fsm_test_error = nil
		fsm_test_next = nil

		guard let content_rulelist = content_rulelist,
				let selectedRule = selectedRule,
				content_rulelist.dictionary[selectedRule] != nil
		else {
			fsm_test_error = "Invalid selection"
			return
		}
		let input = Array(testInput.unicodeScalars.map(\.value))
		guard let selected_fsm = rule_fsm?.expanded else {
			fsm_test_error = "Rule `\(selectedRule)` is recursive or missing rules"
			return
		}

		let fsm_test_state = selected_fsm.nextState(state: selected_fsm.initial, input: input)
		fsm_test_result = selected_fsm.isFinal(fsm_test_state)
		if let fsm_test_state {
			fsm_test_next = selected_fsm.states[fsm_test_state].keys.flatMap { rule_alphabet?.siblings(of: $0).segments ?? [] }
		}
		if fsm_test_result == false {
			if fsm_test_state != nil {
				fsm_test_error = "unexpected EOF"
			} else {
				fsm_test_error = "oblivion"
			}
		}
	}
}
