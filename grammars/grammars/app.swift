import SwiftUI
import FSM
import LanguageSupport
import UniformTypeIdentifiers

// TODO: Implement CFG methods for chomsky normal form, greibach normal form
// TODO: List parse forest productions/alternatives in same order as the original grammar does
// TODO: Add RegexDocument to import regular expressions as a grammar
// TODO: Add JSONSchemaDocument to import a JSON Schema as a grammar
// TODO: Add NotebookDocument to edit a mixture of all of these documents
// TODO: Add RFC XML Document (reads ABNF code inside RFC XML)

extension UTType {
	static var grammarsDoc = UTType(exportedAs: "name.awwright.grammars.doc")
}

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
	var body: some Scene {
		// The DocumentGroup is listed first so that it gets the keyboard shortcuts for New, Save, Open
		DocumentGroup(newDocument: ABNFDocument()) { file in
			DocumentView<ABNFDocument>(document: file.$document)
		}
		Window("Catalog", id: "Catalog") {
			CatalogView(model: model)
		}.defaultLaunchBehavior(.presented)
		Settings {
			SettingsView()
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
			}
		} catch {
			// Use old name
			//			document.name = user[document.id]!.name
			print("Error writing file <\(filepath)>: \(error.localizedDescription)")
		}
	}

	func del(_ document: CatalogListItem) {
		let oldFilepath = document.filepath;
		do {
			try FileManager.default.removeItem(at: oldFilepath)
		} catch {
			print(error.localizedDescription)
		}
		user.removeValue(forKey: document.id)
		user_filepath_id.removeValue(forKey: document.filepath)
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

protocol DocumentProtocol {
	var id: UUID {get}
	var filepath: URL? {get set}
	var name: String {get set}
	var type: String {get set}
	/// The interpertation of the symbols fed as input
	var charset: String {get set}
	var content: String {get set}

	/// Convert this grammar to an ABNFRulelist
	/// (mostly for when the source is already an ABNF document)
	func toABNFRulelist() throws -> ABNFRulelist<UInt32>

	// - rule list: for debugging subrules (get list of rule names, enumerate groups in regular expresions, etc)
	// 	- select which sub expression to export as a regular expression, test for input, etc
	//		- get a list of rules that can be referenced by other grammars (even of other types)
	// - unresolved references: Get list of external rules in other grammars that need to be dereferenced to use the grammar
	// - toCFG: get the specified rule as a CFG, if possible
	// - toFSM: get the specified rule as a FSM, if possible
	// - editor view: A View that can be used to edit the grammar (e.g. a code editor for ABNF)
	// - CFG export options view: A View that specifies how to convert the source grammar to a CFG (e.g. tail recursion technique to use, case sensitive)
	associatedtype EditorView: EditorViewBody, View where EditorView.Document == Self;

	/// Computes properties of the grammar used by DocumentWindow
	associatedtype Parser: DocumentParserProtocol where Parser.Document == Self;
}

extension DocumentProtocol {
	func editorView(document: Binding<Self>, computed: Parser) -> EditorView {
		EditorView(document: document, computed: computed)
	}
}

protocol DocumentParserProtocol {
	associatedtype Document: DocumentProtocol
	init()

	var document: Document? {get set}
	var document_error: String? {get}
	var asABNFRulelist: ABNFRulelist<UInt32>? {get}
	/// The "top level" rule that should be loaded by default, typically the first listed rule
	var primaryRuleName: String? {get}
	/// Rules designed to be used/referenced externally
	var topRuleNames: Array<String> {get}
	/// All rule names, including those for internal use
	var allRuleNames: Array<String> {get}

	var selectedRulename: String? {get set}
	var selectedRule_error: String? {get}

	//var selectedRule_dependencies: Array<String> {get}
	//var selectedRule_builtins: Array<String> {get}
	//var selectedRule_undefined: Array<String> {get}
	//var selectedRule_recursive: Array<String> {get}
	var selectedRule_alphabet: ClosedRangeAlphabet<UInt32>? {get}
	var selectedRule_fsm: DFA<ClosedRangeAlphabet<UInt32>>? {get}
	var selectedRule_cfg: ABNFRulelist<UInt32>.CFG? {get}
	var selectedRule_rr: RailroadNode? {get}
	var selectedRule_complexityClass: Int? {get}
	var selectedRule_chomskyClass: Int? {get}
	var selectedRule_memoryRequirements: Int? {get}
}

//protocol SettingsViewBody: View {
//	@ViewBuilder var document: Binding<Document> {get}
//}
protocol EditorViewBody: View {
	associatedtype Document: DocumentProtocol
	init(document: Binding<Document>, computed: Document.Parser)
}
