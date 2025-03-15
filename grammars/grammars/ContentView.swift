// TODO:
// - Show files from custom home directory, allow creating and renaming custom files
// - Open files from any path, as a document view
// - Accordion/disclosure group for different views on the file
// - Replace text editor with a real code editor
// - Parsing errors, show the unexpected character and the permitted characters for that position
// - Auto-completion of rule names
// - Import rules from other documents
// - Limit text field to accepted characters, use a multi-line field if \n is permitted; use \r\n for newlines when \r is permitted

import SwiftUI
import FSM

struct ContentView: View {
	@State var catalog: [DocumentItem]
	// Document selection
	@State private var selection: DocumentItem? = nil

	var body: some View {
		NavigationSplitView {
			List(selection: $selection) {
				Section("Catalog") {
					ForEach(catalog, id: \.self) {
						document in
						NavigationLink(document.name, value: document)
					}
				}
			}
			.navigationTitle("Catalog")
		} detail: {
			if let selection, let index = catalog.firstIndex(where: { $0.id == selection.id }) {
				DocumentDetail(document: $catalog[index])
			} else {
				Text("Select a document")
			}
		}
	}
}

struct DocumentDetail: View {
	@Binding var document: DocumentItem // Binding to the specific document

	// User input
	@State private var selectedRule: String? = nil
	@State private var testInput: String = ""

	// Computed variables
	// TODO: There's probably a way to actually compute these reactive to the user input
	@State private var rulelist: ABNFRulelist<UInt32>? = nil
	@State private var rulelist_fsm: Dictionary<String, DFA<Array<UInt32>>>? = nil
	@State private var parseError: String? = nil
	@State private var testResult: String? = nil

	var body: some View {
		HStack(spacing: 20) {
			VStack(alignment: .leading) {
				Text("ABNF Grammar")
					.font(.headline)
				TextEditor(text: $document.content)
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

			VStack(alignment: .leading) { ScrollView {
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

					if let selectedRule {
						DisclosureGroup("Partitions", content: {
							let partitions = rulelist.dictionary[selectedRule]!.alphabetPartitions(rulelist: rulelist);
							ForEach(Array(partitions), id: \.self) {
								part in
								let sorted = Array(part).sorted(by: { $0 < $1 })
								Text(String(describing: sorted)).border(Color.gray, width: 1).frame(maxWidth: .infinity, alignment: .leading)
							}
						})
					}

					if let rulelist_fsm, let selectedRule, let selected_fsm = rulelist_fsm[selectedRule] {
						DisclosureGroup("FSM Info", content: {
							Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
								GridRow {
									Text("States").font(.headline).gridColumnAlignment(.trailing)
									Text(String(selected_fsm.states.count))
								}
								GridRow {
									Text("Alphabet").font(.headline).gridColumnAlignment(.trailing)
									Text(String(describing: selected_fsm.alphabet))
								}
							}
						})
						DisclosureGroup("Graphviz", content: {
							Text(selected_fsm.toViz())
								.textSelection(.enabled)
								.border(Color.gray, width: 1)
						})
					}

					Divider()

					TextField("Enter test input", text: $testInput)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.onChange(of: testInput) {
							testInputAgainstRule()
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
			} }
			.frame(minWidth: 200)
		}
		.padding()
		.onChange(of: document.content) {
			// Update rulelist when document text changes
			updateRulelist(document.content)
		}
		.onAppear {
			// Initial parse when view appears
			updateRulelist(document.content)
		}
	}

	/// Parses the grammar text into a rulelist
	private func updateRulelist(_ text: String) {
		let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
		if let (parsed, _) = ABNFRulelist<UInt32>.match(input) {
			rulelist = parsed
			rulelist_fsm = parsed.toPattern(rules: ABNFBuiltins<DFA<Array<UInt32>>>.dictionary)
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
		guard let rulelist_fsm, let selected_fsm = rulelist_fsm[selectedRule] else {
			testResult = "Rule `\(selectedRule)` is recursive or missing rules"
			return
		}

		if selected_fsm.contains(input) {
			testResult = "Accepted"
		} else {
			testResult = "Rejected"
		}
	}
}
