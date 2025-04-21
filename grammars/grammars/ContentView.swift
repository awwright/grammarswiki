// TODO:
// - Auto-completion of rule names
// - Show tab of alternative forms of the document
// - Import rules from other documents
// - Limit text field to accepted characters, use a multi-line field if \n is permitted; use \r\n for newlines when \r is permitted
// - Search feature for catalog
// - Rendered graph view
// - Selection of symbol type/preview (e.g. show decimal, hex, or glyph)
// - Open files from any path, as a document view

import SwiftUI
import FSM
import CodeEditorView
import LanguageSupport

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
			}
		})
		.contextMenu {
			Button {} label: {Text("Show in Finder")}
			Divider()
			Button {isRenaming = true} label: {Text("Rename")}
			Button {} label: {Text("Duplicate")}
			Divider()
			Button {} label: {Text("Delete")}
		}
	}
}

struct DocumentDetail: View {
	@Binding var document: DocumentItem

	// User input
	@State private var selectedRule: String? = nil
	@State private var testInput: String = ""

	// Computed variables
	// TODO: There's probably a way to actually compute these reactive to the user input
	@State private var content_rulelist: ABNFRulelist<UInt32>? = nil
	@State private var content_rulelist_error: String? = nil

	@State private var rule_error: String? = nil
	@State private var rule_alphabet: SymbolClass<UInt32>? = nil
	@State private var rule_fsm: DFA<UInt32>? = nil
	@State private var rule_fsm_error: String? = nil
	@State private var rule_fsm_proxy: SymbolClassDFA<UInt32>? = nil // Translates the full range of input to a DFA that matches an equivalent subset
	@State private var rule_partshrink: Dictionary<UInt32, UInt32>? = nil
	@State private var rule_partexpand: Dictionary<UInt32, Array<UInt32>>? = nil

	@State private var fsm_test_result: Bool? = nil
	@State private var fsm_test_next: Array<ClosedRange<UInt32>>? = nil
	@State private var fsm_test_error: String? = nil

	@State private var fsm_iterator: DFA<UInt32>.Iterator? = nil
	@State private var fsm_iterator_result: [String] = []

	@State private var fsm_regex: SimpleRegex<UInt32>? = nil
	@State private var fsm_regex_description: String? = nil
	@State private var fsm_regex_error: String? = nil

	// Code editor variables
	@State private var position: CodeEditor.Position       = CodeEditor.Position()
	@State private var messages: Set<TextLocated<Message>> = [] // For syntax errors or annotations
	@State private var selectionLink: NSRange? = nil // For linking rule to definition
	@Environment(\.colorScheme) private var colorScheme: ColorScheme

	@AppStorage("showAlphabet") private var showAlphabet: Bool = true
	@AppStorage("showStateCount") private var showStateCount: Bool = true
	@AppStorage("showFSM") private var showFSM: Bool = true
	@AppStorage("showRegex") private var showRegex: Bool = true
	@AppStorage("showGraphViz") private var showGraphViz: Bool = true
	@AppStorage("showInstances") private var showInstances: Bool = true
	@AppStorage("showTestInput") private var showTestInput: Bool = true
	@AppStorage("regexDialect") private var regexDialect: String = RegexDialect.posix.rawValue

	@AppStorage("expandedRule") private var rule_expanded = false
	@AppStorage("expandedAlphabet") private var alphabet_expanded = false
	@State private var fsm_expanded = false
	@State private var regex_expanded = false
	@State private var instances_expanded = false

	// minimized() is necessary here otherwise it won't return a minimized alphabetPartitions
	let builtins = ABNFBuiltins<DFA<UInt32>>.dictionary.mapValues { $0.minimized() };

	var body: some View {
		HStack(spacing: 20) {
			VStack(alignment: .leading) {
				// Some views that were considered for this:
				// - Builtin TextEditor - would be sufficient except it automatically curls quotes and there's no way to disable it
				// - https://github.com/krzyzanowskim/STTextView - more like a text field, lacks code highlighting, instead wants an AttributedString, though maybe that's what I want
				// - https://github.com/CodeEditApp/CodeEditSourceEditor - This requires ten thousand different properties I don't know how to set
				// - https://github.com/mchakravarty/CodeEditorView - This one
				TabView {
					Tab("Editor", systemImage: "pencil") {
						CodeEditor(
							text: $document.content,
							position: $position,
							messages: $messages,
							language: abnfLanguageConfiguration()
						)
						.environment(\.codeEditorTheme, colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
						.frame(minHeight: 300)
						.font(.system(size: 14, design: .monospaced))
					}

					if showRegex {
						Tab("Regex", systemImage: "pencil") {
							Text("Regular Expression Conversion").font(.headline)
						}
					}

					if showGraphViz {
						// TODO: "Copy to clipboard" button
						Tab("GraphViz", systemImage: "pencil") {
							ScrollView {
								if let rule_fsm {
									let reducedAlphabetLanguage = DFA<UInt32>.union( rule_alphabet!.partitionLabels.map { DFA<UInt32>.symbol($0) } ).star();
									let expanded: DFA<String> = rule_fsm.intersection(reducedAlphabetLanguage).mapSymbols { if let cset = rule_alphabet?.siblings($0) {  describeCharacterSet(cset) } else { "Unknown symbol \($0)" } }
									Text(expanded.minimized().toViz())
										.textSelection(.enabled)
										.border(Color.gray, width: 1)
								}
							}
						}
					}

					Tab("Graph", systemImage: "pencil") {
						Text("FSM Diagram").font(.headline)
					}

					Tab("Railroad", systemImage: "pencil") {
						Text("Railroad Diagram").font(.headline)
					}

					if showInstances {
						Tab("Instances", systemImage: "pencil") {
							if let rule_fsm {
								HStack {
									Button {
										fsm_iterator_result = []
										fsm_iterator = rule_fsm.makeIterator()
										generateInstances()
									} label: { Label("Reset", systemImage: "restart") }
									Button {
										generateInstances()
									} label: { Label("More", systemImage: "arrowshape.forward") }
								}
								ScrollView {
									ForEach(fsm_iterator_result, id: \.self) { instance in
										Text(instance).border(Color.gray, width: 1).frame(maxWidth: .infinity, alignment: .leading)
									}
								}
							}
						}
					}

					if showTestInput {
						Tab("Input Testing", systemImage: "pencil") {
							TextField("Enter test input", text: $testInput)
								.textFieldStyle(RoundedBorderTextFieldStyle())
								.onChange(of: testInput) {
									updatedInput()
								}

							if let fsm_test_result {
								Text("Result: " + (fsm_test_result ? "Accepted" : fsm_test_error ?? "Rejected"))
									.foregroundColor(fsm_test_result == true ? .green : .red)
								if let fsm_test_next {
									Text("Next symbols: " + describeCharacterSet(fsm_test_next))
								} else {
									Text("Next symbols: Oblivion")
								}
							}else if let fsm_test_error {
								Text(fsm_test_error).foregroundColor(.red)
							}
							Spacer()
						}
					}
				} //TabView
			} // VStack

			VStack(alignment: .leading) {
				ScrollView {
					// First, show information true about the whole grammar file
					// If there's no rulelist, then the grammar file isn't parsed at all.

					if let content_rulelist {
						// TODO: Order this in the same order as in the grammar
						Picker("Select Starting Rule", selection: $selectedRule) {
							Text("Select a rule").tag(String?.none)
							ForEach(Array(content_rulelist.dictionary.keys.sorted()), id: \.self) { rule in
								Text(rule).tag(String?.some(rule))
							}
						}
						.pickerStyle(MenuPickerStyle())
						.onChange(of: selectedRule) { updatedRule() }
						.onAppear { updatedRule() }

						if let selectedRule {
							DisclosureGroup("Rule Information", isExpanded: $rule_expanded, content: {
								Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
									let deps = content_rulelist.dependencies(rulename: selectedRule)
									GridRow {
										Text("Dependencies").font(.headline).gridColumnAlignment(.trailing)
										Text(String(deps.dependencies.reversed().joined(separator: ", ")))
									}
									if(deps.builtins.isEmpty == false){
										GridRow {
											Text("Builtin").font(.headline).gridColumnAlignment(.trailing)
											Text(String(deps.builtins.joined(separator: ", ")))
										}
									}
									if(deps.undefined.isEmpty == false){
										GridRow {
											Text("Undefined").font(.headline).gridColumnAlignment(.trailing)
											Text(String(deps.undefined.joined(separator: ", ")))
										}
									}
									if(deps.recursive.isEmpty == false){
										GridRow {
											Text("Recursive").font(.headline).gridColumnAlignment(.trailing)
											Text(String(deps.recursive.joined(separator: ", ")))
										}
									}
								}
							})
						}

						if showAlphabet {
							DisclosureGroup("Alphabet", isExpanded: $alphabet_expanded, content: {
								if let rule_alphabet {
									ForEach(rule_alphabet.partitions, id: \.self) {
										part in
										// Text(String(describing: part)).border(Color.gray, width: 1).frame(maxWidth: .infinity, alignment: .leading)
										Text(describeCharacterSet(part)).frame(maxWidth: .infinity, alignment: .leading) //.padding(1).border(Color.gray, width: 0.5)
									}
								}else{
									Text("Computing alphabet...")
										.foregroundColor(.gray)
								}
							})
						}

						if let rule_fsm {
							if showStateCount {
								DisclosureGroup("FSM Info", isExpanded: $fsm_expanded, content: {
									Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
										GridRow {
											Text("States").font(.headline).gridColumnAlignment(.trailing)
											Text(String(rule_fsm.states.count))
										}
									}
								})
							}

							if showRegex {
								DisclosureGroup("Regex", isExpanded: $regex_expanded, content: {
									if let fsm_regex_description {
										Text(fsm_regex_description)
											.textSelection(.enabled)
											.border(Color.gray, width: 1)
									} else if let fsm_regex_error {
										Text("Error: \(fsm_regex_error)")
											.foregroundColor(.red)
									} else {
										Text("Building...")
											.foregroundColor(.gray)
									}
								})
								.onChange(of: rule_fsm) { updatedFSM() }
								.onAppear { updatedFSM() }
							}

							if showGraphViz {
								// TODO: "Copy to clipboard" button
								DisclosureGroup("Graphviz", content: {
									let reducedAlphabetLanguage = DFA<UInt32>.union( rule_alphabet!.partitionLabels.map { DFA<UInt32>.symbol($0) } ).star();
									let expanded: DFA<String> = rule_fsm.intersection(reducedAlphabetLanguage).mapSymbols { if let cset = rule_alphabet?.siblings($0) {  describeCharacterSet(cset) } else { "Unknown symbol \($0)" } }
									Text(expanded.minimized().toViz())
										.textSelection(.enabled)
										.border(Color.gray, width: 1)
								})
							}

							if showInstances {
								DisclosureGroup("Instances", isExpanded: $instances_expanded, content: {
									ForEach(fsm_iterator_result, id: \.self) { instance in
										Text(instance).border(Color.gray, width: 1).frame(maxWidth: .infinity, alignment: .leading)
									}

									HStack {
										Button {
											fsm_iterator_result = []
											fsm_iterator = rule_fsm.makeIterator()
											generateInstances()
										} label: { Label("Reset", systemImage: "restart") }
										Button {
											generateInstances()
										} label: { Label("More", systemImage: "arrowshape.forward") }
									}
								})
							}

							Divider()

							if showTestInput {
								TextField("Enter test input", text: $testInput)
									.textFieldStyle(RoundedBorderTextFieldStyle())
									.onChange(of: testInput) {
										updatedInput()
									}

								if let fsm_test_result {
									Text("Result: " + (fsm_test_result ? "Accepted" : fsm_test_error ?? "Rejected"))
										.foregroundColor(fsm_test_result == true ? .green : .red)
									if let fsm_test_next {
										Text("Next symbols: " + describeCharacterSet(fsm_test_next))
									} else {
										Text("Next symbols: Oblivion")
									}
								}else if let fsm_test_error {
									Text(fsm_test_error).foregroundColor(.red)
								}
							}
						} else if let rule_fsm_error {
							Text(rule_fsm_error)
								.foregroundColor(.red)
						} else if rule_fsm != nil {
							Text("Selected rule is recursive")
								.foregroundColor(.gray)
						} else {
							Text("Building FSM...")
								.foregroundColor(.gray)
						}
					} else if let content_rulelist_error {
						Text("Parse Error: \(content_rulelist_error)")
							.foregroundColor(.red)
					} else {
						Text("Parsing...")
							.foregroundColor(.gray)
					}
					Spacer()
				}
			}
			.frame(minWidth: 200)
		} // HStack
		.padding()
		.onChange(of: document.content) { updatedDocument() }
		.onAppear { updatedDocument() }
	}

	/// Parses the grammar text into a rulelist
	private func updatedDocument() {
		let text = document.content;
		content_rulelist = nil
		content_rulelist_error = nil
		// invalidate updatedRule
		rule_alphabet = nil
		rule_partshrink = nil
		rule_fsm = nil
		rule_fsm_error = nil
		// invalidate updatedFSM
		fsm_regex = nil
		fsm_regex_error = nil
		// invalidate updatedInput
		fsm_test_result = nil
		fsm_test_error = nil
		fsm_test_next = nil
		fsm_iterator = nil
		fsm_iterator_result = []

		let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
		Task.detached(priority: .utility) {
			let result: ABNFRulelist<UInt32>;
			do {
				result = try ABNFRulelist<UInt32>.parse(input)
				await MainActor.run {
					content_rulelist = result
					// Select the first rule by default
					if selectedRule == nil, let firstRule = content_rulelist?.rules.first {
						selectedRule = firstRule.rulename.label
					} else if let s = selectedRule, let content_rulelist, content_rulelist.dictionary[s] == nil, let firstRule = content_rulelist.rules.first {
						selectedRule = firstRule.rulename.label
					}
				}
			} catch let error as ABNFParseError<Array<UInt32>.Index> {
				await MainActor.run {
					content_rulelist = nil
					content_rulelist_error = "Error at index: " + String(describing: error.index)
					rule_alphabet = nil
					rule_partshrink = nil
					fsm_test_result = nil
					let line = input[0...error.index.startIndex].count(where: { $0 == 0xA })
					messages = Set([
						TextLocated(location: TextLocation(zeroBasedLine: line, column: 0), entity: Message(category: .error, length: 2, summary: "Syntax Error", description: nil))
					])
				}
			} catch {
				await MainActor.run {
					content_rulelist = nil
					content_rulelist_error = "Unknown error: " + error.localizedDescription
					rule_fsm = nil
					rule_fsm_error = nil
					fsm_test_result = nil
				}
			}
		}
	}

	/// Render the FSM
	private func updatedRule() {
		rule_alphabet = nil
		rule_partshrink = nil
		rule_fsm = nil
		rule_fsm_error = nil
		// invalidate updatedFSM
		fsm_regex = nil
		fsm_regex_error = nil
		// invalidate updatedInput
		fsm_test_result = nil
		fsm_test_error = nil
		fsm_test_next = nil
		fsm_iterator = nil
		fsm_iterator_result = []

		guard let content_rulelist, let selectedRule else {
			rule_fsm_error = "No rule selected"
			return
		}

		let dependencies_list = content_rulelist.dependencies(rulename: selectedRule);
		let dict = content_rulelist.dictionary;
		let dependencies = dependencies_list.dependencies.compactMap { if let rule = dict[$0] { ($0, rule) } else { nil } }
		if(dependencies.isEmpty){ rule_fsm_error = "dependencies is empty"; return }
		if(dependencies_list.recursive.isEmpty == false){ rule_fsm_error = "Rule is recursive"; return }

		// Compute alphabets
		Task.detached(priority: .utility) {
			let result_alphabet = reduce(definitions: dependencies, initial: builtins.mapValues({ $0.toPattern(as: SymbolClass<UInt32>.self) }), combine: { $0.alphabetPartitions(rulelist: $1) })
			await MainActor.run {
				rule_alphabet = result_alphabet
				rule_partshrink = result_alphabet.alphabetReduce
				let reducedAlphabet = Set(result_alphabet.partitionLabels)

				// Compute DFA
				Task.detached(priority: .utility) {
					func reduce<S, T>(definitions: Array<(String, S)>, initial: Dictionary<String, T>, combine: (S, Dictionary<String, T>) throws -> T) rethrows -> T {
						var current = initial;
						var last: T?
						for (rulename, definition) in definitions {
							last = try combine(definition, current)
							current[rulename] = last
						}
						return last!
					}
					do {
						// Cut the builtins down to match the reducedAlphabet... let's see if this works
						let reducedAlphabetLanguage = DFA<UInt32>.union( reducedAlphabet.map { DFA<UInt32>.symbol($0) } ).star().minimized();
						print(reducedAlphabetLanguage.toViz())
						let reducedBuiltins = builtins.mapValues { $0.intersection(reducedAlphabetLanguage).minimized() }
						let result = try reduce(definitions: dependencies, initial: reducedBuiltins, combine: { try $0.toPattern(rules: $1, alphabet: reducedAlphabet).minimized() })
						await MainActor.run {
							rule_fsm = result
							rule_fsm_proxy = SymbolClassDFA(inner: result, mapping: rule_partshrink!)
							rule_fsm_error = nil
						}
					} catch let error as ABNFExportError {
						print(error)
						await MainActor.run {
							rule_fsm = nil
							rule_fsm_error = "ABNFExportError: " + String(describing: error)
						}
					} catch {
						await MainActor.run {
							rule_fsm = nil
							rule_fsm_error = error.localizedDescription
						}
					}
				}
			}
		}
	}

	private func updatedFSM() {
		fsm_regex = nil
		fsm_regex_error = nil
		// invalidate updatedInput
		fsm_test_result = nil
		fsm_test_error = nil
		fsm_test_next = nil
		fsm_iterator = nil
		fsm_iterator_result = []

		guard let rule_fsm else {
			return
		}

		// Compute regex
		Task.detached(priority: .utility) {
			let result: SimpleRegex<UInt32> = rule_fsm.toPattern()
			let description = result.description
			await MainActor.run {
				fsm_regex = result
				fsm_regex_description = description
				fsm_regex_error = nil
			}
		}
	}

	private func generateInstances() {
		if fsm_iterator != nil {
			for _ in 0..<1000 {
				let value: Array<UInt32>? = fsm_iterator!.next()
				if let value {
					fsm_iterator_result.append(String(decoding: value, as: Unicode.UTF32.self))
				} else {
					break
				}
			}
		}
	}

	/// Tests the input against the selected rule
	private func updatedInput() {
		fsm_test_result = nil
		fsm_test_error = nil
		fsm_test_next = nil

		guard let content_rulelist,
				let selectedRule,
				content_rulelist.dictionary[selectedRule] != nil
		else {
			fsm_test_error = "Invalid selection"
			return
		}
		let input = Array(testInput.unicodeScalars.map(\.value))
		guard let selected_fsm = rule_fsm_proxy else {
			fsm_test_error = "Rule `\(selectedRule)` is recursive or missing rules"
			return
		}

		let fsm_test_state = selected_fsm.nextState(state: selected_fsm.initial, input: input)
		fsm_test_result = selected_fsm.isFinal(fsm_test_state);
		if let fsm_test_state {
			fsm_test_next = selected_fsm.states[fsm_test_state].keys.flatMap { rule_alphabet!.siblings($0) }
		}
		if fsm_test_result == false {
			if fsm_test_state != nil {
				fsm_test_error = "unexpected EOF"
			} else {
				fsm_test_error = "oblivion"
			}
		}
	}

	// Simplified ABNF language configuration
	private func abnfLanguageConfiguration() -> LanguageConfiguration {
		LanguageConfiguration(
			name: "ABNF",
			supportsSquareBrackets: true,
			supportsCurlyBrackets: false,
			stringRegex: try! Regex("\"[^\"]*\"|<[^>]*>"),
			characterRegex: try! Regex("%[bdxBDX][0-9A-Fa-f]+(?:-[0-9A-Fa-f]+|(?:\\.[0-9A-Fa-f]+)*)"),
			numberRegex: try! Regex("[1-9][0-9]*"),
			singleLineComment: ";",
			nestedComment: nil,
			identifierRegex: try! Regex("[0-9A-Za-z-]+"),
			operatorRegex: try! Regex("/|\\*|=|=/"),
			reservedIdentifiers: [],
			reservedOperators: []
		)
	}
}

// Build a number of rules in a certain order, later rules possibly depending on results from earlier on
func reduce<S, T>(definitions: Array<(String, S)>, initial: Dictionary<String, T>, combine: (S, Dictionary<String, T>) throws -> T) rethrows -> T {
	var current = initial;
	var last: T?
	for (rulename, definition) in definitions {
		last = try combine(definition, current)
		current[rulename] = last
	}
	return last!
}

func describeCharacterSet(_ rangeSet: Array<ClosedRange<UInt32>>) -> String {
	// Handle empty set case
	guard !rangeSet.isEmpty else { return "∅" }

	// Convert set to array and sort by lower bound
	let sortedRanges = rangeSet.sorted { $0.lowerBound < $1.lowerBound }

	// Initialize result with the first range
	var merged: [ClosedRange<UInt32>] = [sortedRanges[0]]

	// Iterate through remaining ranges
	for current in sortedRanges.dropFirst() {
		let last = merged.last!

		// Check if current range is adjacent to or overlaps with the last merged range
		if current.lowerBound <= last.upperBound + 1 && ((0x30...0x39).contains(current.lowerBound) || (0x41...0x5A).contains(current.lowerBound) || (0x61...0x7A).contains(current.lowerBound) || current.lowerBound > 0x7F) && ((0x30...0x39).contains(last.lowerBound) || (0x41...0x5A).contains(last.lowerBound) || (0x61...0x7A).contains(last.lowerBound) || last.lowerBound > 0x7F) {
			// Merge by creating a new range with the same lower bound and the maximum upper bound
			let newUpper = max(last.upperBound, current.upperBound)
			merged[merged.count - 1] = last.lowerBound...newUpper
		} else {
			// If not adjacent or overlapping, add the current range as a new segment
			merged.append(current)
		}
	}

	return merged
		.map { getPrintable($0.lowerBound) + ($0.lowerBound==$0.upperBound ? "" : ("⋯" + getPrintable($0.upperBound)) ) }
		.joined(separator: "\u{2001}")
}

func getPrintable(_ char: UInt32) -> String {
	if(char < 0x21) {
		String(UnicodeScalar(0x2400 + char)!)
	} else if (char >= 0x21 && char <= 0x7E) {
		String(UnicodeScalar(char)!)
	} else {
		"U+\(String(format: "%04X", Int(char)))"
	}
}
