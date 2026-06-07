import SwiftUI
import FSM
import UniformTypeIdentifiers
import Foundation

struct NoteDocument: DocumentProtocol, Hashable, Equatable, FileDocument {
	let id = UUID()
	var filepath: URL?
	var name: String
	var charset: String
	var rules: [Rule]

	var type: String { "Grammar XML" }

	struct Rule: Hashable {
		var name: String
		var expression: String
		/// If this is a "top-level" rule intended for external use
		var top: Bool
	}

	static var readableContentTypes: [UTType] { [.grammarsDoc] }

	init() {
		self.filepath = nil
		self.name = ""
		self.charset = "UTF-8"
		self.rules = []
	}

	init(filepath: URL?, name: String, charset: String, rules: [Rule] = []) {
		self.filepath = filepath
		self.name = name
		self.charset = charset
		self.rules = rules
	}

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		self.filepath = nil
		self.name = "name"
		self.charset = "UTF-8"
		do {
			let xmlDoc = try XMLDocument(data: data, options: []);
			// TODO actually read the rules from the file...
			self.rules = []
		} catch {
			self.rules = []
		}
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		//fatalError()
		//let data = Data(content.utf8)
		return .init(regularFileWithContents: Data())
	}

	func duplicate() -> Self {
		Self(filepath: nil, name: name + " Copy", charset: charset, rules: rules)
	}

	// Export the grammar as an ABNFRulelist, if possible
	func toABNFRulelist() throws -> ABNFRulelist<UInt32>  {
		fatalError()
	}

	struct EditorView: EditorViewBody {
		@Binding var document: NoteDocument
		let computed: NoteDocument.Parser

		var body: some View {
			ScrollView {
				VStack(alignment: .leading) {
					ForEach(Array(document.rules.enumerated()), id: \.offset) { (offset, content) in
						HStack {
							Text("\(offset)")
							Button("Export", systemImage: content.top ? "star.fill" : "star") {
								document.rules[offset].top.toggle()
							}
							Button("Delete", systemImage: "minus.circle") {
								document.rules.remove(at: offset)
							}
						}
						TextField("Name", text: Binding(get: {content.name}, set: { document.rules[offset].name = $0; }))
						TextField("Expression", text: Binding(get: {content.expression}, set: { document.rules[offset].expression = $0; }))
							.font(.system(size: 14, design: .monospaced))
						Divider()
					}
				}

				Button("Add", systemImage: "plus.rectangle") {
					document.rules.append(.init(name: "Label", expression: "", top: false))
				}
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
			asABNFRulelist = nil;
			document_error = nil;
			topRuleNames = [];
			allRuleNames = [];
		}

		deinit { _task.cancel() }

		var document: Document? { didSet { _update(); } }
		var document_error: String? = nil
		var asABNFRulelist: FSM.ABNFRulelist<UInt32>? = nil
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
			asABNFRulelist = nil;
			document_error = nil;

			// Don't clear the rule names during parsing, only update when the document is successfully parsed
			//topRuleNames = []; allRuleNames = [];
			_task = Task {
				guard let document else { return }
				let primaryRuleName: String? = document.rules.first?.name;
				let topRuleNames: [String] = document.rules.compactMap{ $0.top ? $0.name : nil };
				let allRuleNames: [String] = document.rules.map { $0.name };
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
