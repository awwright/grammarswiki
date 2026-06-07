import SwiftUI

/// Forms the body of the Catalog window
struct CatalogView: View {
	var model: MainAppModel
	@State private var selectionId: UUID? = nil

	var body: some View {
		NavigationSplitView {
			// This list shows .abnf files in two directories, each in a separate section.
			// Files in the user directory are edited in place.
			// Files in the system directory are duplicated to the user directory on write.
			// Files in the user directory can be deleted, which should select the item above, or deselect the item.
			// Files in the user directory can be renamed.
			// The filesystem is watched for changes, which reloads the changed files.
			// A file with a known inode and a new filename is a rename or a hard link.
			// A filename with a new inode and a known filename should be treated as an edit to the same file (usually an atomic write-and-replace).
			// TODO: Offer search and sort by last-modified time
			List(selection: $selectionId) {
				if model.user.values.isEmpty == false {
					Section("Saved") {
						ForEach(model.userSorted, id: \.id) {
							document in
							CatalogListItemView(item: Binding(get: { document }, set: { model.put($0) }), onDelete: { self.selectionId = nil; model.del(document) }, onDuplicate: { let newDoc = document.duplicate(); model.put(newDoc); selectionId = newDoc.id; }, isEditable: true)
						}
					}
				}
				Section("Catalog") {
					ForEach(model.catalog, id: \.id) {
						document in
						CatalogListItemView(item: Binding(get: { document }, set: { let newDoc = $0.duplicate(); model.put(newDoc); selectionId = newDoc.id }), onDelete: {}, onDuplicate: { let newDoc = document.duplicate(); model.put(newDoc); selectionId = newDoc.id }, isEditable: false)
					}
				}
			}
			.navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 600)
			.toolbar {
				ToolbarItem {
					Button(action: addDocument) {
						// TODO: Consider "book.badge.plus" when macOS 26+ is required
						Label("Add", systemImage: "plus")
					}
				}
			}
		} detail: {
			if let selectionId {
				if let item = model.user[selectionId] {
					let binding = Binding<URL>(
						get: { item.filepath },
						set: { _ in },
					);
					CatalogDocumentView(fileURL: item.filepath, writeDir: model.userDocumentsDirectory!, selectedURL: binding)
				} else if let item = model.catalog.first(where: { $0.id == selectionId }) {
					let binding = Binding<URL>(
						get: { item.filepath },
						set: {
							// Save the new file to the user directory
							// Then change the selected file URL, the app model pick up on this and add it to the user collection
							if item.filepath != $0 {
								var newDocument = CatalogListItem(filepath: $0)!
								model.put(newDocument);
								self.selectionId = newDocument.id
							}
						}
					)
					CatalogDocumentView(fileURL: item.filepath, writeDir: model.userDocumentsDirectory!, selectedURL: binding)
				} else {
					StartView()
				}
			} else {
				StartView()
			}
		}
	}

 	func addDocument(){
 		withAnimation {
 			let newDocument = CatalogListItem(
				basepath: model.userDocumentsDirectory!,
 				name: "New Document \(model.user.count + 1)",
 				type: "ABNF",
 			)!;
 			model.put(newDocument)
 			selectionId = newDocument.id
 		}
 	}
}

/// Item in the sidebar for selecting, renaming, or deleting a grammar from the Catalog
struct CatalogListItem: Comparable {
	let id = UUID()
	var basepath: URL
	var name: String
	var type: String

	var filepath: URL {
		let filename = name + (MainAppModel.typeExtensions[type] ?? ".txt");
		return basepath.appending(path: filename, directoryHint: .notDirectory)
	}

	init?(filepath: URL) {
		let filename = filepath.pathComponents.last!
		let components = filename.split(separator: ".")
		if components.count > 1, let ext = components.last, let type = MainAppModel.extensionsType["."+String(ext)] {
			let name = components.dropLast().joined(separator: ".")
			self.basepath = filepath.deletingLastPathComponent()
			self.name = name
			self.type = type
		} else {
			return nil;
		}
	}

	init?(basepath: URL, name: String, type: String) {
		self.basepath = basepath;
		self.name = name;
		self.type = type;
	}

	func duplicate() -> Self {
		Self(basepath: basepath, name: name + " Copy", type: type)!
	}

	// Implement Comparable
	static func < (lhs: CatalogListItem, rhs: CatalogListItem) -> Bool {
		return lhs.filepath.absoluteString < rhs.filepath.absoluteString
	}
}

/// Item in the sidebar for selecting, renaming, or deleting a grammar from the Catalog
struct CatalogListItemView: View {
	@Binding var item: CatalogListItem
	let onDelete: () -> Void
	let onDuplicate: () -> Void
	let isEditable: Bool
	@State private var isRenaming: Bool = false
	@FocusState private var isFocused: Bool
	@State private var draftName: String = ""

	var body: some View {
		NavigationLink(value: item.id, label: {
			if isRenaming {
				HStack {
					TextField("Name", text: $draftName, onCommit: {
						if !draftName.isEmpty {
							item.name = draftName
						}
						isRenaming = false
						isFocused = false
					}).focused($isFocused)
				}
			} else {
				Text(item.name)
			}
		})
		.contextMenu {
			Button {
				let filepath = item.filepath
				// TODO: If file no longer exists, show an alert
				NSWorkspace.shared.selectFile(filepath.path, inFileViewerRootedAtPath: "")
			} label: {Text("Show in Finder")}
			Divider()
			if isEditable {
				RenameButton()
			}
			Button { onDuplicate() } label: {Text("Duplicate")}
			if isEditable {
				Divider()
				Button { onDelete() } label: {Text("Delete")}
			}
		}
		.renameAction {
			draftName = item.name
			isRenaming = true;
			isFocused = true;
		}
	}
}

/// Pull open the selected catalog item and display it using ``DocumentView``
struct CatalogDocumentView: View {
	/// The file being read from and written to
	let fileURL: URL
	/// The path where all files should be written
	let writeDir: URL
	/// A binding to modify the selected catalog item,
	/// in the event the user forks a builtin item to the user store.
	@Binding var selectedURL: URL

	@State private var document: ABNFDocument? = nil

	var body: some View {
		if let document {
			DocumentView(document: Binding(get: { document }, set: { self.document = $0; saveDocument(); }))
				.navigationTitle(document.name)
				.onAppear { loadDocument() }
				.onChange(of: fileURL) { loadDocument() }
				.id(fileURL)
		} else {
			DocumentView(document: .constant(ABNFDocument()))
				.onAppear { loadDocument() }
				.onChange(of: fileURL) { loadDocument() }
				.id(fileURL)
		}
	}

	private func loadDocument() {
		do {
			let name = fileURL.lastPathComponent;
			let content = try String(contentsOf: fileURL, encoding: .utf8);
			self.document = ABNFDocument(filepath: fileURL, name: name, charset: "UTF-32", content: content);
		} catch {
			// Handle error (e.g., show alert)
			print("Load error: \(error)")
		}
	}

	private func saveDocument() {
		guard let document else { return }
		// Always write to the user directory.
		// Copy the object if necessary.
		do {
			let writePath = writeDir.appendingPathComponent(document.name);
			if writePath != fileURL {
				selectedURL = writePath;
			}
			let data = Data(document.content.utf8);
			try data.write(to: writePath, options: [.atomic, .completeFileProtection])
		} catch {
			print("Save error: \(error)")
		}
	}
}
