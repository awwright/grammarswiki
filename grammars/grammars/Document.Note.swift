import SwiftUI
import FSM
import UniformTypeIdentifiers
import Foundation

extension UTType {
	static var grammarsDoc = UTType(exportedAs: "name.awwright.grammars.doc", conformingTo: .xml)
}

/// Errors while encoding/decoding notebook page XML.
enum PageXMLError: Error, LocalizedError {
	case unexpectedElement(expected: String, actual: String?)
	case missingChild(String)
	case invalidAttribute(String)

	var errorDescription: String? {
		switch self {
		case .unexpectedElement(let expected, let actual):
			"Expected <\(expected)> element, got \(actual.map { "<\($0)>" } ?? "nil")"
		case .missingChild(let name):
			"Missing required child <\(name)>"
		case .invalidAttribute(let name):
			"Invalid or missing attribute \"\(name)\""
		}
	}
}

/// A page that can appear in a notebook.
protocol PageProtocol: LanguageSource, Hashable, Identifiable {
	typealias ID = UUID;
	var id: UUID { get }
	var name: String { get set }
	/// Type shown in the page (e.g. "ABNF").
	var type: String { get }

	associatedtype PageEditor: View

	/// Editor UI when this model is embedded as a notebook page.
	@ViewBuilder
	static func pageEditor(_ page: Binding<Self>) -> PageEditor

	/// Root XML element name for this page kind (e.g. `"abnf"`, `"cfg"`, `"fc"`).
	static var xmlElementName: String { get }

	/// Parse a page from an element whose name is ``xmlElementName``.
	init(xmlElement: XMLElement) throws

	/// Emit an element named ``xmlElementName`` for notebook save.
	func toXMLElement() throws -> XMLElement
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

	func erasedMakeXMLElement() throws -> XMLElement {
		try toXMLElement()
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

	/// Encode this page to its structured XML element.
	func makeXMLElement() throws -> XMLElement {
		try box.erasedMakeXMLElement()
	}

	func updateParser(_ parser: RulelistAnalysis) {
		box.updateParser(parser)
	}

	func compileRule(_ ruleName: String, from list: RulelistAnalysis, into rule: RuleAnalysis) {
		box.compileRule(ruleName, from: list, into: rule)
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

/// Hosts a document's standalone ``EditorView`` with a privately owned ``RulelistAnalysis``.
struct PageDocumentEditor<Document: DocumentProtocol>: View {
	@Binding var document: Document
	@State private var computed = RulelistAnalysis()

	var body: some View {
		Document.EditorView(document: $document, computed: computed)
			.onAppear { document.updateParser(computed) }
			.onChange(of: document) { _, newValue in
				newValue.updateParser(computed);
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

	/// Element local-name → page constructor.
	/// Later: optional parameter / property may override this table.
	private static let pageXMLDecoders: [String: (XMLElement) throws -> Page] = [
		ABNFDocument.xmlElementName: { Page(try ABNFDocument(xmlElement: $0)) },
		CFGDocument.xmlElementName: { Page(try CFGDocument(xmlElement: $0)) },
		FCDocument.xmlElementName: { Page(try FCDocument(xmlElement: $0)) },
		UnionPage.xmlElementName: { Page(try UnionPage(xmlElement: $0)) },
	]

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		let xmlDoc = try XMLDocument(data: data, options: [])
		guard let root = xmlDoc.rootElement(), root.name == "grammar" else {
			throw CocoaError(.fileReadCorruptFile)
		}
		self.filepath = nil
		self.name = root.attribute(forName: "name")?.stringValue ?? ""
		self.start = root.attribute(forName: "start")?.stringValue ?? ""
		self.charset = root.attribute(forName: "charset")?.stringValue ?? "UTF-8"

		var loaded: [Page] = []
		for case let el as XMLElement in root.children ?? [] {
			guard let elName = el.name, elName != "version" else { continue }
			guard let decode = Self.pageXMLDecoders[elName] else { continue }
			loaded.append(try decode(el))
		}
		self.pages = loaded
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let root = XMLElement(name: "grammar");
		root.setAttributesWith([
			"name": self.name,
			"start": self.start,
			"charset": self.charset,
			"xmlns": "http://grammars.awwright.name/doc",
		])

		let versionEl = XMLElement(name: "version")
		versionEl.setStringValue("2", resolvingEntities: false)
		root.addChild(versionEl)

		for page in self.pages {
			root.addChild(try page.makeXMLElement());
		}

		let xmlDoc = XMLDocument(rootElement: root);
		xmlDoc.characterEncoding = "UTF-8";
		xmlDoc.version = "1.0";
		let versionPI = XMLNode.processingInstruction(withName: "version", stringValue: "2") as! XMLNode;
		xmlDoc.insertChild(versionPI, at: 0);
		let data = xmlDoc.xmlData(options: [.nodePrettyPrint]);
		return FileWrapper(regularFileWithContents: data);
	}

	func duplicate() -> Self {
		Self(filepath: nil, name: name + " Copy", start: start, charset: charset, rules: pages)
	}

	struct EditorView: EditorViewBody {
		@Binding var document: NoteDocument
		let computed: RulelistAnalysis

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
						Button("Union") {
							var d = UnionPage();
							d.name = "union\(document.pages.count + 1)";
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

	struct RuleInfoView: RuleInfoViewBody {
		@Binding var document: NoteDocument
		let rule: RuleAnalysis
		var body: some View {
			DisclosureGroup("Notebook Properties", content: {
				Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
					GridRow(alignment: .top) {
						Text("Pages").font(.headline).gridColumnAlignment(.trailing)
						VStack(alignment: .leading) {
							ForEach(document.pages, id: \.self) {
								Text($0.name)
							}
						}
					}
				}
				.padding()
				.frame(maxWidth: .infinity, alignment: .leading)
			})
		}
	}

	func updateParser(_ parser: RulelistAnalysis) {
		let previous = parser.nested;
		var next: Dictionary<UUID, RulelistAnalysis> = [:];
		for page in pages {
			let child = previous[page.id] ?? RulelistAnalysis();
			let isNew = previous[page.id] == nil;
			page.updateParser(child);
			next[page.id] = child;
			if isNew {
				observeChild(parent: parser, id: page.id, child: child);
			}
		}
		parser.nested = next;
		publish(parser, start: start);

		func publish(_ parser: RulelistAnalysis, start: String) {
			let all = pages.flatMap { parser.nested[$0.id]?.allRuleNames ?? [] };
			let tops = pages.flatMap { parser.nested[$0.id]?.topRuleNames ?? [] };
			parser.allRuleNames = all;
			parser.topRuleNames = tops;
			parser.primaryRuleName = start.isEmpty ? all.first : start;
		}

		/// When a child publishes an update, refresh the aggregation
		func observeChild(parent: RulelistAnalysis, id: UUID, child: RulelistAnalysis) {
			withObservationTracking {
				_ = child.allRuleNames;
				_ = child.topRuleNames;
				_ = child.parseRevision;
			} onChange: {
				DispatchQueue.main.async {
					guard parent.nested[id] === child else { return }
					let oldFirst = parent.allRuleNames.first;
					let all = pages.flatMap { parser.nested[$0.id]?.allRuleNames ?? [] };
					let tops = pages.flatMap { parser.nested[$0.id]?.topRuleNames ?? [] };
					parent.allRuleNames = all;
					parent.topRuleNames = tops;
					if parent.primaryRuleName == nil || parent.primaryRuleName == oldFirst {
						parent.primaryRuleName = start.isEmpty ? all.first : start;
					}
					parent.parseRevision += 1;
					observeChild(parent: parent, id: id, child: child);
				}
			}
		}
	}

	func compileRule(_ ruleName: String, from list: RulelistAnalysis, into rule: RuleAnalysis) {
		if pages.isEmpty {
			failUnknown();
			return;
		}

		// Only compile against a page's own analysis — never the notebook parent (it has no page snapshot).
		if let page = pages.first(where: { list.nested[$0.id]?.allRuleNames.contains(ruleName) == true }),
		   let child = list.nested[page.id] {
			page.compileRule(ruleName, from: child, into: rule);
			return;
		}

		let nestedReady = pages.allSatisfy { list.nested[$0.id] != nil }
		let namesPublished = list.nested.values.contains { $0.allRuleNames.isEmpty == false }
		if nestedReady && namesPublished {
			failUnknown();
			return;
		}

		func failUnknown() {
			rule.runCompile(ruleName: ruleName, from: list) { revision in
				await MainActor.run {
					rule.error = "Unknown rule \(ruleName)"
					rule.compiledRevision = revision
				}
			}
		}
	}
}
