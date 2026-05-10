import SwiftUI
import FSM

// TODO: Show equivalent inputs
// TODO: Show a multi-line input if the pattern permits newlines
// TODO: Show an option for newline representation and character encoding

struct InputTestingView: View {
	@Binding var content_rulelist: ABNFRulelist<UInt32>?
	@Binding var selectedRule: String?
	@Binding var rule_alphabet: ClosedRangeAlphabet<UInt32>?
	@Binding var rule_fsm: DFA<ClosedRangeAlphabet<UInt32>>?
	@Binding var content_cfg: CFG<ClosedRangeAlphabet<UInt32>>?
	let charset: Charset
	@State private var testInput: String = ""
	@State private var fsm_test_result: Bool? = nil
	@State private var fsm_test_next: Array<ClosedRange<UInt32>>? = nil
	@State private var fsm_test_error: String? = nil
	@State private var cfg_test_result: Bool? = nil
	@State private var cfg_test_tree: CFG<ClosedRangeAlphabet<UInt32>>.ParseTree? = nil

	var body: some View {
		Group {
			OctetInputField(testInput: $testInput)

			if let fsm_test_result {
				// TODO: Show symbols that are valid to enter at given cursor position
				Text("Result: " + (fsm_test_result ? "Accepted" : fsm_test_error ?? "Rejected"))
					.foregroundColor(fsm_test_result == true ? .green : .red)
				if let fsm_test_next {
					Text("Next symbols: " + describeCharacterSet(fsm_test_next, charset: charset))
				} else {
					Text("Next symbols: Oblivion")
				}
			} else if let cfg_test_result {
				Text("Result: " + (cfg_test_result ? "Accepted" : "Rejected"))
					.foregroundColor(cfg_test_result == true ? .green : .red)
			} else if let fsm_test_error {
				Text(fsm_test_error).foregroundColor(.red)
			}

			if let cfg_test_tree, let start = cfg_test_tree.start.first {
				ScrollView([.horizontal, .vertical]) {
					ParseTreeResult(result: cfg_test_tree, rule: start, charset: charset)
				}
			}
		}
		.onAppear { updatedInput() }
		.onChange(of: selectedRule) { updatedInput() }
		.onChange(of: rule_fsm) { updatedInput() }
		.onChange(of: rule_alphabet) { updatedInput() }
		.onChange(of: testInput) { updatedInput() }
	}

	private func updatedInput() {
		fsm_test_result = nil
		fsm_test_error = nil
		fsm_test_next = nil
		cfg_test_result = nil
		cfg_test_tree = nil

		guard let content_rulelist = content_rulelist,
				let selectedRule = selectedRule,
				content_rulelist.dictionary[selectedRule] != nil
		else {
			fsm_test_error = "Invalid selection"
			return
		}
		let input = Array(testInput.unicodeScalars.map(\.value))
		if let selected_fsm = rule_fsm {
			let fsm_test_state = selected_fsm.nextState(state: selected_fsm.initial, input: input)
			fsm_test_result = selected_fsm.isFinal(fsm_test_state)
			if let fsm_test_state {
				fsm_test_next = selected_fsm.states[fsm_test_state].alphabet.flatMap { $0 }
			}
			if fsm_test_result == false {
				if fsm_test_state != nil {
					fsm_test_error = "unexpected EOF"
				} else {
					fsm_test_error = "oblivion"
				}
			} else if let cfg = content_cfg {
				// Also attempt a CFG parse to display the parse tree
				cfg_test_result = cfg.contains(input);
				cfg_test_tree = cfg.parseTree(input);
			}
		} else if let cfg = content_cfg {
			cfg_test_result = cfg.contains(input);
			cfg_test_tree = cfg.parseTree(input);
		} else {
			fsm_test_error = "Rule `\(selectedRule)` is recursive or missing rules"
		}
	}
}

struct OctetInputField: View {
	@Binding var testInput: String
	@State private var selectedInputType: String? = nil
	@State private var hexInput: String = ""
	@State private var isUpdating = false
	@State private var isTargeted: Bool = false
	@State private var isImporting = false
	@State private var selectedFileURL: URL?

	var body: some View {
		let hexFont = Font.system(size: 14).monospaced()
		return TabView {
			Tab("Field", systemImage: "pencil") {
				TextField("Enter test input", text: $testInput)
					.font(hexFont)
					.textFieldStyle(RoundedBorderTextFieldStyle())
			}
			Tab("Multiline", systemImage: "pencil") {
				TextEditor(text: $testInput)
					.font(hexFont)
			}
			Tab("File", systemImage: "pencil") {
				ZStack {
					RoundedRectangle(cornerRadius: 12)
						.stroke(isTargeted ? Color.blue : Color.gray, style: .init(lineWidth: 2, dash: [4, 4]))
						.background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
					VStack {
						Text(selectedFileURL?.absoluteString ?? "Select file")
						Button("Open File...") { isImporting = true }
					}
				}
				.frame(width: 300, height: 100)
				// Makes the frame a drop area
				.dropDestination(for: URL.self) { urls, location in
					// Handle the dropped files (URLs)
					selectedFileURL = urls.first
					updateFromFile(url: urls.first!);
					return (selectedFileURL != nil);
				} isTargeted: { targeted in
					// Optional: update UI state when a file is hovered over the area
					isTargeted = targeted
				}
				// Presents the file picker dialog
				.fileImporter(
					isPresented: $isImporting,
					allowedContentTypes: [.text, .data], // Use .pdf, .plainText, etc. for specific types
					allowsMultipleSelection: false
				) { result in
					switch result {
					case .success(let urls):
						selectedFileURL = urls.first
						updateFromFile(url: selectedFileURL!);
					case .failure(let error):
						print("Error selecting file: \(error.localizedDescription)")
					}
				}
			}
			Tab("Binary", systemImage: "pencil") {
				HStack {
					TextEditor(text: $hexInput)
						.font(hexFont)
						.frame(width: 450)
					// TODO: This should render special characters as the symbols from U+24xx
					TextEditor(text: $testInput)
						.font(hexFont)
						.frame(width: 159)
				}
			}
		}
		.onChange(of: testInput) { updateFromTestInput() }
		.onChange(of: hexInput) { updateFromHex() }
	}

	private func updateFromTestInput() {
		guard !isUpdating else { return }
		isUpdating = true
		let bytes = Array(testInput.utf8)
		hexInput = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
		isUpdating = false
	}

	private func updateFromHex() {
		guard !isUpdating else { return }
		isUpdating = true
		let cleanedHex = hexInput.replacingOccurrences(of: " ", with: "").uppercased()
		guard cleanedHex.count % 2 == 0 else {
			isUpdating = false
			return
		}
		var bytes: [UInt8] = []
		for i in stride(from: 0, to: cleanedHex.count, by: 2) {
			let start = cleanedHex.index(cleanedHex.startIndex, offsetBy: i)
			let end = cleanedHex.index(start, offsetBy: 2)
			let hexPair = String(cleanedHex[start..<end])
			if let byte = UInt8(hexPair, radix: 16) {
				bytes.append(byte)
			} else {
				isUpdating = false
				return
			}
		}
		let data = Data(bytes)
		if let str = String(data: data, encoding: .ascii) {
			testInput = str
		}
		isUpdating = false
	}

	private func updateFromFile(url: URL) {
		testInput = (try? String(contentsOf: url, encoding: .utf8)) ?? "";
	}
}

struct ParseTreeResult: View {
	let result: CFG<ClosedRangeAlphabet<UInt32>>.ParseTree;
	let rule: CFG<ClosedRangeAlphabet<UInt32>>.ParseTreeKey;
	let charset: Charset;
	var body: some View {
		let production: CFG<ClosedRangeAlphabet<UInt32>>.ParseTree.Production = result.dictionary[rule]![0];
		Branch {
			BranchLabel(rule.name)
			ForEach(Array(production.body), id: \.self) {
				switch $0 {
					case .terminal(let t):
						Text(describeCharacterSet(t, charset: charset));
					case .nonterminal(let t):
						// TODO: Make this condition configurable
						if t.length > 0 { ParseTreeResult(result: result, rule: t, charset: charset); }
				}
			}
		}
	}
}
