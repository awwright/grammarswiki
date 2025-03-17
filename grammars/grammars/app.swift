import SwiftUI

@main
struct ABNFEditorApp: App {
	@State private var model = AppModel()
	var body: some Scene {
		WindowGroup {
			ContentView(model: $model)
		}
	}
}

class AppModel {
	var user: [UUID: DocumentItem]
	var filepaths: [UUID: URL]
	let catalog: [DocumentItem]

	static let fileExtension = ".abnf"

	init(){
		user = [:]
		filepaths = [:]
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
			if filename.hasSuffix(AppModel.fileExtension) {
				let filePath = userDocumentsDirectory.appendingPathComponent(filename)
				// Remove fileExtension from the end of filename
				let name = filename.hasSuffix(AppModel.fileExtension) ? String(filename.dropLast(AppModel.fileExtension.count)) : filename
				let content = try! String(contentsOf: filePath, encoding: .utf8)
				let newDocument = DocumentItem(name: name, content: content)
				addDocument(newDocument)
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
		let filepath = userDocumentsDirectory.appendingPathComponent(document.name + AppModel.fileExtension)
		do {
			if let oldFilepath, oldFilepath != filepath {
				print("move", oldFilepath, " -> ", filepath);
				// Name changed, rename the file
				try FileManager.default.moveItem(at: oldFilepath, to: filepath)
			}
//			print("write", filepath);
//			let data = Data(document.content.utf8);
//			try data.write(to: filepath, options: [.atomic, .completeFileProtection])
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
				if filename.hasSuffix(fileExtension) {
					let filePath = textDirectory + "/" + filename
					let content = try String(contentsOfFile: filePath, encoding: .utf8)
					loadedFiles.append(DocumentItem(name: filename, content: content))
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
	var content: String

	init(name: String, content: String) {
		self.name = name
		self.content = content
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	static func == (lhs: DocumentItem, rhs: DocumentItem) -> Bool {
		lhs.id == rhs.id && lhs.name == rhs.name && lhs.content == rhs.content
	}
}
