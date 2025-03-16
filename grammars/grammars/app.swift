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
	let catalog: [DocumentItem]

	init(){
		user = Self.getUser()
		catalog = Self.getCatalog()
	}

	func addDocument(_ document: DocumentItem) {
		user[document.id] = document
	}

	static private func getUser() -> Dictionary<UUID, DocumentItem> {
		return [:]
	}

	static private func getCatalog() -> Array<DocumentItem> {
		guard let bundlePath = Bundle.main.resourcePath else { return [] }
		let fileExtension = ".abnf"

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
struct DocumentItem: Identifiable, Hashable, Equatable {
	let id = UUID()
	var name: String
	var content: String
}
