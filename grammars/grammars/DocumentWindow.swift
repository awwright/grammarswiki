// TODO:
// - Limit text field to accepted characters, use a multi-line field if \n is permitted; use \r\n for newlines when \r is permitted
// - Search feature for catalog
// - Selection of symbol type/preview (e.g. show decimal, hex, or glyph)

import SwiftUI
import FSM

/// Full-window mode of a document: the editor, or one compiled projection of the selected rule.
enum DocumentPane: String, CaseIterable, Identifiable {
	case edit, cfg, regex, fsm, graph, railroad, instances, test
	var id: Self { self }

	var title: String {
		switch self {
		case .edit: "Edit"
		case .cfg: "CFG"
		case .regex: "Regex"
		case .fsm: "FSM"
		case .graph: "Graph"
		case .railroad: "Railroad"
		case .instances: "Instances"
		case .test: "Input Testing"
		}
	}

	var systemImage: String {
		switch self {
		case .edit: "pencil"
		case .cfg: "translate"
		case .regex: "textformat.characters.arrow.left.and.right"
		case .fsm: "rectangle.portrait.and.arrow.right"
		case .graph: "flowchart"
		case .railroad: "train.side.front.car"
		case .instances: "bolt.fill" // Consider list.bullet.badge.ellipsis on macOS 26+
		case .test: "text.cursor"
		}
	}
}

/// The main viewer for a single grammar
struct DocumentView<Document: DocumentProtocol>: View {
	@Binding var document: Document
	// TODO: Cache computation results with <https://developer.apple.com/documentation/Foundation/NSCache>
	@State var computed = RulelistAnalysis()
	@State var rule = RuleAnalysis()

	// User input
 	@State private var selectedCharsetId: String = "UTF-32"
	// TODO: Keep a list of last-used selected rule names and work down the list if the previous rule becomes unavailable e.g. due to user editing
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
	@State private var pane: DocumentPane = .edit
	@State private var inspector_isPresented = false

	// minimized() is necessary here otherwise it won't return a minimized alphabetPartitions
	let builtins = ABNFBuiltins<DFA<ClosedRangeAlphabet<UInt32>>>.dictionary.mapValues { $0.minimized() };

	private var availablePanes: [DocumentPane] {
		DocumentPane.allCases.filter { pane in
			switch pane {
			case .regex: showRegex
			case .fsm: showExport
			case .instances: showInstances
			case .test: showTestInput
			default: true
			}
		}
	}

	@ViewBuilder
	private var paneContent: some View {
		switch pane {
		case .edit:
			document.editorView(document: $document, computed: computed)
		case .cfg:
			if let content_cfg = rule.cfg {
				CFGContentView(grammar: content_cfg)
			} else {
				Text("Building CFG...").foregroundStyle(.secondary)
			}
		case .regex:
			RegexContentView(rule_fsm: rule.fsm)
		case .fsm:
			ScrollView {
				FSMExportView(rule_alphabet: rule.alphabet, rule_fsm: rule.fsm)
				Spacer()
			}
		case .graph:
			DFAGraphPageView(rule_fsm: rule.fsm)
		case .railroad:
			ScrollView([.horizontal, .vertical]) {
				if let content_rr = rule.rr {
					content_rr.view
				} else {
					Text("Select a rule to view its railroad diagram")
						.foregroundStyle(.secondary)
				}
			}
		case .instances:
			InstanceGeneratorView(rule_fsm: rule.fsm)
		case .test:
			ScrollView {
				InputTestingView(
					rule_alphabet: rule.alphabet,
					rule_fsm: rule.fsm,
					content_cfg: rule.cfg,
				)
				Spacer()
			}
		}
	}

	var body: some View {
		paneContent
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

						StartRulePicker(title: "Start rule", computed: computed, selection: $selectedRule)

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

					if let err = rule.error {
						Text(err)
					}

					if computed.allRuleNames.isEmpty == false {
						RuleInformationView(document: $document, computed: computed, rule: rule)
						if rule.fsm == nil && rule.cfg == nil {
							if let err = rule.error {
								Text(err).foregroundStyle(.red)
							} else {
								Text("Building…").foregroundStyle(.secondary)
							}
						}
					} else if let err = rule.error {
						Text("Parse Error: \(err)").foregroundStyle(.red)
					} else {
						Text("Parsing...").foregroundStyle(.secondary)
					}
					Spacer()
				} // ScrollView
				.padding()
				.inspectorColumnWidth(min: 300, ideal: 500, max: 2000)
			}
		.onAppear {
			document.updateParser(computed)
		}
		.onChange(of: document) {
			document.updateParser(computed)
		}
		.onChange(of: selectedRule) {
			compileSelectedRule()
		}
		.onChange(of: computed.primaryRuleName) {
			if selectedRule == nil { selectedRule = computed.primaryRuleName }
		}
		.onChange(of: computed.parseRevision) {
			compileSelectedRule()
		}
		.onChange(of: availablePanes) {
			if availablePanes.contains(pane) == false { pane = .edit }
		}
		.toolbar {
			// It only makes sense to show this if there's rules to select between
			if computed.allRuleNames.count > 1 {
				ToolbarItem(placement: .principal) {
					HStack(spacing: 2) {
						Image(systemName: "arrow.right")
						StartRulePicker(title: "Start rule", computed: computed, selection: $selectedRule)
					}
				}
			}

			ToolbarItem(placement: .principal) {
				Picker("View", selection: $pane) {
					ForEach(availablePanes) { item in
						Label(item.title, systemImage: item.systemImage).tag(item)
					}
				}
				.pickerStyle(.segmented)
			}

			ToolbarItem(placement: .primaryAction) {
				Button {
					inspector_isPresented.toggle()
				} label: {
					Label("Inspector", systemImage: "sidebar.squares.right")
				}
			}
		}
		.environment(SelectedCharset(charset: MainAppModel.charsetDict[selectedCharsetId]!))
	}

	/// Ask the document to compile whatever rule the UI currently has selected.
	/// The editor itself does not track or compile a selected rule.
	private func compileSelectedRule() {
		let name = selectedRule ?? computed.primaryRuleName
		guard let name else { return }
		document.compileRule(name, from: computed, into: rule)
	}
}

struct StartRulePicker: View {
	let title: String
	let computed: RulelistAnalysis
	@Binding var selection: String?
	var body: some View {
		Picker(title, selection: $selection) {
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
		}.pickerStyle(.menu)

	}
}
