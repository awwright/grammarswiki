import SwiftUI
import FSM

// This view generates a regular expression from a DFA/FSM.
// There are many variations of regular expressions, so the user may pick a dialect and other options.
// The user can also quote the regular expression inside another language, escaping characters in the regular expression itself as necessary.
// Users should be able to "star" presets for re-use later.
// If a preset is selected and I make edits, I should see options to update the selected preset, or to duplicate it as a new preset.
// TODO: The regular expression should be factored out in roughly the same way the ABNF is;
// If multiple choices in an alternation overlap, then remove the match from the subsequent alternation options.

struct RegexPreset: Identifiable, Codable {
	let id: UUID
	var name: String
	var dialect: String
	/// Specifies if the generated regex should use the "case insensitive" flag, if the case of all the characters is insignificant to the result.
	var caseInsensitive: Bool
	var escaping: String

	init(id: UUID = UUID(), name: String, dialect: String, caseInsensitive: Bool, escaping: String) {
		self.id = id
		self.name = name
		self.dialect = dialect
		self.caseInsensitive = caseInsensitive
		self.escaping = escaping
	}
}

struct RegexContentView: View {
	@Binding var rule_fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>?
	@State private var regexDescription: String?
	@State private var error: String?
	@State private var unsavedChanges: Bool = false
	@State private var presetExpanded: Bool = true
	//@State private var option_exclude_rules: String = ""

	@AppStorage("regexDialect") private var regexDialect: String = RegexDialect.posix.rawValue
	@AppStorage("regexPresets") private var presetsData: Data = Data()

	@State private var presets: [RegexPreset] = []
	@State private var selectedPresetId: UUID? = nil
	@State private var selectedPreset: RegexPreset? = nil
	@State private var presetName: String = ""
	@State private var caseInsensitive: Bool = false
	@State private var escaping: String = ""
	@State private var renameText: String = ""
	@State private var showingNamePopover: Bool = false

	var body: some View {
		VStack(spacing: 0) {
			Form {
				DisclosureGroup(
					isExpanded: $presetExpanded,
					content: {
						Picker("Dialect", selection: $regexDialect) {
							ForEach(RegexDialect.allCases) { dialect in
								Text(dialect.rawValue).tag(dialect.rawValue)
							}
						}
						.pickerStyle(.menu)

						// Per-dialect specific options
						if(regexDialect == RegexDialect.swift.rawValue){
							GroupBox(content: {
								Toggle("Case-insensitive flag when possible", isOn: $caseInsensitive)
							}, label: {
								Text("Swift options")
							})
						}

						Picker("Escape", selection: $escaping) {
							Text("ASCII").tag("ascii")
							Text("Unicode").tag("unicode")
							Divider()
							Text("Swift Regex Literal").tag("swift_literal")
							Text("Swift Ignore Whitespace Literal").tag("swift_nws_literal")
							Text("Swift Regex String").tag("swift_string")
							Text("Swift Regex Builder").tag("swift_builder")
							Text("Swift NSRegularExpression").tag("swift_nsregex")
							Text("Shell").tag("shell")
						}
						.pickerStyle(.menu)

						//TextField("Exclude rules", text: $option_exclude_rules);
					},
					label: {
						// TODO: Allow user to star/favorite specific dialects and configurations
						HStack {
							Picker("Preset", selection: $selectedPresetId) {
								Text("None").tag(UUID?.none)
								// TODO: Keep a "stage" item, where modifications are kept for using while they're unsaved.
								// When the Save button is pressed, then copy the stage to the saved preset data.
								if unsavedChanges, let id = selectedPresetId, let preset = presets.first(where: { $0.id == id }) {
									Text(preset.name + " (Edited)").tag(UUID?.some(preset.id))
								}
								Divider();
								ForEach(presets) { preset in
									Text(preset.name).tag(UUID?.some(preset.id))
								}
							}
							.pickerStyle(.menu)
							.frame(width: 300)
							.popover(isPresented: $showingNamePopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
								TextField("Preset Name", text: $presetName)
									.padding()
									.frame(width: 300)
									.onSubmit {
										savePresetName()
										showingNamePopover = false;
									}
							}
							if(unsavedChanges){
								Button("Save", systemImage: "square.and.arrow.down", action: savePreset)
							}
							Spacer();
							if(presetExpanded){
								// Should I use RenameButton? I can't figure out how that works.
								Button(action: { showingNamePopover = true }) {
									Image(systemName: "pencil")
								}
								if(selectedPreset != nil){
									Button("Duplicate", systemImage: "square.on.square", action: duplicatePreset)
									Button("Delete", systemImage: "trash", action: deletePreset)
								}
							}
						}
					}).labelStyle(.iconOnly)
			}
			.padding()

			HStack {
				Spacer();

				Button(
					"Copy to Clipboard",
					systemImage: "document.on.document",
					action: {
					if let copyText = regexDescription {
	#if os(macOS)
						let pasteboard = NSPasteboard.general
						pasteboard.clearContents()
						pasteboard.setString(copyText, forType: .string)
	#elseif os(iOS)
						UIPasteboard.general.string = copyText
	#endif
					}
				})
				.padding()
				.disabled(regexDescription == nil);

				Button(
					"Save As...",
					systemImage: "square.and.arrow.down",
					action: {
						print("Save as...");
					})
				.padding()
				.disabled(regexDescription == nil);

			}

			ScrollView {
				if let regexDescription = regexDescription {
					Text(regexDescription)
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
						.padding()
						.border(Color.gray, width: 1)
				} else if let error = error {
					Text("Error: \(error)")
						.foregroundColor(.red)
				} else {
					Text("Building...")
						.foregroundColor(.gray)
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onAppear {
			loadPresets()
			computeRegexDescription()
		}
		.onChange(of: rule_fsm) { computeRegexDescription() }
		.onChange(of: regexDialect) { checkPresetMismatch(); computeRegexDescription() }
		.onChange(of: caseInsensitive) { checkPresetMismatch() }
		.onChange(of: escaping) { checkPresetMismatch() }
		.onChange(of: selectedPresetId) {
			if let id = selectedPresetId, let preset = presets.first(where: { $0.id == id }) {
				selectedPreset = preset
				regexDialect = preset.dialect
				caseInsensitive = preset.caseInsensitive
				escaping = preset.escaping
				presetName = preset.name
				unsavedChanges = false
			} else {
				selectedPreset = nil
				unsavedChanges = false
			}
		}
	}

	private func computeRegexDescription() {
		regexDescription = nil
		error = nil
		guard let fsm = rule_fsm else {
			return
		}
		let regexDialect = regexDialect;
		Task.detached(priority: .utility) {
			let regex: REPattern<UInt32> = fsm.toPattern()
			let description = switch regexDialect {
				case "Swift": REDialectBuiltins.swift.encode(regex)
				case "POSIX Extended": REDialectBuiltins.posixExtended.encode(regex)
				default: "[:Unknown:]"
			}
			await MainActor.run {
				regexDescription = description
				error = nil
			}
		}
	}

	private func loadPresets() {
		if let decoded = try? JSONDecoder().decode([RegexPreset].self, from: presetsData) {
			presets = decoded
		}
	}

	private func savePresets() {
		presetsData = (try? JSONEncoder().encode(presets)) ?? Data()
	}

	private func checkPresetMismatch() {
		guard let selectedPreset else {
			unsavedChanges = false
			return
		}
		unsavedChanges = selectedPreset.dialect != regexDialect ||
						 selectedPreset.caseInsensitive != caseInsensitive ||
						 selectedPreset.escaping != escaping
	}

	private func savePreset() {
		if let selectedPreset {
			// update existing
			if let index = presets.firstIndex(where: { $0.id == selectedPreset.id }) {
				presets[index] = RegexPreset(id: selectedPreset.id, name: presetName, dialect: regexDialect, caseInsensitive: caseInsensitive, escaping: escaping)
				self.selectedPreset = presets[index]
			}
		} else {
			// save new
			let newPreset = RegexPreset(name: presetName, dialect: regexDialect, caseInsensitive: caseInsensitive, escaping: escaping)
			presets.append(newPreset)
			selectedPresetId = newPreset.id
		}
		savePresets()
		unsavedChanges = false
	}

	private func savePresetName() {
		if let selectedPreset, let index = presets.firstIndex(where: { $0.id == selectedPreset.id }) {
			presets[index].name = presetName
			self.selectedPreset = presets[index]
			savePresets()
		} else {
			// No preset selected, save new preset with the entered name
			savePreset()
		}
	}

	private func renamePreset() {
		guard let selectedPreset, let index = presets.firstIndex(where: { $0.id == selectedPreset.id }) else { return }
		presets[index].name = presetName
		self.selectedPreset = presets[index]
		savePresets()
	}

	private func duplicatePreset() {
		guard let selectedPreset else { return }
		let baseName = selectedPreset.name
		// TODO: If this ends with "Copy" or a number, then rename to an unused number
		let newName = baseName + " Copy"
		let newPreset = RegexPreset(name: newName, dialect: regexDialect, caseInsensitive: caseInsensitive, escaping: escaping)
		presets.append(newPreset)
		selectedPresetId = newPreset.id
		savePresets()
	}

	private func deletePreset() {
		guard let selectedPreset, let index = presets.firstIndex(where: { $0.id == selectedPreset.id }) else { return }
		presets.remove(at: index)
		selectedPresetId = nil
		savePresets()
	}
}

#Preview {
	let fsm = SymbolClassDFA<ClosedRangeAlphabet<UInt32>>.empty;
	RegexContentView(rule_fsm: Binding(get: { fsm }, set: { fsm in }))
}
