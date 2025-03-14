import SwiftUI
import FSM

struct ContentView: View {
	// User input
	@State private var text: String = ""
	@State private var selectedRule: String? = nil
	@State private var testInput: String = ""

	// Computed variables
	// TODO: There's probably a way to actually compute these reactive to the user input
	@State private var rulelist: ABNFRulelist<UInt32>? = nil
	@State private var rulelist_fsm: Dictionary<String, DFA<Array<UInt32>>>? = nil
	@State private var parseError: String? = nil
	@State private var testResult: String? = nil
	@State private var graphviz = ""

	var body: some View {
		HStack(spacing: 20) {
			VStack(alignment: .leading) {
				Text("ABNF Grammar")
					.font(.headline)
				TextEditor(text: $text)
					.border(Color.gray, width: 1)
					.font(Font.system(.body, design: .monospaced))
					.autocorrectionDisabled(true)
				if let error = parseError {
					Text("Parse Error: \(error)")
						.foregroundColor(.red)
				} else {
					Text("Grammar parsed successfully")
						.foregroundColor(.green)
				}
			}

			VStack(alignment: .leading) {
				Text("Test Input")
					.font(.headline)
				if let rulelist = rulelist {
					Picker("Select Starting Rule", selection: $selectedRule) {
						Text("Select a rule").tag(String?.none)
						ForEach(Array(rulelist.dictionary.keys.sorted()), id: \.self) { rule in
							Text(rule).tag(String?.some(rule))
						}
					}
					.pickerStyle(MenuPickerStyle())
					TextField("Enter test input", text: $testInput)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.onChange(of: testInput) {
							testInputAgainstRule()
						}

					if graphviz.isEmpty == false {
						Text(graphviz)
					}

					if let testResult {
						Text("Result: \(testResult)")
							.foregroundColor(testResult == "Accepted" ? .green : .red)
					}
				} else {
					Text("No valid grammar loaded")
						.foregroundColor(.gray)
				}
				Spacer()
			}
			.frame(minWidth: 200)
		}
		.padding()
		.onChange(of: self.text) {
			// Update rulelist when document text changes
			updateRulelist(self.text)
		}
		.onAppear {
			// Initial parse when view appears
			updateRulelist(self.text)
		}
	}

	/// Parses the grammar text into a rulelist
	private func updateRulelist(_ text: String) {
		let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
		if let (parsed, _) = ABNFRulelist<UInt32>.match(input) {
			rulelist = parsed
			rulelist_fsm = parsed.toPattern()
			parseError = nil
			if let currentSelection = selectedRule, !parsed.dictionary.keys.contains(currentSelection) {
				if let firstRule = parsed.rules.first {
					selectedRule = firstRule.rulename.label
				}else{
					selectedRule = nil
				}
			} else if let firstRule = parsed.rules.first {
				selectedRule = firstRule.rulename.label
			}
		} else {
			rulelist = nil
			rulelist_fsm = nil
			parseError = "Failed to parse grammar"
			selectedRule = nil
			testResult = nil
		}
	}

	/// Tests the input against the selected rule
	private func testInputAgainstRule() {
		guard let rulelist,
				let selectedRule,
				rulelist.dictionary[selectedRule] != nil
		else {
			testResult = "Invalid selection"
			return
		}
		let input = Array(testInput.unicodeScalars.map(\.value))
		let compiledRulelist: Dictionary<String, DFA<Array<UInt32>>> = rulelist.toPattern(as: DFA<Array<UInt32>>.self);
		guard let selected_fsm = compiledRulelist[selectedRule] else {
			testResult = "Rule `\(selectedRule)` is recursive"
			return
		}
		graphviz = selected_fsm.toViz()

		if selected_fsm.contains(input) {
			testResult = "Accepted"
		} else {
			testResult = "Rejected"
		}
	}
}
