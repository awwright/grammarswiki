import SwiftUI
import FSM
import LanguageSupport

struct FileType {
	let label: String
	let fileExtension: String
	let languageConfiguration: LanguageConfiguration
	let parser: (String) throws -> ABNFRulelist<UInt32> // nil for no parsing
}

@main
struct ABNFEditorApp: App {
	@State private var model = AppModel()
	var body: some Scene {
		WindowGroup {
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
		),
		FileType(
			label: "Regex (ECMAScript)",
			fileExtension: ".js",
			languageConfiguration: LanguageConfiguration.swift(), // FIXME: Swift is pretty close, but this can be adjusted
			parser: { text in
				let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
				return try ABNFRulelist<UInt32>.parse(input)
			},
		),
		FileType(
			label: "Regex (Swift)",
			fileExtension: ".swift",
			languageConfiguration: LanguageConfiguration.swift(),
			parser: { text in
				let input = Array(text.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
				return try ABNFRulelist<UInt32>.parse(input)
			},
		),
	]
 	static let typeExtensions: [String: String] = Dictionary(uniqueKeysWithValues: fileTypes.map { ($0.label, $0.fileExtension) })
 	static let extensionsType: [String: String] = Dictionary(uniqueKeysWithValues: fileTypes.map { ($0.fileExtension, $0.label) })

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
				let newDocument = DocumentItem(filepath: filePath, name: name, type: type, content: content)
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
					let document = DocumentItem(filepath: filepath, name: name, type: type, content: content)
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
	var content: String

	init(filepath: URL?, name: String, type: String, content: String) {
		self.filepath = filepath
		self.name = name
		self.type = type
		self.content = content
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	static func == (lhs: DocumentItem, rhs: DocumentItem) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.content == rhs.content && lhs.type == rhs.type
	}
}
