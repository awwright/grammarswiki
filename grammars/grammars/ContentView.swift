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
	@State private var rule_alphabet: ClosedRangeAlphabet<UInt32>? = nil
	@State private var rule_fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>? = nil
	@State private var rule_fsm_error: String? = nil

	// Code editor variables
	@State private var position: CodeEditor.Position       = CodeEditor.Position()
	@State private var messages: Set<TextLocated<Message>> = [] // For syntax errors or annotations
	@State private var selectionLink: NSRange? = nil // For linking rule to definition
	@Environment(\.colorScheme) private var colorScheme: ColorScheme

	@AppStorage("showAlphabet") private var showAlphabet: Bool = true
	@AppStorage("showStateCount") private var showStateCount: Bool = true
	@AppStorage("showFSM") private var showFSM: Bool = true
	@AppStorage("showRegex") private var showRegex: Bool = true
	@AppStorage("showExport") private var showExport: Bool = true
	@AppStorage("showInstances") private var showInstances: Bool = true
	@AppStorage("showTestInput") private var showTestInput: Bool = true
	@AppStorage("regexDialect") private var regexDialect: String = RegexDialect.posix.rawValue

	@AppStorage("expandedRule_deps") private var rule_deps_expanded = true
	@AppStorage("expandedRule_builtin") private var rule_builtin_expanded = true
	@AppStorage("expandedRule_undefined") private var rule_undefined_expanded = true
	@AppStorage("expandedRule_recursive") private var rule_recursive_expanded = true
	@AppStorage("expandedAlphabet") private var alphabet_expanded = true
	@State private var fsm_expanded = false
	@State private var regex_expanded = false
	@State private var test_expanded = false
	@State private var inspector_isPresented = true

	// minimized() is necessary here otherwise it won't return a minimized alphabetPartitions
	let builtins = ABNFBuiltins<SymbolClassDFA<ClosedRangeAlphabet<UInt32>>>.dictionary.mapValues { $0.minimized() };

	var body: some View {
		HStack(spacing: 20) {
			VStack(alignment: .leading) {
				TabView {
					Tab("Editor", systemImage: "pencil") {
						// Some views that were considered for this:
						// - Builtin TextEditor - would be sufficient except it automatically curls quotes and there's no way to disable it
						// - https://github.com/krzyzanowskim/STTextView - more like a text field, lacks code highlighting, instead wants an AttributedString, though maybe that's what I want
						// - https://github.com/CodeEditApp/CodeEditSourceEditor - This requires ten thousand different properties I don't know how to set
						// - https://github.com/mchakravarty/CodeEditorView - This one
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
							RegexContentView(rule_fsm: $rule_fsm)
						}
					}

					if showExport {
						// TODO: "Copy to clipboard" button
						Tab("FSM", systemImage: "pencil") {
							ScrollView {
								FSMExportView(rule_alphabet: $rule_alphabet, rule_fsm: $rule_fsm)
								Spacer()
							}
						}
					}

					Tab("Graph", systemImage: "pencil") {
						DFAGraphView(rule_fsm: $rule_fsm)
					}

					Tab("Railroad", systemImage: "pencil") {
						Text("Railroad Diagram").font(.headline)
					}

					if showInstances {
						Tab("Instances", systemImage: "pencil") {
							InstanceGeneratorView(rule_fsm: $rule_fsm)
						}
					}

					if showTestInput {
						Tab("Input Testing", systemImage: "pencil") {
							ScrollView {
								InputTestingView(
									content_rulelist: $content_rulelist,
									selectedRule: $selectedRule,
									rule_alphabet: $rule_alphabet,
									rule_fsm: $rule_fsm
								)
								Spacer()
							}
						}
					}
				} //TabView
			} // VStack
			.padding()
			.inspector(isPresented: $inspector_isPresented) {
				ScrollView {
					// First, show information true about the whole grammar file
					// If there's no rulelist, then the grammar file isn't parsed at all.

					if let content_rulelist {
						// TODO: Order this in the same order as in the grammar
						let (orphanGroup, subGroup) = computeGroupedRules(for: content_rulelist)
						Picker("Select Starting Rule", selection: $selectedRule) {
							Text("Select a rule").tag(String?.none)
							if !orphanGroup.isEmpty {
								Section("Orphan Rules") {
									ForEach(orphanGroup, id: \.self) { rule in
										Text(rule).tag(String?.some(rule))
									}
								}
							}
							if !subGroup.isEmpty {
								Section("Sub-rules") {
									ForEach(subGroup, id: \.self) { rule in
										Text(rule).tag(String?.some(rule))
									}
								}
							}
						}
						.pickerStyle(MenuPickerStyle())

						if let selectedRule {
							let deps = content_rulelist.dependencies(rulename: selectedRule)
							DisclosureGroup("Rule Dependencies", isExpanded: $rule_deps_expanded, content: {
								Text(String(deps.dependencies.reversed().joined(separator: ", ")))
							})
							if(deps.builtins.isEmpty == false){
								DisclosureGroup("Implicit Builtins", isExpanded: $rule_builtin_expanded, content: {
									Text(String(deps.builtins.joined(separator: ", ")))
								})
							}
							if(deps.undefined.isEmpty == false){
								DisclosureGroup("Undefined Rules", isExpanded: $rule_undefined_expanded, content: {
									Text(String(deps.undefined.joined(separator: ", ")))
								})
							}
							if(deps.recursive.isEmpty == false){
								DisclosureGroup("Recursive Rules", isExpanded: $rule_recursive_expanded, content: {
									Text(String(deps.recursive.joined(separator: ", ")))
								})
							}
						}

						if showAlphabet {
							DisclosureGroup("Alphabet", isExpanded: $alphabet_expanded, content: {
								if let rule_alphabet: ClosedRangeAlphabet<UInt32> = rule_alphabet {
									let rule_alphabet_sorted: [ClosedRangeAlphabet<UInt32>.SymbolClass] = Array(rule_alphabet)
									ForEach(rule_alphabet_sorted, id: \.self) {
										(part: ClosedRangeAlphabet<UInt32>.SymbolClass) in
										// TODO: Convert to a String
										//Text(describeCharacterSet(part)).frame(maxWidth: .infinity, alignment: .leading).padding(1).border(Color.gray, width: 0.5)
										Text(String(describing: part)).frame(maxWidth: .infinity, alignment: .leading).padding(1).border(Color.gray, width: 0.5)
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
									RegexContentView(rule_fsm: $rule_fsm)
								})
							}

							Divider()

							if showTestInput {
								DisclosureGroup("Test Input", isExpanded: $test_expanded, content: {
									InputTestingView(
										content_rulelist: $content_rulelist,
										selectedRule: $selectedRule,
										rule_alphabet: $rule_alphabet,
										rule_fsm: $rule_fsm
									)
								})
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
				} // ScrollView
				.padding()
				.inspectorColumnWidth(min: 300, ideal: 500, max: 2000)
			}
		} // HStack
		.onChange(of: document.content) { updatedDocument() }
		.onChange(of: selectedRule) { updatedRule() }
		.onAppear { updatedDocument(); updatedRule() }
		.toolbar {
			Button {
				inspector_isPresented.toggle()
			} label: {
				Label("Inspector", systemImage: "sidebar.squares.right")
			}
		}
	}

	/// Parses the grammar text into a rulelist
	private func updatedDocument() {
		let text = document.content;
		content_rulelist = nil
		content_rulelist_error = nil
		// invalidate updatedRule
		rule_alphabet = nil
		rule_fsm = nil
		rule_fsm_error = nil
		guard let bundlePath = Bundle.main.resourcePath else { return }
		let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
		Task.detached(priority: .utility) {
			do {
				let root_parsed = try! ABNFRulelist<UInt32>.parse(input)
				let rulelist_all_final = try dereferenceABNFRulelist(root_parsed, {
					filename in
					let filePath = bundlePath + "/catalog/" + filename
					let content = try String(contentsOfFile: filePath, encoding: .utf8)
					return try ABNFRulelist<UInt32>.parse(content.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
				});
				await MainActor.run {
					content_rulelist = rulelist_all_final
					// Select the first rule by default
					if selectedRule == nil, let firstRule = content_rulelist?.rules.first {
						selectedRule = firstRule.rulename.label
					} else if let s = selectedRule, let content_rulelist, content_rulelist.dictionary[s] == nil, let firstRule = content_rulelist.rules.first {
						selectedRule = firstRule.rulename.label
					}
					messages = [];
				}
			} catch let error as ABNFParseError<Array<UInt32>.Index> {
				await MainActor.run {
					content_rulelist = nil
					content_rulelist_error = "Error at index: " + String(describing: error.index)
					rule_alphabet = nil
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
				}
			}
		}
	}

	/// Render the FSM
	private func updatedRule() {
		rule_alphabet = nil
		rule_fsm = nil
		rule_fsm_error = nil

		guard let content_rulelist, let selectedRule else {
			rule_fsm_error = "No rule selected"
			return
		}

		// Compute alphabets
		Task.detached(priority: .utility) {
			let dependencies_list = content_rulelist.dependencies(rulename: selectedRule);
			let dict = content_rulelist.dictionary;
			let dependencies = dependencies_list.dependencies.compactMap { if let rule = dict[$0] { ($0, rule) } else { nil } }
			if(dependencies.isEmpty){
				await MainActor.run { rule_fsm_error = "dependencies is empty"; }
				return
			}
			if(dependencies_list.recursive.isEmpty == false){
				await MainActor.run { rule_fsm_error = "Rule is recursive"; }
				return
			}
			do {
				var result_fsm_dict = builtins.mapValues { $0.minimized() }
				for (rulename, definition) in dependencies {
					let pat = try definition.toClosedRangePattern(rules: result_fsm_dict);
					result_fsm_dict[rulename] = pat.minimized()
				}
				let result = result_fsm_dict[selectedRule]!
				let result_alphabet = result.alphabet

				await MainActor.run {
					rule_fsm = result
					rule_fsm_error = nil
					rule_alphabet = result_alphabet
				}
			} catch let error as ABNFExportError {
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

	private func computeGroupedRules(for rulelist: ABNFRulelist<UInt32>) -> (orphanGroup: [String], subGroup: [String]) {
		let orderedRules = rulelist.ruleNames
		guard !orderedRules.isEmpty else { return ([], []) }

		let allReferenced = rulelist.referencedRules
		let orphans = orderedRules.filter { !allReferenced.contains($0) }

		let first = orderedRules[0]
		var orphanGroup: [String] = [first]

		for orphan in orphans {
			if orphan != first {
				orphanGroup.append(orphan)
			}
		}

		let subGroup = orderedRules.filter { !orphanGroup.contains($0) }

		return (orphanGroup, subGroup)
	}
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
