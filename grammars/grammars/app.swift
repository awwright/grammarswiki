import SwiftUI
import FSM
import LanguageSupport
import UniformTypeIdentifiers

// TODO: Move test input into DocumentWindow, so that other widgets like CFGView can highlight rules based on the input and parse status
// TODO: Implement CFG methods for chomsky normal form, greibach normal form
// TODO: List parse forest productions/alternatives in same order as the original grammar does
// TODO: Add RegexDocument to import regular expressions as a grammar
// TODO: Add JSONSchemaDocument to import a JSON Schema as a grammar
// TODO: Add RFC XML Document (reads ABNF code inside RFC XML)

/// Stores a method of converting from a string of numbers to a String, for display purposes
struct Charset {
	let id: String
	let label: String
	/// Convert to a String, if there is such a representation
	let toString: ((UInt32) -> String)?
	/// Show a (possibly lossy) representation of the string, using ? or placeholders as necessary
	let toPrintable: (UInt32) -> String
	/// Represent literal characters from this character set in single or double quotes
	/// Escape other characters using U+... or other notation
	let toQuoted: (UInt32) -> String
}

@Observable class SelectedCharset {
	var charset: Charset
	init(charset: Charset) {
		self.charset = charset
	}
	// TODO: Use double quotes for case-insensitive, and single quotes (or no quotes) for case-sensitive
	func describe(_ rangeSet: Array<ClosedRange<UInt32>>) -> String {
		// Handle empty set case
		guard !rangeSet.isEmpty else { return "∅" }

		// Convert set to array and sort by lower bound
		let sortedRanges = rangeSet.sorted { $0.lowerBound < $1.lowerBound }

		// Initialize result with the first range
		var merged: [ClosedRange<UInt32>] = [sortedRanges[0]]

		// Iterate through remaining ranges
		for current in sortedRanges.dropFirst() {
			let last = merged.last!

			// Check if current range is adjacent to or overlaps with the last merged range
			if current.lowerBound <= last.upperBound + 1 && ((0x30...0x39).contains(current.lowerBound) || (0x41...0x5A).contains(current.lowerBound) || (0x61...0x7A).contains(current.lowerBound) || current.lowerBound > 0x7F) && ((0x30...0x39).contains(last.lowerBound) || (0x41...0x5A).contains(last.lowerBound) || (0x61...0x7A).contains(last.lowerBound) || last.lowerBound > 0x7F) {
				// Merge by creating a new range with the same lower bound and the maximum upper bound
				let newUpper = max(last.upperBound, current.upperBound)
				merged[merged.count - 1] = last.lowerBound...newUpper
			} else {
				// If not adjacent or overlapping, add the current range as a new segment
				merged.append(current)
			}
		}

		return merged
		// U+22EF Midline Horizontal Ellipsis
			.map { charset.toQuoted($0.lowerBound) + ($0.lowerBound==$0.upperBound ? "" : ("⋯" + charset.toQuoted($0.upperBound)) ) }
		// U+2001 EM QUAD, a space that is an em-dash wide, for increased separation
			.joined(separator: "\u{2001}")
	}
}


@main
struct MainApp: App {
	@State private var model = MainAppModel()
	@Environment(\.newDocument) private var newDocument
	@FocusedBinding(\.isImportingRFCXML) var isImportingRFCXML: Bool?
	var body: some Scene {
		// The DocumentGroup is listed first so that it gets the keyboard shortcuts for New, Save, Open
		DocumentGroup(newDocument: NoteDocument()) { file in
			DocumentView<NoteDocument>(document: file.$document)
		}

		DocumentGroup(newDocument: ABNFDocument()) { file in
			DocumentView<ABNFDocument>(document: file.$document)
				.focusedSceneValue(\.isImportingRFCXML, file.$document.isImportingRFCXML)
		}

		DocumentGroup(newDocument: CFGDocument()) { file in
			DocumentView<CFGDocument>(document: file.$document)
		}

		Window("Catalog", id: "Catalog") {
			CatalogView(model: model)
		}.defaultLaunchBehavior(.presented)

		Settings {
			SettingsView()
		}
		.commands {
			// Adding commands to one window seems to suffice for all of them
			// File mennu
			CommandGroup(replacing: .newItem) {
				Menu("New", systemImage: "plus") {
					// TODO: Figure out how to get this to work for the Catalog window
					Button("Grammar notebook") { newDocument(contentType: .grammarsDoc) }.keyboardShortcut("N")
					Divider()
					Button("ABNF rule list") { newDocument(contentType: .abnfDoc) }
					Button("CFG (JSON)") { newDocument(contentType: .cfgJsonDoc) }
				}
			}
			CommandGroup(after: .importExport) {
				Menu("Import") {
					// TODO: Figure out how to get this to work for the Catalog window
					Button("RFC XML") { isImportingRFCXML = true }.disabled(isImportingRFCXML == nil)
				}
			}
			CommandGroup(replacing: .help) {
				let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "";
				Button("\(name) Help", systemImage: "questionmark.circle") {
					// TODO: Bundle this file with the app, or remove this replacement and use the builtin help viewer
					if let url = URL(string: "https://awwright.name/2026/Syntax%20Forge%20Guide.pdf") {
						NSWorkspace.shared.open(url)
					}
				}
				.keyboardShortcut("?", modifiers: [.command])
			}
			// View menu
			SidebarCommands()
			InspectorCommands()
		}
	}
}

@Observable class MainAppModel {
	var user: [UUID: CatalogListItem] = [:]
	var user_filepath_id: [URL: UUID] = [:]
	var userSorted: Array<CatalogListItem> = []
	// You could also watch the catalog directory, but it's usually embedded inside the app bundle and isn't going to change
	let catalog: Array<CatalogListItem>
	let userDocumentsDirectory: URL?
	let userDocumentsWatcher: DirectoryWatcher

	static let typeExtensions: [String: String] = ["ABNF": ".abnf"];
	static let extensionsType: [String: String] = Dictionary(uniqueKeysWithValues: typeExtensions.map { ($0.1, $0.0) });

	static let charsets: [Charset] = [
		// TODO: Add binary, which is sometimes useful for networking protocols
		Charset(
			id: "Decimal",
			label: "10",
			toString: { String(format: "%02d", $0) },
			toPrintable: { String(format: "%02d", $0) },
			toQuoted: { String(format: "%02d", $0) },
		),
		Charset(
			id: "Hexadecimal",
			label: "16",
			toString: { String(format: "%02X", $0) },
			toPrintable: { String(format: "%02X", $0) },
			toQuoted: { String(format: "%02X", $0) },
		),
		Charset(
			id: "UTF-8",
			label: "UTF-8 / ASCII",
			toString: { String(UnicodeScalar($0)!) },
			toPrintable: { char in
				if(char <= 0x20) {
					String(UnicodeScalar(0x2400 + char)!)
				} else if (char >= 0x21 && char <= 0x7E) {
					String(UnicodeScalar(char)!)
				} else {
					"x\(String(format: "%02X", Int(char)))"
				}
			},
			toQuoted: { char in
				if(char <= 0x20) {
					String(UnicodeScalar(0x2400 + char)!)
				} else if (char == 0x21) {
					"\"!\""
				} else if (char == 0x22) {
					"'" + String(UnicodeScalar(char)!) + "'"
				} else if (char >= 0x23 && char <= 0x7E) {
					"\"" + String(UnicodeScalar(char)!) + "\""
				}  else if (char == 0x7F) {
					"\u{2421}"
				} else {
					"U+\(String(format: "%04X", Int(char)))"
				}
			},
		),
		// TODO: Add UTF-16
		// Display surrogate code points with a syntax like [D800xDC00]
		Charset(
			id: "UTF-32",
			label: "UTF-32 / Unicode",
			toString: { String(UnicodeScalar($0)!) },
			toPrintable: { char in
				if(char <= 0x20) {
					String(UnicodeScalar(0x2400 + char)!)
				} else if (char >= 0x21 && char <= 0x7E) {
					String(UnicodeScalar(char)!)
				} else {
					"U+\(String(format: "%04X", Int(char)))"
				}
			},
			toQuoted: { char in
				if(char <= 0x20) {
					String(UnicodeScalar(0x2400 + char)!)
				} else if (char == 0x21) {
					"\"!\""
				} else if (char == 0x22) {
					"'" + String(UnicodeScalar(char)!) + "'"
				} else if (char >= 0x23 && char <= 0x7E) {
					"\"" + String(UnicodeScalar(char)!) + "\""
				}  else if (char == 0x7F) {
					"\u{2421}"
				} else {
					"U+\(String(format: "%04X", Int(char)))"
				}
			},
		),
	];
	static let charsetDict: Dictionary<String, Charset> = Dictionary(uniqueKeysWithValues: charsets.map { ($0.id, $0) });

	init(){
		catalog = Self.getCatalog()
		userDocumentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user")
		userDocumentsWatcher = DirectoryWatcher(url: userDocumentsDirectory!)
		userDocumentsWatcher.onChange = { [weak self] in
			Task { @MainActor in
				self?.reloadUser()
			}
		}
		self.reloadUser()
		try! userDocumentsWatcher.start()
	}

	private func reloadUser() {
		guard let userDocumentsDirectory else { return }
		do {
			try FileManager.default.createDirectory(at: userDocumentsDirectory, withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("Error creating folder <\(userDocumentsDirectory)>: \(error)")
		}
		let contents: [URL]
		do {
			print("contentsOfDirectory: \(userDocumentsDirectory)");
			contents = try FileManager.default.contentsOfDirectory(at: userDocumentsDirectory, includingPropertiesForKeys: [])
		} catch {
			contents = []
		}

		// Build a map of every valid file currently on disk (keyed by its stable filepath)
		// TODO: keep the UUID the same, if it was merely renamed, to keep it selected
		var updated_path_id: [URL: UUID] = [:]
		for filepath in contents {
			let filename = filepath.pathComponents.last!;
			print("Read: \(filename)");
			let components = filename.split(separator: ".");
			guard
				components.count > 1,
				let ext = components.last,
				let type = MainAppModel.extensionsType["."+String(ext)]
			else { print("Ignore \(filepath)"); continue; }

			if let item = CatalogListItem(filepath: filepath) {
				// Add any items that don't already exist
				if user_filepath_id[filepath] == nil {
					print("Add \(filename)");
					user[item.id] = item;
					user_filepath_id[item.filepath] = item.id;
				}
				updated_path_id[filepath] = item.id;
			}
		}

		// Remove any items in `user` whose corresponding file no longer exists on disk
		for old_item in user.values {
			if updated_path_id[old_item.filepath] == nil {
				print("Remove \(old_item.filepath.pathComponents.last!)");
				// Will return even if the key does not exist
				user.removeValue(forKey: old_item.id);
				user_filepath_id.removeValue(forKey: old_item.filepath);
			}
		}

		userSorted = user.values.sorted();
	}

	func put(_ document: CatalogListItem) {
		let oldFilepath = user[document.id]?.filepath;
		user[document.id] = document
		user_filepath_id[document.filepath] = document.id
		print(document)
		// Try to save this document to storage
		let userDocumentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user")
		// Create a storage directory if it doesn't exist
		do {
			try FileManager.default.createDirectory(at: userDocumentsDirectory, withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("Error creating folder <\(userDocumentsDirectory)>: \(error)")
		}
		// If the name changed, assign the new filepath
		let ext = MainAppModel.typeExtensions[document.type] ?? ".txt"
		let filepath = userDocumentsDirectory.appendingPathComponent(document.name + ext)
		do {
			if let oldFilepath, oldFilepath != filepath {
				print("move", oldFilepath, " -> ", filepath);
				// Name changed, rename the file
				try FileManager.default.moveItem(at: oldFilepath, to: filepath)
			} else if oldFilepath == nil, FileManager.default.fileExists(atPath: filepath.path) == false {
				try Data().write(to: filepath, options: [.atomic])
			}
		} catch {
			// Use old name
			//			document.name = user[document.id]!.name
			print("Error writing file <\(filepath)>: \(error.localizedDescription)")
		}
		userSorted = user.values.sorted()
	}

	func del(_ document: CatalogListItem) {
		let oldFilepath = document.filepath;
		do {
			try FileManager.default.trashItem(at: oldFilepath, resultingItemURL: nil)
		} catch {
			print(error.localizedDescription)
		}
		user.removeValue(forKey: document.id)
		user_filepath_id.removeValue(forKey: document.filepath)
		userSorted = user.values.sorted()
	}

	static private func getCatalog() -> Array<CatalogListItem> {
		guard let bundlePath = Bundle.main.resourcePath else { return [] }
		do {
			let fileManager = FileManager.default
			let textDirectory = bundlePath + "/catalog"
			let contents = try fileManager.contentsOfDirectory(atPath: textDirectory)
			var loadedFiles: Array<CatalogListItem> = [];
			for filename in contents {
				let components = filename.split(separator: ".")
				if components.count > 1, let ext = components.last, let type = MainAppModel.extensionsType["."+String(ext)] {
					let filepath = URL(fileURLWithPath: textDirectory + "/" + filename)
					let document = CatalogListItem(filepath: filepath)!;
					loadedFiles.append(document);
				} else {
					print("Ignoring extension of \(filename)");
				}
			}
			return loadedFiles.sorted { $0.name < $1.name }
		} catch {
			print("Error loading files: \(error)")
		}
		return [];
	}
}

protocol DocumentProtocol: LanguageSource, Hashable {
	var id: UUID {get}
	var filepath: URL? {get set}
	var name: String {get set}
	var type: String {get}
	/// The interpertation of the symbols fed as input
	var charset: String {get set}

	// - rule list: for debugging subrules (get list of rule names, enumerate groups in regular expresions, etc)
	// 	- select which sub expression to export as a regular expression, test for input, etc
	//		- get a list of rules that can be referenced by other grammars (even of other types)
	// - unresolved references: Get list of external rules in other grammars that need to be dereferenced to use the grammar
	// - toCFG: get the specified rule as a CFG, if possible
	// - toFSM: get the specified rule as a FSM, if possible
	// - editor view: A View that can be used to edit the grammar (e.g. a code editor for ABNF)
	// - CFG export options view: A View that specifies how to convert the source grammar to a CFG (e.g. tail recursion technique to use, case sensitive)
 	associatedtype RuleInfoView: RuleInfoViewBody, View where RuleInfoView.Document == Self;
	associatedtype EditorView: EditorViewBody, View where EditorView.Document == Self;
}

extension DocumentProtocol {
	func ruleInfoView(document: Binding<Self>, rule: RuleAnalysis) -> RuleInfoView {
		RuleInfoView(document: document, rule: rule)
	}
	func editorView(document: Binding<Self>, computed: RulelistAnalysis) -> EditorView {
		EditorView(document: document, computed: computed)
	}
}

/// A grammar definition that can snapshot itself onto a ``RulelistAnalysis``
/// and compile a named rule onto a ``RuleAnalysis``.
protocol LanguageSource {
	/// Snapshot this definition and publish document-level analysis onto `parser`.
	/// Rule names must be written first (and independently of compiled-rule artifacts).
	func updateParser(_ parser: RulelistAnalysis)

	/// Compile `ruleName` and publish artifacts onto `rule`.
	/// Uses the last successful parse on `list` (does not re-parse). No-ops if `rule` was
	/// already compiled from the current parse snapshot. `list` is also used by notebooks to find the owning page.
	func compileRule(_ ruleName: String, from list: RulelistAnalysis, into rule: RuleAnalysis)
}

/// Document-level analysis: parse errors and the set of rule names.
///
/// `nil` means the property has not been computed or cannot be computed (see error if any).
/// A failed parse sets ``document_error`` and leaves the last successful parse in place.
@Observable
final class RulelistAnalysis {
	var document_error: String? = nil
	/// Zero-based line of a syntax error, when the source is line-oriented.
	var content_parseErrorLine: Int? = nil

	/// Default rule to pick from this rule list
	var primaryRuleName: String? = nil
	/// All rules intended for export (reference from outside)
	var topRuleNames: Array<String> = []
	/// All rules this grammar uses (for reference from inside)
	var allRuleNames: Array<String> = []
	/// Direct references of each defined rule, in first-seen order (including locals, imports, and builtins).
	var referencedRuleNames: Dictionary<String, Array<String>> = [:]

	/// Last successful parse payload (LanguageSource-specific). Unchanged when parse fails.
	var parsedSource: Any? = nil
	/// Bumped when a successful parse replaces the snapshot. Compile records this on ``RuleAnalysis/compiledRevision``.
	var parseRevision: Int = 0

	/// Nested parsers for NoteDocument
	var nested: Dictionary<UUID, RulelistAnalysis> = [:]

	private var _parseTask = Task<Void, Never> {}

	deinit { _parseTask.cancel() }

	/// Cancel any in-flight parse and run `body` as the sole document-level update.
	/// `body` should hop to the main actor to publish fields.
	func runUpdate(_ body: @escaping () async -> Void) {
		_parseTask.cancel();
		_parseTask = Task { await body() };
	}

	/// Last successful parse as `T`, or `nil` if no snapshot has been stored yet.
	func parsed<T>(_ type: T.Type) -> T? {
		guard let parsedSource else { return nil; }
		guard let value = parsedSource as? T else {
			assertionFailure("RulelistAnalysis.parsedSource is \(Swift.type(of: parsedSource)), expected \(T.self)");
			return nil;
		}
		return value;
	}
}

/// Artifacts for one compiled rule.
///
/// `nil` means the property has not been computed or cannot be computed (see ``error`` if any).
@Observable
final class RuleAnalysis {
	var rulename: String? = nil
	var error: String? = nil

	var dependencies: Array<String> = []
	var builtins: Array<String> = []
	var undefined: Array<String> = []
	var recursive: Array<String> = []

	var alphabet: ClosedRangeAlphabet<UInt32>? = nil
	var fsm: DFA<ClosedRangeAlphabet<UInt32>>? = nil
	var cfg: ABNFRulelist<UInt32>.CFG? = nil
	var cfga: CFGArray<ClosedRangeAlphabet<UInt32>>? = nil
	var rr: RailroadNode? = nil
	var complexityClass: Int? = nil
	var chomskyClass: Int? = nil
	var memoryRequirements: Int? = nil

	/// ``RulelistAnalysis/parseRevision`` this compile was produced from.
	var compiledRevision: Int? = nil

	private var _compileTask = Task<Void, Never> {}

	deinit { _compileTask.cancel() }

	/// Compile `ruleName` from `list`'s current snapshot, or no-op if this object already holds that result.
	/// Same-rule recompile keeps previous artifacts until `body` publishes. `body` receives the snapshot
	/// revision and should set ``compiledRevision`` when it finishes.
	func runCompile(ruleName: String, from list: RulelistAnalysis, _ body: @escaping (_ revision: Int) async -> Void) {
		let revision = list.parseRevision;
		if rulename == ruleName && compiledRevision == revision { return }
		let replacing = rulename != ruleName;
		_compileTask.cancel();
		if replacing {
			reset(ruleName: ruleName);
		} else {
			rulename = ruleName;
		}
		_compileTask = Task { await body(revision) };
	}

	/// Drop artifacts so the UI does not show a stale rule.
	func reset(ruleName: String?) {
		rulename = ruleName;
		error = nil;
		dependencies = [];
		builtins = [];
		undefined = [];
		recursive = [];
		alphabet = nil;
		fsm = nil;
		cfg = nil;
		cfga = nil;
		rr = nil;
		complexityClass = nil;
		chomskyClass = nil;
		memoryRequirements = nil;
		compiledRevision = nil;
	}
}

protocol RuleInfoViewBody: View {
	associatedtype Document: DocumentProtocol
	init(document: Binding<Document>, rule: RuleAnalysis)
}

protocol EditorViewBody: View {
	associatedtype Document: DocumentProtocol
	init(document: Binding<Document>, computed: RulelistAnalysis)
}

extension FocusedValues {
	@Entry var isImportingRFCXML: Binding<Bool>?
}

