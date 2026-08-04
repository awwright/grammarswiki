import SwiftUI
import FSM
import UniformTypeIdentifiers
import Foundation

struct NoteDocument: DocumentProtocol, Hashable, Equatable, FileDocument {
	let id = UUID()
	var filepath: URL?
	var name: String
	var start: String
	var charset: String
	var pages: [Page]

	var type: String { "Grammar XML" }

	struct Page: Hashable {
		var name: String
		var type: String
		/// If this is a "top-level" rule intended for external use
		var top: Bool
	}

	static var readableContentTypes: [UTType] { [.grammarsDoc] }

	init() {
		self.filepath = nil
		self.name = ""
		self.start = ""
		self.charset = "UTF-8"
		self.pages = []
	}

	init(filepath: URL?, name: String, start: String, charset: String, rules: [Page] = []) {
		self.filepath = filepath
		self.name = name
		self.start = start
		self.charset = charset
		self.pages = rules
	}

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile);
		}
		let xmlDoc = try XMLDocument(data: data, options: [])
		guard let root = xmlDoc.rootElement(), root.name == "grammar" else {
			throw CocoaError(.fileReadCorruptFile);
		}
		self.filepath = nil;
		self.name = root.attribute(forName: "name")?.stringValue ?? "";
		self.start = root.attribute(forName: "start")?.stringValue ?? "";
		self.charset = root.attribute(forName: "charset")?.stringValue ?? "UTF-8";

		var parsedRules: [Page] = [];
		for eRule in root.elements(forName: "rule") {
			let rName = eRule.attribute(forName: "name")?.stringValue ?? "";
			let topStr = eRule.attribute(forName: "top")?.stringValue?.lowercased() ?? "";
			let top = !topStr.isEmpty
			for eProduction in eRule.elements(forName: "p") {
				let expr = eProduction.stringValue ?? "";
				parsedRules.append(Page(name: rName, type: expr, top: top));
				// TODO: Support more than one alternative production
				break;
			}
		}
		self.pages = parsedRules;
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let root = XMLElement(name: "grammar");
		root.setAttributesWith([
			"name": self.name,
			"start": self.start,
			"charset": self.charset,
			"xmlns": "http://grammars.awwright.name/doc",
		]);

		for rule in self.pages {
			root.addChild({
				let ruleEl = XMLElement(name: "page");
				ruleEl.setAttributesWith([
					"name": rule.name,
					"top": rule.top ? "true" : "",
				]);
				ruleEl.addChild({
					let eProduction = XMLElement(name: "p");
					eProduction.setStringValue(rule.type, resolvingEntities: false)
					return eProduction;
				}())
				return ruleEl;
			}());
		}

		let xmlDoc = XMLDocument(rootElement: root);
		xmlDoc.characterEncoding = "UTF-8";
		xmlDoc.version = "1.0";
		let versionPI = XMLNode.processingInstruction(withName: "version", stringValue: "1") as! XMLNode;
		xmlDoc.insertChild(versionPI, at: 0);
		let data = xmlDoc.xmlData(options: [.nodePrettyPrint]);
		return FileWrapper(regularFileWithContents: data);
	}

	func duplicate() -> Self {
		Self(filepath: nil, name: name + " Copy", start: start, charset: charset, rules: pages)
	}

	struct EditorView: EditorViewBody {
		@Binding var document: NoteDocument
		let computed: NoteDocument.Parser

		var body: some View {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					GroupBox("Document") {
						VStack(alignment: .leading, spacing: 6) {
							TextField("Start rule (overall)", text: $document.start)
							TextField("Charset", text: $document.charset)
						}
						.padding(4)
					}

					ForEach(Array(document.pages.enumerated()), id: \.offset) { (offset, frag) in
						GroupBox(frag.type) {
							VStack(alignment: .leading, spacing: 4) {
								HStack {
									TextField("Name", text: Binding(
										get: { document.pages[offset].name },
										set: { document.pages[offset].name = $0 }
									))
									.font(.headline)

									Spacer()

									Button(role: .destructive) {
										document.pages.remove(at: offset)
									} label: {
										Image(systemName: "trash")
									}
								}

								// TODO: Show view for page here
							}
						}
					}

					Menu {
						Button("ABNF") {
							//var d = ABNFDocument()
							//d.name = "abnf\(document.pages.count + 1)"
							//document.pages.append(d)
						}
						Button("CFG") {
							//var d = CFGDocument()
							//d.name = "cfg\(document.pages.count + 1)"
							//document.pages.append(d)
						}
					} label: {
						Label("Add page", systemImage: "plus.rectangle")
					}
				}
				.padding()
			}
		}
	}

	struct RuleInfoView: EditorViewBody {
		@Binding var document: NoteDocument
		let computed: NoteDocument.Parser
		var body: some View {
		}
	}


	@Observable class Parser: DocumentParserProtocol {
		typealias Document = NoteDocument

		required init() {
			document = nil
			self._task = Task{}
			document_error = nil;
			document_error = nil;
			topRuleNames = [];
			allRuleNames = [];
		}

		deinit { _task.cancel() }

		var document: Document? { didSet { _update(); } }
		var document_error: String? = nil
		var primaryRuleName: String? = nil
		var topRuleNames: Array<String> = []
		var allRuleNames: Array<String> = []

		var selectedRulename: String? { didSet { _update(); } }
		var selectedRule_error: String? = nil
		var selectedRule_alphabet: ClosedRangeAlphabet<UInt32>? = nil
		var selectedRule_fsm: DFA<ClosedRangeAlphabet<UInt32>>? = nil
		var selectedRule_cfg: FSM.ABNFRulelist<UInt32>.CFG? = nil
		var selectedRule_rr: RailroadNode? = nil
		var selectedRule_complexityClass: Int? = nil
		var selectedRule_chomskyClass: Int? = nil
		var selectedRule_memoryRequirements: Int? = nil

		let builtins = ABNFBuiltins<DFA<ClosedRangeAlphabet<UInt32>>>.dictionary.mapValues { $0.minimized() };

		var _task: Task<(), Never>
		func _update() {
			_task.cancel()
			document_error = nil;
			document_error = nil;

			// Don't clear the rule names during parsing, only update when the document is successfully parsed
			//topRuleNames = []; allRuleNames = [];
			_task = Task {
				guard let document else { return }
				let primaryRuleName: String? = document.pages.first?.name;
				let topRuleNames: [String] = document.pages.compactMap{ $0.top ? $0.name : nil };
				let allRuleNames: [String] = document.pages.map { $0.name };
				if _task.isCancelled { return }
				await MainActor.run {
					self.primaryRuleName = primaryRuleName;
					self.topRuleNames = topRuleNames;
					self.allRuleNames = allRuleNames;
				}

				guard let primaryRuleName else { return }
			}
		}
	}
}
