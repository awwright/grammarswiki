import SwiftUI
import FSM
import UniformTypeIdentifiers
import Foundation

extension UTType {
	static var grammarsDoc = UTType(exportedAs: "name.awwright.grammars.doc", conformingTo: .xml)
}

/// A page that can appear in a notebook.
protocol PageProtocol: Hashable, Identifiable where ID == UUID {
	var id: UUID { get }
	var name: String { get set }
	/// Type shown in the page (e.g. "ABNF").
	var type: String { get }

	associatedtype PageEditor: View

	/// Editor UI when this model is embedded as a notebook page.
	@ViewBuilder
	static func pageEditor(_ page: Binding<Self>) -> PageEditor
}

extension PageProtocol {
	/// Project an erased ``Page`` binding into a binding of this concrete page type.
	///
	/// Fails hard if the erased value is not `Self` — never returns a stale copy.
	static func binding(from page: Binding<Page>) -> Binding<Self> {
		Binding(
			get: {
				guard let value = page.wrappedValue.unwrap(Self.self) else {
					preconditionFailure(
						"Page editor binding type mismatch: expected \(Self.self), got a different page type"
					);
				}
				return value;
			},
			set: { newValue in
				precondition(
					newValue.id == page.wrappedValue.id,
					"Page editor must not change page id (expected \(page.wrappedValue.id), got \(newValue.id))"
				);
				page.wrappedValue = Page(newValue);
			}
		)
	}

	/// Open this erased page's notebook editor by casting the ``Page`` binding to `Self`.
	func erasedPageEditor(binding: Binding<Page>) -> AnyView {
		AnyView(Self.pageEditor(Self.binding(from: binding)))
	}

	func erasedEquals(_ other: any PageProtocol) -> Bool {
		guard let other = other as? Self else { return false }
		return self == other;
	}

	func erasedHash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(Self.self));
		hasher.combine(self);
	}
}

/// Default notebook embed for filesystem documents: reuse their standalone ``EditorView``
/// (with a private ``Parser``). Override ``pageEditor`` for a lighter page-only UI.
extension PageProtocol where Self: DocumentProtocol {
	@ViewBuilder
	static func pageEditor(_ page: Binding<Self>) -> some View {
		PageDocumentEditor(document: page)
	}
}

/// Type-erased notebook page stored in ``NoteDocument/pages``.
struct Page: Identifiable, Hashable {
	fileprivate var box: any PageProtocol

	init<P: PageProtocol>(_ page: P) {
		self.box = page;
	}

	var id: UUID { box.id }

	var name: String {
		get { box.name }
		set { box.name = newValue; }
	}

	var type: String { box.type }

	/// Dispatch to the concrete type's ``PageProtocol/pageEditor`` (opens the existential).
	func pageEditor(binding: Binding<Page>) -> AnyView {
		box.erasedPageEditor(binding: binding)
	}

	/// Cast the erased payload to a concrete ``PageProtocol`` type.
	fileprivate func unwrap<T: PageProtocol>(_ type: T.Type) -> T? {
		box as? T
	}

	static func == (lhs: Page, rhs: Page) -> Bool {
		lhs.box.erasedEquals(rhs.box)
	}

	func hash(into hasher: inout Hasher) {
		box.erasedHash(into: &hasher);
	}
}

/// Hosts a document's standalone ``EditorView`` with a privately owned ``Parser``.
/// Default notebook embed for types that are both ``DocumentProtocol`` and ``PageProtocol``.
struct PageDocumentEditor<Document: DocumentProtocol>: View {
	@Binding var document: Document
	@State private var computed = Document.Parser()

	var body: some View {
		Document.EditorView(document: $document, computed: computed)
			.onAppear { computed.document = document }
			.onChange(of: document) { _, newValue in
				computed.document = newValue;
			}
	}
}

struct NoteDocument: DocumentProtocol, Hashable, Equatable, FileDocument {
	let id = UUID()
	var filepath: URL?
	var name: String
	var start: String
	var charset: String
	var pages: [Page]

	var type: String { "Grammar XML" }

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
		// TODO: Parse pages from the loaded document
		self.pages = [];
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

					ForEach($document.pages) { $page in
						GroupBox("\(page.type)") {
							VStack(alignment: .leading, spacing: 8) {
								HStack {
									TextField("Name", text: $page.name)
										.font(.headline)

									Spacer()

									Button(role: .destructive) {
										document.pages.removeAll { $0.id == page.id }
									} label: {
										Image(systemName: "trash")
									}
								}

								// Open dispatch: each page renders its own pageEditor.
								page.pageEditor(binding: $page)
							}
						}
					}

					Menu {
						// Not all of the implementations of PageProtocol have to appear here, just these ones I'm interested in
						// e.g. I should be able to add an implementation of PageProtocol here without needing any other changes
						Button("ABNF") {
							var d = ABNFDocument();
							d.name = "abnf\(document.pages.count + 1)";
							document.pages.append(Page(d));
						}
						Button("CFG") {
							var d = CFGDocument();
							d.name = "cfg\(document.pages.count + 1)";
							document.pages.append(Page(d));
						}
						Button("Finite Choice") {
							var d = FCDocument();
							d.name = "fc\(document.pages.count + 1)";
							document.pages.append(Page(d));
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

		var _task: Task<(), Never>
		func _update() {
			_task.cancel()
			document_error = nil;

			// Don't clear the rule names during parsing, only update when the document is successfully parsed
			//topRuleNames = []; allRuleNames = [];
			_task = Task {
				guard let document else { return }
				let primaryRuleName: String? = document.pages.first?.name;
				let topRuleNames: [String] = document.pages.map { $0.name };
				let allRuleNames: [String] = document.pages.map { $0.name };
				if Task.isCancelled { return }
				await MainActor.run {
					self.primaryRuleName = primaryRuleName;
					self.topRuleNames = topRuleNames;
					self.allRuleNames = allRuleNames;
				}
			}
		}
	}
}
