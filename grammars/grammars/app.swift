import SwiftUI

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

	static let fileExtension = ".abnf"
	static let typeExtensions: [String: String] = [
		"Plain text": ".txt",
		"ABNF": ".abnf",
		"EBNF": ".ebnf",
		"Regex (ECMAScript)": ".js",
		"Regex (Swift)": ".swift",
		"Regex (POSIX-e)": ".posix"
	]
	static let extensionsType: [String: String] = Dictionary(uniqueKeysWithValues: typeExtensions.map { ($0.value, $0.key) })

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
