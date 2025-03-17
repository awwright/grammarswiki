// TODO:
// - Replace text editor with a real code editor
// - Parsing errors, show the unexpected character and the permitted characters for that position
// - Auto-completion of rule names
// - Import rules from other documents
// - Limit text field to accepted characters, use a multi-line field if \n is permitted; use \r\n for newlines when \r is permitted
// - Search feature for catalog
// - Rendered graph view
// - Selection of symbol type/preview (e.g. show decimal, hex, or glyph)
// - Open files from any path, as a document view

import SwiftUI
import FSM

struct ContentView: View {
	@Binding var model: AppModel
	@State private var selection: DocumentItem? = nil

	var body: some View {
		NavigationSplitView {
			List(selection: $selection) {
				Section("Saved") {
					ForEach(Array(model.user.values), id: \.self) {
						document in
						DocumentItemView(document: Binding(get: { document }, set: { model.addDocument($0) }))
					}
				}
				Section("Catalog") {
					ForEach(model.catalog, id: \.self) {
						document in
						DocumentItemView(document: Binding(get: { document }, set: { model.addDocument($0) }))
					}
				}
			}
			.navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 600)
			.toolbar {
				ToolbarItem {
					Button(action: addDocument) {
						Label("Add", systemImage: "plus")
					}
				}
			}
		} detail: {
			// FIXME: This technique mangles the undo stack when you switch documents. I don't know how to fix this.
			if let selectedDocument = selection {
				let binding: Binding<DocumentItem> = model.catalog.contains(selectedDocument) ?
					Binding(
						get: { selectedDocument },
						set: {
							// Attemting to set on this document makes a copy
							let newDocument = DocumentItem(
								name: "\($0.name) copy",
								content: $0.content
							)
							model.addDocument(newDocument)
							selection = newDocument
						}
					) : Binding(
						get: { model.user[selectedDocument.id]! },
						set: { model.addDocument($0) }
					);
				DocumentDetail(document: binding)
					.navigationTitle(selectedDocument.name)
			} else {
				Text("Select a document")
			}
		}
	}

	func addDocument(){
		withAnimation {
			let newDocument = DocumentItem(
				name: "New Document \(model.user.count + 1)",
				content: ""
			)
			model.addDocument(newDocument)
			selection = newDocument
		}
	}
}

struct DocumentItemView: View {
	@Binding var document: DocumentItem
	@State private var isRenaming: Bool = false
	@State private var draftName: String = ""
	var body: some View {
		NavigationLink(value: document, label: {
			if isRenaming {
				TextField("Name", text: $draftName, onCommit: {
					document.name = draftName
					isRenaming = false
				})
			} else {
				Text(document.name)
					.onTapGesture {
						draftName = document.name // Initialize with current name
						isRenaming = true
					}
			}
		})
	}
}

struct DocumentDetail: View {
	@Binding var document: DocumentItem

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

						Divider()

						TextField("Enter test input", text: $testInput)
							.textFieldStyle(RoundedBorderTextFieldStyle())
							.onChange(of: testInput) {
								testInputAgainstRule()
							}
					}

					if let testResult {
						Text("Result: \(testResult)")
							.foregroundColor(testResult == "Accepted" ? .green : .red)
					}
				} else {
					Text("No valid grammar loaded")
						.foregroundColor(.gray)

					Divider()
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
		rulelist = nil
		rulelist_fsm = nil
		parseError = "Parsing..."
		selectedRule = nil
		testResult = nil
		let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
		Task.detached(priority: .background) {
			if let (parsed, _) = ABNFRulelist<UInt32>.match(input) {
				await MainActor.run {
					rulelist = parsed
					Task.detached(priority: .background) {
						let parsed_rulelist_fsm = parsed.toPattern(rules: ABNFBuiltins<DFA<Array<UInt32>>>.dictionary)
						await MainActor.run {
							rulelist_fsm = parsed_rulelist_fsm
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
						}
					}
				}
			} else {
				await MainActor.run {
					rulelist = nil
					rulelist_fsm = nil
					parseError = "Failed to parse grammar"
					selectedRule = nil
					testResult = nil
				}
			}
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
