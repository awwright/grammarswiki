import SwiftUI
import FSM
import LanguageSupport
import UniformTypeIdentifiers

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
struct ABNFEditorApp: App {
	@NSApplicationDelegateAdaptor var appdelegate: AppDelegate
	class AppDelegate: NSObject, NSApplicationDelegate {
		@Environment(\.openWindow)
		var openWindow
		func applicationDidFinishLaunching(_ notification: Notification) {
			DispatchQueue.main.async {
				// This is the function that's run when someone clicks (launches) the application icon, even if it's already running
				// Ensure that the Catalog is the first window open, if no other window is open.
				// If this isn't done now, then macOS will use the first listed View, and the the file selection dialog will open up.
				if let window = NSApp.windows.filter({ $0.identifier?.rawValue == "Catalog" }).first {
					// Usually because there's windows restored from a previous session, or the app is already open
					window.makeKeyAndOrderFront(self)
				} else {
					self.openWindow(id: "Catalog")
				}
			}
		}
	}

	@State private var model = AppModel()
	var body: some Scene {
		// The DocumentGroup is listed first so that it gets the keyboard shortcuts for New, Save, Open
		DocumentGroup(newDocument: DocumentItemDocument()) { file in
			DocumentEditor(document: .constant(file.document))
		}
		Window("Catalog", id: "Catalog") {
			ContentView(model: model)
		}
		Settings {
			SettingsView()
		}
	}
}

class AppModel: ObservableObject {
	@Published var user: [UUID: DocumentItem] = [:]
	let catalog: [DocumentItem]

	static let fileTypes: [FileType] = [
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
		reloadUser()
	}

	private func reloadUser() {
		let userDocumentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user")
		do {
			try FileManager.default.createDirectory(at: userDocumentsDirectory, withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("Error creating folder <\(userDocumentsDirectory)>: \(error)")
		}
		let contents: [String];
		do {
			contents = try FileManager.default.contentsOfDirectory(atPath: userDocumentsDirectory.path())
		} catch {
			contents = []
		}
		for filename in contents {
			let components = filename.split(separator: ".")
			if components.count > 1, let ext = components.last, let type = AppModel.extensionsType["."+String(ext)] {
				print("\tLoading \(filename) -> \(type)");
				let name = components.dropLast().joined(separator: ".")
				let filePath = userDocumentsDirectory.appendingPathComponent(filename)
				let content = try! String(contentsOf: filePath, encoding: .utf8)
				let newDocument = DocumentItem(filepath: filePath, name: name, type: type, charset: "UTF-32", content: content)
				user[newDocument.id] = newDocument
			} else {
				print("Ignoring extension of \(filename)");
			}
		}
	}

	func addDocument(_ document: DocumentItem) {
		user[document.id] = document
		print(document)
		let oldFilepath = document.filepath
		// Try to save this document to storage
		let userDocumentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user")
		// Create a storage directory if it doesn't exist
		do {
			try FileManager.default.createDirectory(at: userDocumentsDirectory, withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("Error creating folder <\(userDocumentsDirectory)>: \(error)")
		}
		// If the name changed, assign the new filepath
		let ext = AppModel.typeExtensions[document.type] ?? ".txt"
		let filepath = userDocumentsDirectory.appendingPathComponent(document.name + ext)
		do {
			if let oldFilepath, oldFilepath != filepath {
				print("move", oldFilepath, " -> ", filepath);
				// Name changed, rename the file
				try FileManager.default.moveItem(at: oldFilepath, to: filepath)
			}
			let data = Data(document.content.utf8);
			try data.write(to: filepath, options: [.atomic, .completeFileProtection])
			document.filepath = filepath
		} catch {
			// Use old name
			//			document.name = user[document.id]!.name
			print("Error writing file <\(filepath)>: \(error.localizedDescription)")
		}
	}

	func delDocument(_ document: DocumentItem) {
		if let oldFilepath = document.filepath {
			do {
				try FileManager.default.removeItem(at: oldFilepath)
			} catch {
				print(error.localizedDescription)
			}
		}
		user.removeValue(forKey: document.id)
	}

	static private func getCatalog() -> Array<DocumentItem> {
		guard let bundlePath = Bundle.main.resourcePath else { return [] }
		do {
			let fileManager = FileManager.default
			let textDirectory = bundlePath + "/catalog"
			let contents = try fileManager.contentsOfDirectory(atPath: textDirectory)
			var loadedFiles: [DocumentItem] = []
			for filename in contents {
				let components = filename.split(separator: ".")
				if components.count > 1, let ext = components.last, let type = AppModel.extensionsType["."+String(ext)] {
					let name = components.dropLast().joined(separator: ".")
					let filePath = textDirectory + "/" + filename
					let content = try String(contentsOfFile: filePath, encoding: .utf8)
					let filepath = URL(fileURLWithPath: filePath)
					let document = DocumentItem(filepath: filepath, name: name, type: type, charset: "UTF-32", content: content)
					loadedFiles.append(document)
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

// Model to represent a text file
@Observable class DocumentItem: Identifiable, Hashable, Equatable {
	let id = UUID()
	var filepath: URL?
	var name: String
	var type: String
	var charset: String
	var content: String

	init(filepath: URL?, name: String, type: String, charset: String, content: String) {
		self.filepath = filepath
		self.name = name
		self.type = type
		self.content = content
		self.charset = charset
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	static func == (lhs: DocumentItem, rhs: DocumentItem) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.content == rhs.content && lhs.type == rhs.type
	}

	func duplicate() -> DocumentItem {
		DocumentItem(filepath: nil, name: name + " Copy", type: type, charset: charset, content: content)
	}
}

// TODO: This should be a wrapper around DocumentItem
struct DocumentItemDocument: FileDocument {
	var text: String

	init(text: String = "") {
		self.text = text
	}

	static var readableContentTypes: [UTType] { [.grammarsDoc] }

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		text = String(decoding: data, as: UTF8.self)
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = Data(text.utf8)
		return .init(regularFileWithContents: data)
	}
}
