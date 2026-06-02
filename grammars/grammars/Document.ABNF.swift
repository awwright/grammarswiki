import SwiftUI
import FSM
import CodeEditorView
import LanguageSupport
import UniformTypeIdentifiers

// Model to represent a text file
struct ABNFDocument: DocumentProtocol, Hashable, Equatable, FileDocument {
	let id = UUID()
	/// Used in in the inspector view in ``DocumentView``
	var filepath: URL?
	var name: String
	var type: String
	var charset: String
	var content: String

	var topRuleNames: Array<String> {
		// FIXME: Cache this parse result somewhere
		let rulelist = try? ABNFRulelist<UInt8>.parse(self.content.utf8);
		guard let rulelist else { return [] }
		let orderedRules = rulelist.ruleNames;
		return orderedRules.filter { !rulelist.referencedRules.contains($0) }
	}

	var allRuleNames: Array<String> {
		// FIXME: Cache this parse result somewhere
		let rulelist = try? ABNFRulelist<UInt8>.parse(self.content.utf8);
		guard let rulelist else { return [] }
		let orderedRules = rulelist.ruleNames;
		return orderedRules.filter { !rulelist.referencedRules.contains($0) }
	}

	static var readableContentTypes: [UTType] { [.grammarsDoc] }

	init() {
		self.filepath = nil
		self.name = ""
		self.type = "ABNF"
		self.content = ""
		self.charset = "UTF-8"
	}

	init(filepath: URL?, name: String, type: String, charset: String, content: String) {
		self.filepath = filepath
		self.name = name
		self.type = type
		self.content = content
		self.charset = charset
	}

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		self.filepath = nil
		self.name = "name"
		self.type = "ABNF"
		self.content = String(decoding: data, as: UTF8.self)
		self.charset = "UTF-8"
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = Data(content.utf8)
		return .init(regularFileWithContents: data)
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.content == rhs.content && lhs.type == rhs.type
	}

	func duplicate() -> Self {
		Self(filepath: nil, name: name + " Copy", type: type, charset: charset, content: content)
	}

	// Export the grammar as an ABNFRulelist, if possible
	func toABNFRulelist() throws -> ABNFRulelist<UInt32>  {
		guard let bundlePath = Bundle.main.resourcePath else { fatalError() }
		let text = self.content;
		let document = self;
		// Filename references are always within the catalog... at least for now?
		let catalog = Catalog(root: bundlePath + "/catalog/")
		let (_, rulelist_all_final, _): (source: Dictionary<String, ABNFRulelist<UInt32>>, merged: ABNFRulelist<UInt32>, backward: Dictionary<String, (filename: String, ruleid: String)>) = try catalog.load(path: document.name, content: text)
		return rulelist_all_final;
	}

	struct EditorView: EditorViewBody {
		@Binding var document: ABNFDocument
		@Binding var parseErrorLine: Int?

		// Code editor variables
		@State private var position: CodeEditor.Position       = CodeEditor.Position()
		@State private var messages: Set<TextLocated<Message>> = [] // For syntax errors or annotations
		@State private var selectionLink: NSRange? = nil // For linking rule to definition
		@Environment(\.colorScheme) private var colorScheme: ColorScheme

		// Language configuration
		private func abnfLanguageConfiguration() -> LanguageConfiguration {
			return MainAppModel.fileTypes.first { $0.label == "ABNF" }?.languageConfiguration ?? MainAppModel.fileTypes[0].languageConfiguration
		}

		var body: some View {
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
			.onChange(of: parseErrorLine) {
				if let parseErrorLine, parseErrorLine >= 0 {
					messages = Set([
						TextLocated(location: TextLocation(zeroBasedLine: parseErrorLine, column: 0), entity: Message(category: .error, length: 2, summary: "Syntax Error", description: nil))
					])
				} else {
					messages = [];
				}
			}
		}
	}
}
