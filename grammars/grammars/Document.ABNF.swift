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
		let computed: ABNFDocument.Parser

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
		}
	}

	struct RuleInfoView: EditorViewBody {
		@Binding var document: ABNFDocument
		let computed: ABNFDocument.Parser

		@AppStorage("expandedRule_deps") private var rule_deps_expanded = true
		@AppStorage("expandedRule_builtin") private var rule_builtin_expanded = true
		@AppStorage("expandedRule_undefined") private var rule_undefined_expanded = true
		@AppStorage("expandedRule_recursive") private var rule_recursive_expanded = true

		var body: some View {
			if let content_rulelist = computed.asABNFRulelist, let selectedRule = computed.selectedRulename {
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
		}
	}


	@Observable class Parser: DocumentParserProtocol {
		typealias Document = ABNFDocument

		required init() {
			document = nil
			self._task = Task{}
			document_error = nil;
			asABNFRulelist = nil;
			document_error = nil;
			content_parseErrorLine = nil;
			topRuleNames = [];
			allRuleNames = [];
		}

		deinit { _task.cancel() }

		var document: Document? { didSet { _update(); } }
		var document_error: String? = nil
		var content_parseErrorLine: Int? = nil
		var asABNFRulelist: FSM.ABNFRulelist<UInt32>? = nil
		var primaryRuleName: String? = nil
		var topRuleNames: Array<String> = []
		var allRuleNames: Array<String> = []

		var selectedRulename: String? { didSet { _update(); } }
		var selectedRule_error: String? = nil
		var selectedRule_alphabet: ClosedRangeAlphabet<UInt32>? = nil
		var selectedRule_fsm: DFA<ClosedRangeAlphabet<UInt32>>? = nil
		var selectedRule_cfg: ABNFRulelist<UInt32>.CFG? = nil
		var selectedRule_rr: RailroadNode? = nil
		var selectedRule_complexityClass: Int? = nil
		var selectedRule_chomskyClass: Int? = nil
		var selectedRule_memoryRequirements: Int? = nil

		let builtins = ABNFBuiltins<DFA<ClosedRangeAlphabet<UInt32>>>.dictionary.mapValues { $0.minimized() };

		var _task: Task<(), Never>
		func _update() {
			print("updated document");
			_task.cancel()
			document_error = nil;
			asABNFRulelist = nil;
			document_error = nil;
			content_parseErrorLine = nil;
			// Don't clear the rule names during parsing, only update when the document is successfully parsed
			//topRuleNames = []; allRuleNames = [];
			_task = Task {
				guard let document else { return }
				let rulelist: ABNFRulelist<UInt32>?;
				do {
					print("Parsing");
					// Array() is necessary otherwise the error will be of type ABNFParseError<String.Index>
					rulelist = try ABNFRulelist<UInt32>.parse(Array(document.content.utf8))
					print("Parsed");
					await MainActor.run { self.asABNFRulelist = rulelist }
				} catch let error as ABNFParseError<Array<UInt32>.Index> {
					print("ABNFParseError");
					print(error.localizedDescription);
					rulelist = nil;
					await MainActor.run {
						self.document_error = "Error at index: " + String(describing: error.index)
						let input = Array(document.content.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
						content_parseErrorLine = input[0...error.index.startIndex].count(where: { $0 == 0xA })
					}
					return
				} catch {
					print("Undefined error while parsing")
					print(error.localizedDescription);
					rulelist = nil;
					await MainActor.run {
						self.document_error = error.localizedDescription;
					}
					return
				}
				if _task.isCancelled { return }
				guard let rulelist else { return }

				let orderedRules = rulelist.ruleNames;
				let primaryRuleName = orderedRules.first;
				// FIXME: This shouldn't filter out recursive references
				let topRuleNames = orderedRules.filter { !rulelist.referencedRules.contains($0) };
				let allRuleNames = orderedRules;
				await MainActor.run {
					self.primaryRuleName = primaryRuleName;
					self.topRuleNames = topRuleNames;
					self.allRuleNames = allRuleNames;
				}
				if _task.isCancelled { return }
				guard let selectedRulename else { return }

				let dependencies_list = rulelist.dependencies(rulename: selectedRulename);
				let dict = rulelist.dictionary;
				let dependencies = dependencies_list.dependencies.compactMap { if let rule = dict[$0] { ($0, rule) } else { nil } }
				if(dependencies.isEmpty){
					await MainActor.run { selectedRule_error = "dependencies is empty"; }
					return
				}
				if(dependencies_list.recursive.isEmpty == false){
					await MainActor.run { selectedRule_error = "Rule is recursive"; }
					return
				}

				var result_fsm_dict: Dictionary<String, DFA<ClosedRangeAlphabet<UInt32>>> = builtins.mapValues { $0.minimized() }
				for (rulename, definition) in dependencies {
					let pat: DFA<ClosedRangeAlphabet<UInt32>>? = try? definition.toPattern(rules: result_fsm_dict);
					if let pat { result_fsm_dict[rulename] = pat.minimized() }
				}
				guard let result = result_fsm_dict[selectedRulename] else { return }

				let selectedRule_alphabet: ClosedRangeAlphabet<UInt32> = result.alphabet;
				let selectedRule_fsm: DFA<ClosedRangeAlphabet<UInt32>> = result;
				let selectedRule_cfg: ABNFRulelist<UInt32>.CFG? = try? rulelist.toCFG(rulename: selectedRulename);
				let selectedRule_rr: RailroadNode? = rulelist.dictionary[selectedRulename]?.toRailroad(rules: rulelist.dictionary.mapValues { $0.alternation })
//				let selectedRule_complexityClass: Int =
				let selectedRule_chomskyClass: Int? = selectedRule_cfg?.chomskyClass();
				let selectedRule_memoryRequirements: Int? = selectedRule_cfg?.memoryRequirements();
				await MainActor.run {
					self.selectedRule_alphabet = selectedRule_alphabet;
					self.selectedRule_fsm = selectedRule_fsm;
					self.selectedRule_cfg = selectedRule_cfg;
					self.selectedRule_rr = selectedRule_rr;
//					self.selectedRule_complexityClass = selectedRule_complexityClass;
					self.selectedRule_chomskyClass = selectedRule_chomskyClass;
					self.selectedRule_memoryRequirements = selectedRule_memoryRequirements;
				}
			}
		}
	}


}
