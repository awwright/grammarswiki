import SwiftUI
import FSM

// TODO: Show equivalent inputs
// TODO: Show a multi-line input if the pattern permits newlines
// TODO: Show an option for newline representation and character encoding

struct InputTestingView: View {
	@Binding var content_rulelist: ABNFRulelist<UInt32>?
	@Binding var selectedRule: String?
	@Binding var rule_alphabet: ClosedRangeAlphabet<UInt32>?
	@Binding var rule_fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>?
	let charset: Charset
	@State private var testInput: String = ""
	@State private var fsm_test_result: Bool? = nil
	@State private var fsm_test_next: Array<ClosedRange<UInt32>>? = nil
	@State private var fsm_test_error: String? = nil
	@State private var selectedInputType: String? = nil
	@State private var hexInput: String = ""
	@State private var isUpdating = false

	var body: some View {
		Group {
			let hexFont = Font.system(size: 14).monospaced()

			TabView {
				Tab("Field", systemImage: "pencil") {
					TextField("Enter test input", text: $testInput)
						.font(hexFont)
						.textFieldStyle(RoundedBorderTextFieldStyle())
				}
				Tab("Document", systemImage: "pencil") {
					TextEditor(text: $testInput)
						.font(hexFont)
				}
				Tab("Binary", systemImage: "pencil") {
					HStack {
						TextEditor(text: $hexInput)
							.font(hexFont)
							.frame(width: 450)
						// TODO: This should render special characters as the symbols from U+24xx
						TextEditor(text: $testInput)
							.font(hexFont)
							.frame(width: 159)
					}
				}
			}

			if let fsm_test_result {
				Text("Result: " + (fsm_test_result ? "Accepted" : fsm_test_error ?? "Rejected"))
					.foregroundColor(fsm_test_result == true ? .green : .red)
				if let fsm_test_next {
					Text("Next symbols: " + describeCharacterSet(fsm_test_next, charset: charset))
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
		.onChange(of: testInput) { updateFromTestInput() }
		.onChange(of: hexInput) { updateFromHex() }
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
		guard let selected_fsm = rule_fsm else {
			fsm_test_error = "Rule `\(selectedRule)` is recursive or missing rules"
			return
		}

		let fsm_test_state = selected_fsm.nextState(state: selected_fsm.initial, input: input)
		fsm_test_result = selected_fsm.isFinal(fsm_test_state)
		if let fsm_test_state {
			fsm_test_next = selected_fsm.states[fsm_test_state].alphabet.flatMap { $0 }
		}
		if fsm_test_result == false {
			if fsm_test_state != nil {
				fsm_test_error = "unexpected EOF"
			} else {
				fsm_test_error = "oblivion"
			}
		}
	}

	private func updateFromHex() {
		guard !isUpdating else { return }
		isUpdating = true
		let cleanedHex = hexInput.replacingOccurrences(of: " ", with: "").uppercased()
		guard cleanedHex.count % 2 == 0 else {
			isUpdating = false
			updatedInput()
			return
		}
		var bytes: [UInt8] = []
		for i in stride(from: 0, to: cleanedHex.count, by: 2) {
			let start = cleanedHex.index(cleanedHex.startIndex, offsetBy: i)
			let end = cleanedHex.index(start, offsetBy: 2)
			let hexPair = String(cleanedHex[start..<end])
			if let byte = UInt8(hexPair, radix: 16) {
				bytes.append(byte)
			} else {
				isUpdating = false
				updatedInput()
				return
			}
		}
		let data = Data(bytes)
		if let str = String(data: data, encoding: .ascii) {
			testInput = str
		}
		isUpdating = false
		updatedInput()
	}

	private func updateFromTestInput() {
		guard !isUpdating else { return }
		isUpdating = true
		let bytes = Array(testInput.utf8)
		hexInput = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
		isUpdating = false
		updatedInput()
	}
}
