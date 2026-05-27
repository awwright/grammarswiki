import SwiftUI

/// Forms the body of the Catalog window
struct CatalogView: View {
	@ObservedObject var model: MainAppModel
	@State private var selectionId: UUID? = nil

	var body: some View {
		NavigationSplitView {
			List(selection: $selectionId) {
				if model.user.values.isEmpty == false {
					Section("Saved") {
						ForEach(Array(model.user.values), id: \.id) {
							document in
							CatalogListItemView(document: Binding(get: { document }, set: { model.addDocument($0) }), onDelete: { self.selectionId = nil; model.delDocument(document) }, onDuplicate: { let newDoc = document.duplicate(); model.addDocument(newDoc); selectionId = newDoc.id; }, isEditable: true)
						}
					}
				}
				Section("Catalog") {
					ForEach(model.catalog, id: \.id) {
						document in
						CatalogListItemView(document: Binding(get: { document }, set: { let newDoc = $0.duplicate(); model.addDocument(newDoc); selectionId = newDoc.id }), onDelete: {}, onDuplicate: { let newDoc = document.duplicate(); model.addDocument(newDoc); selectionId = newDoc.id }, isEditable: false)
					}
				}
			}
			.navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 600)
			.toolbar {
				ToolbarItem {
					Button(action: addDocument) {
						Label("Add", systemImage: "plus")
					}
				}
			}
		} detail: {
			if let id = selectionId {
				if let document = model.user[id] {
					let binding = Binding(get: { document }, set: { model.addDocument($0) })
					DocumentView(document: binding)
						.navigationTitle(document.name)
				} else if let document = model.catalog.first(where: { $0.id == id }) {
					let binding = Binding(
						get: { document },
						set: {
							let newDocument = $0.duplicate();
							model.addDocument(newDocument)
							selectionId = newDocument.id
						}
					)
					DocumentView(document: binding)
						.navigationTitle(document.name)
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
 			let newDocument = Document(
				filepath: nil,
 				name: "New Document \(model.user.count + 1)",
 				type: "ABNF",
				charset: "UTF-32",
 				content: "",
 			);
 			model.addDocument(newDocument)
 			selectionId = newDocument.id
 		}
 	}
}

/// Item in the sidebar for selecting, renaming, or deleting a grammar from the Catalog
struct CatalogListItemView: View {
	@Binding var document: Document
	let onDelete: () -> Void
	let onDuplicate: () -> Void
	let isEditable: Bool
	@State private var isRenaming: Bool = false
	@FocusState private var isFocused: Bool
	@State private var draftName: String = ""

	var body: some View {
		NavigationLink(value: document.id, label: {
			if isRenaming {
				HStack {
					TextField("Name", text: $draftName, onCommit: {
						if !draftName.isEmpty {
							document.name = draftName
						}
						isRenaming = false
						isFocused = false
						// Save the changes, trigger a binding set operation
						document = document;
					}).focused($isFocused)
				}
			} else {
				Text(document.name)
			}
		})
		.contextMenu {
			Button {
				if let filepath = document.filepath {
					// TODO: If file no longer exists, show an alert
					NSWorkspace.shared.selectFile(filepath.path, inFileViewerRootedAtPath: "")
				}
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
			draftName = document.name
			isRenaming = true;
			isFocused = true;
		}
	}
}
