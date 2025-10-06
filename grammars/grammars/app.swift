import SwiftUI
import LanguageSupport

struct FileType {
    let label: String
    let fileExtension: String
    let languageConfiguration: LanguageConfiguration
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
	@Published var filepaths: [UUID: URL] = [:]
	let catalog: [DocumentItem]

	static let fileTypes: [FileType] = [
		FileType(label: "Plain text", fileExtension: ".txt", languageConfiguration: LanguageConfiguration(
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
			reservedOperators: []
		)),
		FileType(label: "ABNF", fileExtension: ".abnf", languageConfiguration: LanguageConfiguration(
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
			reservedOperators: []
		)),
		FileType(label: "Regex (ECMAScript)", fileExtension: ".js", languageConfiguration: LanguageConfiguration(
			name: "ECMAScript",
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
			reservedOperators: []
		)),
		FileType(label: "Regex (Swift)", fileExtension: ".swift", languageConfiguration: LanguageConfiguration(
			name: "Swift",
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
			reservedOperators: []
		)),
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
				let newDocument = DocumentItem(name: name, type: type, content: content)
				addDocument(newDocument)
			} else {
				print("Ignoring extension of \(filename)");
			  }
		}
	}

	func addDocument(_ document: DocumentItem) {
		user[document.id] = document
		print(document)
		let oldFilepath = filepaths[document.id]
		// Try to save this document to storage
		let userDocumentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user")
		// Create a storage directory if it doesn't exist
		do {
			try FileManager.default.createDirectory(at: userDocumentsDirectory, withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("Error creating folder <\(userDocumentsDirectory)>: \(error)")
		}
		// Figure out if we need to rename the file
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
			filepaths[document.id] = filepath
		} catch {
			// Use old name
//			document.name = user[document.id]!.name
			print("Error writing file <\(filepath)>: \(error.localizedDescription)")
		}
	}

	func delDocument(_ document: DocumentItem) {
		let oldFilepath = filepaths[document.id]
		if let oldFilepath {
			do {
				try FileManager.default.removeItem(at: oldFilepath)
			} catch {
				print(error.localizedDescription)
			}
		}
		user.removeValue(forKey: document.id)
		filepaths.removeValue(forKey: document.id)
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
					loadedFiles.append(DocumentItem(name: name, type: type, content: content))
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
	var name: String
	var type: String
	var content: String

	init(name: String, type: String, content: String) {
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
