import SwiftUI

@main
struct ABNFEditorApp: App {
	static var catalog: Array<DocumentItem> = {
		guard let bundlePath = Bundle.main.resourcePath else { return [] }
		print(bundlePath)
		let fileExtension = ".abnf"

		do {
			let fileManager = FileManager.default
			let textDirectory = bundlePath + "/catalog" // Assumes a "TextFiles" directory
			let contents = try fileManager.contentsOfDirectory(atPath: textDirectory)

			var loadedFiles: [DocumentItem] = []

			for filename in contents {
				print(filename)
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
	}()

	var body: some Scene {
		WindowGroup {
			ContentView(catalog: Self.catalog)
		}
	}
}

// Model to represent a text file
struct DocumentItem: Identifiable, Hashable, Equatable {
	let id = UUID()
	let name: String
	var content: String
}
