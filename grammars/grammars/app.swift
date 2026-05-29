import SwiftUI
import FSM
import LanguageSupport
import UniformTypeIdentifiers

// TODO: Automatically update file list from filesystem events
// TODO: Add DocumentProtocol to Document that outlines methods like:
// TODO: Implement CFG methods for chomsky normal form, greibach normal form
// TODO: List parse forest productions/alternatives in same order as the original grammar does
// TODO: Add RegexDocument to import regular expressions as a grammar
// TODO: Add JSONSchemaDocument to import a JSON Schema as a grammar
// TODO: Add NotebookDocument to edit a mixture of all of these documents
// TODO: Add RFC XML Document (reads ABNF code inside RFC XML)

extension UTType {
	static var grammarsDoc = UTType(exportedAs: "name.awwright.grammars.doc")
}

struct FileType {
	let label: String
	let fileExtension: String
	let languageConfiguration: LanguageConfiguration
	let parser: (String) throws -> ABNFRulelist<UInt32> // nil for no parsing
	let toRailroad: ((ABNFRulelist<UInt32>, String) throws -> RailroadNode)?
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

@main
struct MainApp: App {
	@State private var model = MainAppModel()
	var body: some Scene {
		// The DocumentGroup is listed first so that it gets the keyboard shortcuts for New, Save, Open
		DocumentGroup(newDocument: Document()) { file in
			DocumentView(document: file.$document);
		}
		Window("Catalog", id: "Catalog") {
			CatalogView(model: model)
		}.defaultLaunchBehavior(.presented)
		Settings {
			SettingsView()
		}
	}
}

class MainAppModel: ObservableObject {
	@Published var user: [UUID: CatalogListItem] = [:]
	@Published var user_filepath_id: [URL: UUID] = [:]
	@Published var userSorted: Array<CatalogListItem> = []
	// You could also watch the catalog directory, but it's usually embedded inside the app bundle and isn't going to change
	let catalog: Array<CatalogListItem>
	let userDocumentsDirectory: URL?
	let userDocumentsWatcher: DirectoryWatcher

	static let fileTypes: [FileType] = [
		FileType(
			label: "Syntax/Formal Grammar Notebook",
			fileExtension: ".sfgnb",
			languageConfiguration: LanguageConfiguration(
				name: "Plain",
				supportsSquareBrackets: true,
				supportsCurlyBrackets: false,
				stringRegex: nil,
				characterRegex: nil,
				numberRegex: nil,
				singleLineComment: "//",
				nestedComment: nil,
				identifierRegex: nil,
				operatorRegex: nil,
				reservedIdentifiers: [],
				reservedOperators: [],
			),
			parser:  { _ in return ABNFRulelist<UInt32>.init() },
			toRailroad: nil,
		),
		FileType(
			label: "Plain text",
			fileExtension: ".txt",
			languageConfiguration: LanguageConfiguration(
				name: "Plain",
				supportsSquareBrackets: true,
				supportsCurlyBrackets: false,
				stringRegex: nil,
				characterRegex: nil,
				numberRegex: nil,
				singleLineComment: "//",
				nestedComment: nil,
				identifierRegex: nil,
				operatorRegex: nil,
				reservedIdentifiers: [],
				reservedOperators: [],
			),
			parser:  { _ in return ABNFRulelist<UInt32>.init() },
			toRailroad: nil,
		),
		FileType(
			label: "ABNF",
			fileExtension: ".abnf",
			languageConfiguration: LanguageConfiguration(
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
			parser: { text in
				let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
				return try ABNFRulelist<UInt32>.parse(input)
			},
			toRailroad: {
				content_rulelist, selectedRule in
				let dictionary = content_rulelist.dictionary;
				guard let rule = dictionary[selectedRule] else { fatalError() }
				return rule.toRailroad(rules: dictionary.mapValues { $0.alternation });
			},
		),
		FileType(
			label: "Regex (ECMAScript)",
			fileExtension: ".js",
			languageConfiguration: LanguageConfiguration.swift(), // FIXME: Swift is pretty close, but this can be adjusted
			parser: { text in
				let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
				return try ABNFRulelist<UInt32>.parse(input)
			},
			toRailroad: nil,
		),
		FileType(
			label: "Regex (Swift)",
			fileExtension: ".swift",
			languageConfiguration: LanguageConfiguration.swift(),
			parser: { text in
				let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
				return try ABNFRulelist<UInt32>.parse(input)
			},
			toRailroad: nil,
		),
	];
	static let typeExtensions: [String: String] = Dictionary(uniqueKeysWithValues: fileTypes.map { ($0.label, $0.fileExtension) })
	static let extensionsType: [String: String] = Dictionary(uniqueKeysWithValues: fileTypes.map { ($0.fileExtension, $0.label) })

	static let charsets: [Charset] = [
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
	// - rule list: for debugging subrules (get list of rule names, enumerate groups in regular expresions, etc)
	// 	- select which sub expression to export as a regular expression, test for input, etc
	//		- get a list of rules that can be referenced by other grammars (even of other types)
	// - unresolved references: Get list of external rules in other grammars that need to be dereferenced to use the grammar
	// - toCFG: get the specified rule as a CFG, if possible
	// - toFSM: get the specified rule as a FSM, if possible
	// - editor view: A View that can be used to edit the grammar (e.g. a code editor for ABNF)
	// - CFG export options view: A View that specifies how to convert the source grammar to a CFG (e.g. tail recursion technique to use, case sensitive)

	//associatedtype SettingsView: View;
	//var settings: SettingsView { get }
	//
	//associatedtype EditorView: View;
	//var editor: EditorView {get}
}

// Model to represent a text file
struct Document: Hashable, Equatable, FileDocument {
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
}
