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

	// User input
 	@State private var selectedCharsetId: String = "UTF-32"
	@State private var selectedRule: String? = nil
	@State private var testInput: String = ""

	// Computed variables
	// TODO: There's probably a way to actually compute these reactive to the user input
	// TODO: Cache computation results with <https://developer.apple.com/documentation/Foundation/NSCache>
	@State private var content_rulelist: ABNFRulelist<UInt32>? = nil
	@State private var content_rulelist_error: String? = nil
	@State private var content_parseErrorLine: Int? = nil

	@State private var content_cfg: ABNFRulelist<UInt32>.CFG? = nil;
	@State private var content_cfg_err: String? = nil;
	@State private var content_rr: RailroadNode? = nil

	@State private var content_cfg_complexityClass: Int? = nil
	@State private var content_cfg_chomskyClass: Int? = nil
	@State private var content_cfg_memoryRequirements: Int? = nil

	@State private var rule_error: String? = nil
	@State private var rule_alphabet: ClosedRangeAlphabet<UInt32>? = nil
	@State private var rule_fsm: DFA<ClosedRangeAlphabet<UInt32>>? = nil
	@State private var rule_fsm_error: String? = nil

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
						document.editorView(document: $document, parseErrorLine: $content_parseErrorLine)
					}

					Tab("Information", systemImage: "info.circle") {
						ScrollView {
							RuleInformationView(content_rulelist: content_rulelist, grammar: content_cfg, selectedRule: selectedRule, rule_fsm: rule_fsm, rule_alphabet: rule_alphabet);
						}.frame(maxWidth: .infinity)
					}

					Tab("Translate", systemImage: "translate") {
						if let content_cfg {
							CFGContentView(grammar: content_cfg);
						} else if let content_cfg_err {
							Text(content_cfg_err)
						} else {
							Text("CFG is generating...")
						}
					}

					if showRegex {
						Tab("Regex", systemImage: "textformat.characters.arrow.left.and.right") {
							RegexContentView(rule_fsm: $rule_fsm, rulelist_fsm: content_rulelist?.ruleNames)
						}
					}

					if showExport {
						// TODO: "Copy to clipboard" button
						Tab("Export", systemImage: "rectangle.portrait.and.arrow.right") {
							ScrollView {
								FSMExportView(rule_alphabet: $rule_alphabet, rule_fsm: $rule_fsm)
								Spacer()
							}
						}
					}

					Tab("Graph", systemImage: "photo") {
						DFAGraphPageView(rule_fsm: $rule_fsm)
					}

					Tab("Railroad", systemImage: "train.side.front.car") {
						ScrollView([.horizontal, .vertical]) {
							if let content_rr {
								content_rr.view
							} else {
								Text("Select a rule to view its railroad diagram")
									.foregroundColor(.gray)
							}
						}
					}

					if showInstances {
						Tab("Instances", systemImage: "printer.dotmatrix") {
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
									rule_fsm: $rule_fsm,
									content_cfg: $content_cfg,
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
							if let content_rulelist {
								let list = document.topRuleNames;
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
								let subGroup = document.allRuleNames.filter { !list.contains($0) }
								if !subGroup.isEmpty {
									Section("Sub-rules") {
										ForEach(subGroup, id: \.self) { rule in
											Text(rule).tag(String?.some(rule))
										}
									}
								}
							}
						}
						.pickerStyle(MenuPickerStyle())

						// Specifies how to interpert the meaning of a number in the language
						// This is only used when something needs to intrepert the symbols in the context of a charset
						//	UTF-32 is preferred
						// Integer ensures they are always opaque
						//
						Picker("Charset", selection: $selectedCharsetId) {
							ForEach(MainAppModel.charsets, id: \.id) { type in
								Text(type.label).tag(type.id)
							}
						}
						.pickerStyle(MenuPickerStyle())

						// TODO: Add an option to translate and re-interpret symbols, e.g. hex or URL encode the input string
					}.formStyle(.grouped)

					// TODO: Add a sheet/dialog that actually transforms the language from one to another
					//Button("Convert\u{2026}", systemImage: "arrow.trianglehead.swap", action: {});

					if let content_rulelist {
						RuleInformationView(content_rulelist: content_rulelist, grammar: content_cfg, selectedRule: selectedRule, rule_fsm: rule_fsm, rule_alphabet: rule_alphabet);

						if rule_fsm != nil {
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
										rule_fsm: $rule_fsm,
										content_cfg: $content_cfg,
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
		.onChange(of: selectedRule) { updatedRule(); updatedDocument() }
		.onChange(of: selectedCharsetId) { document.charset = selectedCharsetId; }
		.onChange(of: document.id) { switchDocument(); }
		.onChange(of: content_cfg) { updatedCFG(); }
		.onAppear { switchDocument(); }
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button {
					inspector_isPresented.toggle()
				} label: {
					Label("Inspector", systemImage: "sidebar.squares.right")
				}
			}

			ToolbarItem(placement: .principal) {
				HStack(spacing: 8) {
					Picker("Rule", systemImage: "arrow.left", selection: $selectedRule) {
						ForEach(document.topRuleNames, id: \.self) {
							Text($0).tag($0)
						}
					}.pickerStyle(.menu)
				}
			}
		}
		.environment(SelectedCharset(charset: MainAppModel.charsetDict[selectedCharsetId]!))
	}

	/// Parses the grammar text into a rulelist
	private func switchDocument() {
		selectedCharsetId = document.charset;
		updatedDocument();
		updatedRule();
	}

	/// Parses the grammar text into a rulelist
	private func updatedDocument() {
		let text = document.content;
		content_rulelist = nil
		content_rulelist_error = nil
		content_cfg = nil
		content_cfg_err = nil;
		// invalidate updatedRule
		rule_alphabet = nil
		rule_fsm = nil
		rule_fsm_error = nil
		guard let bundlePath = Bundle.main.resourcePath else { return }
		Task.detached(priority: .utility) {
			let catalog = Catalog(root: bundlePath + "/catalog/")
			await MainActor.run {
				do {
					let rulelist_all_final = try document.toABNFRulelist();
					content_rulelist = rulelist_all_final.addingBuiltins();
					if let selectedRule, let content_rulelist {
						content_cfg = try content_rulelist.toCFG(rulename: selectedRule)
					} else {
						content_cfg = .init()
					}
					content_rr = rulelist_all_final.dictionary[selectedRule ?? ""]?.toRailroad(rules: content_rulelist!.dictionary.mapValues { $0.alternation })
				} catch {
					if let err = error as? ABNFExportError {
						content_cfg_err = err.message;
					} else {
						content_cfg_err = error.localizedDescription;
					}
					content_cfg = nil
				}
				// Select the first rule by default
				if selectedRule == nil, let firstRule = content_rulelist?.rules.first {
					selectedRule = firstRule.rulename.id
				} else if let s = selectedRule, let content_rulelist, content_rulelist.dictionary[s] == nil, let firstRule = content_rulelist.rules.first {
					selectedRule = firstRule.rulename.id
				}
				content_parseErrorLine = nil;
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
					let pat = try definition.toPattern(rules: result_fsm_dict);
					result_fsm_dict[rulename] = pat.minimized()
				}
				let result = result_fsm_dict[selectedRule]!
				let result_alphabet = result.alphabet

				await MainActor.run {
					rule_fsm = result.normalized()
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

	private func updatedCFG() {
		guard let content_cfg else { return }
		content_cfg_chomskyClass = content_cfg.chomskyClass();
		content_cfg_memoryRequirements = content_cfg.memoryRequirements();
	}
}
