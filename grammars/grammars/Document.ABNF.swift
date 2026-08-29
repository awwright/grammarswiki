// TODO:
// - Auto-completion of rule names

import SwiftUI
import FSM
import CodeEditorView
import LanguageSupport
import UniformTypeIdentifiers

extension UTType {
	static var abnfDoc = UTType(exportedAs: "name.awwright.grammars.doc.abnf", conformingTo: .text)
}

/// Normalize line endings to CRLF before feeding text to `ABNFRulelist.parse`.
func abnfNormalizeLineEndings(_ text: String) -> String {
	text
		.replacingOccurrences(of: "\r\n", with: "\n")
		.replacingOccurrences(of: "\r", with: "\n")
		.replacingOccurrences(of: "\n", with: "\r\n")
}

// Model to represent a text file
struct ABNFDocument: DocumentProtocol, PageProtocol, Hashable, Equatable, FileDocument {
	let id = UUID()
	/// Used in in the inspector view in ``DocumentView``
	var filepath: URL?
	var name: String
	var type: String { "ABNF" }
	var charset: String
	var content: String
	var isImportingRFCXML: Bool = false

	static var readableContentTypes: [UTType] { [.abnfDoc] }

	init() {
		self.filepath = nil
		self.name = ""
		self.content = ""
		self.charset = "UTF-8"
	}

	init(filepath: URL?, name: String, charset: String, content: String) {
		self.filepath = filepath
		self.name = name
		self.content = abnfNormalizeLineEndings(content)
		self.charset = charset
	}

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		self.filepath = nil
		self.name = "name"
		self.content = abnfNormalizeLineEndings(String(decoding: data, as: UTF8.self))
		self.charset = "UTF-8"
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = Data(abnfNormalizeLineEndings(content).utf8)
		return .init(regularFileWithContents: data)
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.content == rhs.content && lhs.type == rhs.type
	}

	func duplicate() -> Self {
		Self(filepath: nil, name: name + " Copy", charset: charset, content: content)
	}

	// MARK: PageProtocol XML
	static var xmlElementName: String { "abnf" }

	init(xmlElement: XMLElement) throws {
		guard xmlElement.name == Self.xmlElementName else {
			throw PageXMLError.unexpectedElement(expected: Self.xmlElementName, actual: xmlElement.name);
		}
		self.filepath = nil;
		self.name = xmlElement.attribute(forName: "name")?.stringValue ?? "";
		self.charset = xmlElement.attribute(forName: "charset")?.stringValue ?? "UTF-8";
		self.isImportingRFCXML = false;
		let codeText = xmlElement.elements(forName: "code").first?.stringValue ?? "";
		self.content = abnfNormalizeLineEndings(codeText);
	}

	func toXMLElement() throws -> XMLElement {
		let el = XMLElement(name: Self.xmlElementName);
		el.setAttributesWith([
			"name": name,
			"charset": charset,
		]);
		let code = XMLElement(name: "code");
		// Escaped text content (Foundation serializes entities as needed).
		code.setStringValue(abnfNormalizeLineEndings(content), resolvingEntities: false);
		el.addChild(code);
		return el;
	}

	struct EditorView: EditorViewBody {
		@Binding var document: ABNFDocument
		let computed: RulelistAnalysis

		// Code editor variables
		@State private var position: CodeEditor.Position       = CodeEditor.Position()
		@State private var messages: Set<TextLocated<Message>> = [] // For syntax errors or annotations
		@State private var selectionLink: NSRange? = nil // For linking rule to definition
		@Environment(\.colorScheme) private var colorScheme: ColorScheme

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
				language: LanguageConfiguration(
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
					reservedOperators: [],
				),
			)
			.environment(\.codeEditorTheme, colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
			.frame(minHeight: 300)
			.font(.system(size: 14, design: .monospaced))
			.onChange(of: computed.content_parseErrorLine) {
				if let parseErrorLine = computed.content_parseErrorLine, parseErrorLine >= 0 {
					messages = Set([
						TextLocated(location: TextLocation(zeroBasedLine: parseErrorLine, column: 0), entity: Message(category: .error, length: 2, summary: "Syntax Error", description: nil))
					])
				} else {
					messages = [];
				}
			}
			.fileImporter(isPresented: $document.isImportingRFCXML, allowedContentTypes: [.xml]) {
				defer { document.isImportingRFCXML = false }
				guard case .success(let url) = $0 else { return }
				let documentName = url.lastPathComponent;
				do {
					guard url.startAccessingSecurityScopedResource() else { return }
					defer { url.stopAccessingSecurityScopedResource() }
					let xmlDoc = try XMLDocument(contentsOf: url, options: [])
					// Use local-name() to handle the default namespace used by real RFC XML (urn:ietf:rfc:7991 etc.).
					let sourceCodeNodes = try? xmlDoc.nodes(forXPath: "//*[local-name()='sourcecode'][@type=\"abnf9110\"]") as? [XMLElement] ?? []
					document.content += sourceCodeNodes?.map { node in
						// Many RFC XML elements add leading whitespace, strip it out if any
						// This line also has the effect of converting LF to CRLF
						let lines = (node.stringValue ?? "").split(separator: /\r?\n/, omittingEmptySubsequences: false);
						let minIndent = lines.compactMap{ $0.isEmpty ? nil : $0.prefix { $0.isWhitespace }.count }.min();
						guard let minIndent else { return node.stringValue ?? "" }
						let title = node.attribute(forName: "pn")?.stringValue ?? ""
						return  "; \(documentName) \(title)\r\n" + lines.map{ $0.dropFirst(minIndent) }.joined(separator: "\r\n");
					}.joined(separator: "\r\n") ?? "";
				} catch {
					print(error);
				}
			}
		}
	}

	struct RuleInfoView: RuleInfoViewBody {
		@Binding var document: ABNFDocument
		let computed: RulelistAnalysis

		@AppStorage("expandedRule_deps") private var rule_deps_expanded = true
		@AppStorage("expandedRule_builtin") private var rule_builtin_expanded = true
		@AppStorage("expandedRule_undefined") private var rule_undefined_expanded = true
		@AppStorage("expandedRule_recursive") private var rule_recursive_expanded = true

		var body: some View {
			if computed.selectedRulename != nil {
				if computed.selectedRule_dependencies.isEmpty == false {
					DisclosureGroup("Rule Dependencies", isExpanded: $rule_deps_expanded, content: {
						Text(String(computed.selectedRule_dependencies.joined(separator: ", ")))
					})
				}
				if computed.selectedRule_builtins.isEmpty == false {
					DisclosureGroup("Implicit Builtins", isExpanded: $rule_builtin_expanded, content: {
						Text(String(computed.selectedRule_builtins.joined(separator: ", ")))
					})
				}
				if computed.selectedRule_undefined.isEmpty == false {
					DisclosureGroup("Undefined Rules", isExpanded: $rule_undefined_expanded, content: {
						Text(String(computed.selectedRule_undefined.joined(separator: ", ")))
					})
				}
				if computed.selectedRule_recursive.isEmpty == false {
					DisclosureGroup("Recursive Rules", isExpanded: $rule_recursive_expanded, content: {
						Text(String(computed.selectedRule_recursive.joined(separator: ", ")))
					})
				}
			}
		}
	}

	private static let builtins = ABNFBuiltins<DFA<ClosedRangeAlphabet<UInt32>>>.dictionary.mapValues { $0.minimized() }

	func updateParser(_ parser: RulelistAnalysis) {
		let content = self.content;
		let documentName = self.name;
		let selectedRulename = parser.selectedRulename;
		parser.runUpdate {
			let parseInput = abnfNormalizeLineEndings(content);
			let rulelist: ABNFRulelist<UInt32>?;
			do {
				rulelist = try ABNFRulelist<UInt32>.parse(Array(parseInput.utf8));
			} catch let error as ABNFParseError<Array<UInt32>.Index> {
				await MainActor.run {
					parser.document_error = "Error at index: " + String(describing: error.index);
					let input = Array(parseInput.utf8);
					parser.content_parseErrorLine = input[0...error.index.startIndex].count(where: { $0 == 0xA });
				}
				return
			} catch {
				await MainActor.run {
					parser.document_error = error.localizedDescription;
					parser.content_parseErrorLine = nil;
				}
				return
			}
			if Task.isCancelled { return }
			guard let rulelist else { return }

			let orderedRules = rulelist.ruleNames;
			let primaryRuleName = orderedRules.first;
			// FIXME: This shouldn't filter out recursive references
			let topRuleNames = orderedRules.filter { !rulelist.referencedRules.contains($0) };
			let allRuleNames = orderedRules;
			await MainActor.run {
				parser.document_error = nil;
				parser.content_parseErrorLine = nil;
				parser.primaryRuleName = primaryRuleName;
				parser.topRuleNames = topRuleNames;
				parser.allRuleNames = allRuleNames;
			}
			if Task.isCancelled { return }
			guard let selectedRulename else { return }

			guard let bundlePath = Bundle.main.resourcePath else { fatalError() }
			let catalog = Catalog(root: bundlePath + "/catalog/");
			let (_, rulelist_all_final, _): (source: Dictionary<String, ABNFRulelist<UInt32>>, merged: ABNFRulelist<UInt32>, backward: Dictionary<String, (filename: String, ruleid: String)>) = try! catalog.load(path: documentName, content: parseInput);
			let rulelist_resolved = rulelist_all_final.addingBuiltins();

			let dependencies_list = rulelist_resolved.dependencies(rulename: selectedRulename);
			await MainActor.run {
				parser.selectedRule_dependencies = Array(dependencies_list.dependencies.reversed());
				parser.selectedRule_builtins = dependencies_list.builtins;
				parser.selectedRule_undefined = dependencies_list.undefined;
				parser.selectedRule_recursive = dependencies_list.recursive;
			}

			let dict = rulelist_resolved.dictionary;
			let dependencies = dependencies_list.dependencies.compactMap { if let rule = dict[$0] { ($0, rule) } else { nil } };
			if dependencies.isEmpty {
				await MainActor.run { parser.selectedRule_error = "dependencies is empty" }
				return;
			}

			let selectedRule_cfg: ABNFRulelist<UInt32>.CFG? = try? rulelist_resolved.toCFG(rulename: selectedRulename);
			let selectedRule_cfga: CFGArray<ClosedRangeAlphabet<UInt32>>? = selectedRule_cfg.map { CFGArray($0) };
			let selectedRule_rr: RailroadNode? = dict[selectedRulename]?.toRailroad(rules: dict.mapValues { $0.alternation });
			let selectedRule_chomskyClass = selectedRule_cfg?.chomskyClass();
			let selectedRule_memoryRequirements = selectedRule_cfg?.memoryRequirements();
			if Task.isCancelled { return }
			await MainActor.run {
				parser.selectedRule_error = nil;
				parser.selectedRule_cfg = selectedRule_cfg;
				parser.selectedRule_cfga = selectedRule_cfga;
				parser.selectedRule_rr = selectedRule_rr;
				parser.selectedRule_chomskyClass = selectedRule_chomskyClass;
				parser.selectedRule_memoryRequirements = selectedRule_memoryRequirements;
			}

			var result_fsm_dict: Dictionary<String, DFA<ClosedRangeAlphabet<UInt32>>> = Self.builtins;
			for (rulename, definition) in dependencies {
				let pat: DFA<ClosedRangeAlphabet<UInt32>>? = try? definition.toPattern(rules: result_fsm_dict);
				if let pat { result_fsm_dict[rulename] = pat.minimized() }
				if Task.isCancelled { return }
			}
			let result = result_fsm_dict[selectedRulename];
			if Task.isCancelled { return }
			await MainActor.run {
				parser.selectedRule_alphabet = result?.alphabet;
				parser.selectedRule_fsm = result;
			}
		}
	}
}
