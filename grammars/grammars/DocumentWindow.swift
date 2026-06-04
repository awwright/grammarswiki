// TODO:
// - Auto-completion of rule names
// - Show tab of alternative forms of the document
// - Limit text field to accepted characters, use a multi-line field if \n is permitted; use \r\n for newlines when \r is permitted
// - Search feature for catalog
// - Rendered graph view
// - Selection of symbol type/preview (e.g. show decimal, hex, or glyph)

import SwiftUI
import FSM

/// The main viewer for a single grammar
struct DocumentView<Document: DocumentProtocol>: View {
	@Binding var document: Document
	// TODO: Cache computation results with <https://developer.apple.com/documentation/Foundation/NSCache>
	@State var computed: Document.Parser = .init()

	// User input
 	@State private var selectedCharsetId: String = "UTF-32"
	@State private var selectedRule: String? = nil
	@State private var testInput: String = ""

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
	@State private var regex_expanded = false
	@State private var test_expanded = false
	@State private var inspector_isPresented = true

	// minimized() is necessary here otherwise it won't return a minimized alphabetPartitions
	let builtins = ABNFBuiltins<DFA<ClosedRangeAlphabet<UInt32>>>.dictionary.mapValues { $0.minimized() };

	var body: some View {
		HStack(spacing: 20) {
			VStack(alignment: .leading) {
				TabView {
					Tab("Edit", systemImage: "pencil") {
						document.editorView(document: $document, computed: computed)
					}

					Tab("Information", systemImage: "info.circle") {
						ScrollView {
							RuleInformationView(content_rulelist: computed.asABNFRulelist, grammar: computed.selectedRule_cfg, selectedRule: selectedRule, rule_fsm: computed.selectedRule_fsm, rule_alphabet: computed.selectedRule_alphabet);
						}.frame(maxWidth: .infinity)
					}

					Tab("Translate", systemImage: "translate") {
						if let content_cfg = computed.selectedRule_cfg {
							CFGContentView(grammar: content_cfg);
						} else {
							Text("CFG is generating...")
						}
					}

					if showRegex {
						Tab("Regex", systemImage: "textformat.characters.arrow.left.and.right") {
							RegexContentView(rule_fsm: computed.selectedRule_fsm)
						}
					}

					if showExport {
						// TODO: "Copy to clipboard" button
						Tab("Export", systemImage: "rectangle.portrait.and.arrow.right") {
							ScrollView {
								FSMExportView(rule_alphabet: computed.selectedRule_alphabet, rule_fsm: computed.selectedRule_fsm)
								Spacer()
							}
						}
					}

					Tab("Graph", systemImage: "photo") {
						DFAGraphPageView(rule_fsm: computed.selectedRule_fsm)
					}

					Tab("Railroad", systemImage: "train.side.front.car") {
						ScrollView([.horizontal, .vertical]) {
							if let content_rr = computed.selectedRule_rr {
								content_rr.view
							} else {
								Text("Select a rule to view its railroad diagram")
									.foregroundColor(.gray)
							}
						}
					}

					if showInstances {
						Tab("Instances", systemImage: "printer.dotmatrix") {
							InstanceGeneratorView(rule_fsm: computed.selectedRule_fsm)
						}
					}

					if showTestInput {
						Tab("Input Testing", systemImage: "pencil") {
							ScrollView {
								InputTestingView(
									rule_alphabet: computed.selectedRule_alphabet,
									rule_fsm: computed.selectedRule_fsm,
									content_cfg: computed.selectedRule_cfg,
								)
								Spacer()
							}
						}
					}
				} //TabView
				.tabViewStyle(.automatic)
			} // VStack
			.padding()
			.inspector(isPresented: $inspector_isPresented) {
				// MARK: Inspector sidebar
				ScrollView {
					Form {
						if let filepath = document.filepath {
							LabeledContent("Path") {
								Button {
									NSWorkspace.shared.selectFile(filepath.path, inFileViewerRootedAtPath: "")
								} label: {
									Text(filepath.path)
										.lineLimit(1)
										.truncationMode(.middle)
									Image(systemName: "magnifyingglass.circle.fill")
								}
								.buttonStyle(.plain)
								.foregroundStyle(.secondary)
							}
						}

						LabeledContent("Type") {
							Text(document.type)
						}

						Picker("Starting rule", selection: $selectedRule) {
							let list = computed.topRuleNames;
							if let first = list.first {
								Section("First rule") {
									Text(first).tag(String?.some(first))
								}
							} else {
								Text("No rules defined").disabled(true)
							}
							let orphanGroup = list.isEmpty ? [] : list[1...];
							if !orphanGroup.isEmpty {
								Section("Orphan rules") {
									ForEach(orphanGroup, id: \.self) { rule in
										Text(rule).tag(String?.some(rule))
									}
								}
							}
							let subGroup = computed.allRuleNames.filter { !list.contains($0) }
							if !subGroup.isEmpty {
								Section("Sub-rules") {
									ForEach(subGroup, id: \.self) { rule in
										Text(rule).tag(String?.some(rule))
									}
								}
							}
						}
						.pickerStyle(MenuPickerStyle())

						// Specifies how to interpert the meaning of a number in the language
						// This is only used when something needs to intrepert the symbols in the context of a charset
						//	UTF-32 is preferred
						// Integer ensures they are always opaque
						// TODO: Pull this list from HomomorphismGraph<UInt32>.builtin.nodes
						Picker("Charset", selection: $selectedCharsetId) {
							ForEach(MainAppModel.charsets, id: \.id) { type in
								Text(type.label).tag(type.id)
							}
						}
						.pickerStyle(MenuPickerStyle())

						// TODO: Add an option to translate and re-interpret symbols, e.g. hex or URL encode the input string
						//document.settingsView(document: self.$document)
					}.formStyle(.grouped)

					// TODO: Add a sheet/dialog that actually transforms the language from one to another
					//Button("Convert\u{2026}", systemImage: "arrow.trianglehead.swap", action: {});

					if let err = computed.document_error {
						Text(err)
					}

					if let err = computed.selectedRule_error {
						Text(err)
					}

					if let content_rulelist = computed.asABNFRulelist {
						RuleInformationView(content_rulelist: computed.asABNFRulelist, grammar: computed.selectedRule_cfg, selectedRule: selectedRule, rule_fsm: computed.selectedRule_fsm, rule_alphabet: computed.selectedRule_alphabet);

						if let rule_fsm = computed.selectedRule_fsm {
							if showRegex {
								DisclosureGroup("Regex", isExpanded: $regex_expanded, content: {
									RegexContentView(rule_fsm: rule_fsm)
								})
							}

							Divider()

							if showTestInput {
								DisclosureGroup("Test Input", isExpanded: $test_expanded, content: {
									InputTestingView(
										rule_alphabet: computed.selectedRule_alphabet,
										rule_fsm: computed.selectedRule_fsm,
										content_cfg: computed.selectedRule_cfg,
									)
								})
							}
						} else if let rule_fsm_error = computed.selectedRule_error {
							Text(rule_fsm_error)
								.foregroundColor(.red)
						} else if computed.selectedRule_fsm != nil {
							Text("Selected rule is recursive")
								.foregroundColor(.gray)
						} else {
							Text("Building FSM...")
								.foregroundColor(.gray)
						}
					} else if let rule_fsm_error = computed.selectedRule_error {
						Text("Parse Error: \(rule_fsm_error)")
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
		.onAppear { computed.document = document; computed.selectedRulename = selectedRule; }
		.onChange(of: document.content) { computed.document = document; computed.selectedRulename = selectedRule; }
		.onChange(of: selectedRule) { computed.selectedRulename = selectedRule; }
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button {
					inspector_isPresented.toggle()
				} label: {
					Label("Inspector", systemImage: "sidebar.squares.right")
				}
			}

			// It only makes sense to show this if there's rules to select between
			if computed.topRuleNames.count > 1 {
				ToolbarItem(placement: .principal) {
					HStack(spacing: 2) {
						Image(systemName: "arrow.right")
						Picker("Rule", systemImage: "arrow.right", selection: $selectedRule) {
							ForEach(computed.topRuleNames, id: \.self) {
								Text($0).tag($0)
							}
						}.pickerStyle(.menu)
					}
				}
			}
		}
		.environment(SelectedCharset(charset: MainAppModel.charsetDict[selectedCharsetId]!))
	}
}
