import SwiftUI
import FSM

// TODO: Show equivalent inputs
// TODO: Show a multi-line input if the pattern permits newlines
// TODO: Show an option for newline representation and character encoding

struct InputTestingView: View {
	@Binding var rule_alphabet: ClosedRangeAlphabet<UInt32>?
	@Binding var rule_fsm: DFA<ClosedRangeAlphabet<UInt32>>?
	@Binding var content_cfg: ABNFRulelist<UInt32>.CFG?
	@Environment(SelectedCharset.self) private var charset
	@State private var testInput: String = ""
	@State private var fsm_test_result: Bool? = nil
	@State private var fsm_test_next: Array<ClosedRange<UInt32>>? = nil
	@State private var fsm_test_error: String? = nil
	@State private var cfg_test_result: Bool? = nil
	@State private var cfg_test_parse: ABNFRulelist<UInt32>.CFG.Parser? = nil
	@State private var cfg_test_tree: ABNFRulelist<UInt32>.CFG.ParseTree? = nil

	var body: some View {
		Group {
			OctetInputField(testInput: $testInput)

			if let fsm_test_result {
				// TODO: Show symbols that are valid to enter at given cursor position
				Text("Result: " + (fsm_test_result ? "Accepted" : fsm_test_error ?? "Rejected"))
					.foregroundColor(fsm_test_result == true ? .green : .red)
			} else if let cfg_test_result {
				Text("Result: " + (cfg_test_result ? "Accepted" : "Rejected"))
					.foregroundColor(cfg_test_result == true ? .green : .red)
			} else if let fsm_test_error {
				Text(fsm_test_error).foregroundColor(.red)
			}

			if let fsm_test_next {
				Text("Next symbols: " + charset.describe(fsm_test_next))
			} else {
				Text("Next symbols: Oblivion")
			}

			if let cfg_test_tree, let start = cfg_test_tree.start.first {
				// TODO: Show a partial parse result. Either:
				// - The longest completed subsequence of a production, if more input is expected
				// - The longest substring of input that was matched, if in an oblivion state
				ScrollView([.horizontal, .vertical]) {
					ParseTreeResult(result: cfg_test_tree, rule: start)
				}
			}

			if let cfg_test_parse {
				DisclosureGroup("Parse chart") {
					VStack(alignment: .leading) {
						// TODO: The Array() wrapper can be removed in later versions of Swift
						ForEach(Array(cfg_test_parse.allItems.enumerated()), id: \.offset) { offset, chart_position in
							VStack(alignment: .leading) {
								ForEach(chart_position, id: \.self) { item in
									// Mostly the same as ParseStateItem.description except this shows a range like @1-3
									let body = item.production.rhs.enumerated().map { (element_i, element) in
										let c = (item.progress == element_i ? "● " : "")
										let x = switch element {
											case .nonterminal(let x): String(describing: x);
											case .terminal(let x): charset.describe(x)
										};
										return  "\(c)\(x)";
									}.joined(separator: " ") + (item.isComplete ? " ■" : "")
									Text("\(item.production.name) @\(item.offset)-\(offset) → \(body)")
								}
							}
							Divider()
						}
					}
				}
				DisclosureGroup("Parse forest") {
					// The parse forest is the largest subset of the original grammar that matches only the input string.
					// cfg_test_tree should always be defined, but in the event it's not just show the empty set
					let grammar = cfg_test_tree ?? .init();
					VStack(alignment: .leading) {
						ForEach(grammar.start, id: \.self) { rulename in
							Text("\u{2192} \(rulename)")
						}
						if grammar.start.isEmpty {
							Text("\u{2192} \u{2205}")
						}
						Spacer()
						let dictionary = grammar.dictionary
						let ruleNames = grammar.ruleNames;
						ForEach(ruleNames, id: \.self) { (ruleName: ABNFRulelist<UInt32>.CFG.ParseTree.Variable) in
							let rules = dictionary[ruleName] ?? []
							Text("\(ruleName)").font(.headline);
							if rules.isEmpty {
								Text("\t= \u{2205}");
							}
							ForEach(rules, id: \.self) { rule in
								HStack {
									Text("\t\u{2192} ")
									ForEach(rule.body, id: \.self) { (token: ABNFRulelist<UInt32>.CFG.ParseTree.BodyElement) in
										switch token {
											case .terminal(let sym): Text(charset.describe(sym)).monospaced()
											case .nonterminal(let name): Text(name.description)
//											default: Text(String(describing: token))
										}
									}
									if rule.body.isEmpty {
										Text("\u{3B5}") // Epsilon
									}
								}
							}
							Spacer()
						}
					}.frame(maxWidth: .infinity, alignment: .topLeading)
				}
			}
		}
		.onAppear { updatedInput() }
		.onChange(of: rule_fsm) { updatedInput() }
		.onChange(of: rule_alphabet) { updatedInput() }
		.onChange(of: testInput) { updatedInput() }
	}

	private func updatedInput() {
		fsm_test_result = nil
		fsm_test_error = nil
		fsm_test_next = nil
		cfg_test_result = nil
		cfg_test_parse = nil
		cfg_test_tree = nil

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
			}
		}
		if let cfg = content_cfg {
			// Also attempt a CFG parse to display the parse tree
			let cfg_parse = cfg.parse(input);
			cfg_test_parse = cfg_parse;
			cfg_test_result = cfg_parse.isCompleted;
			cfg_test_tree = cfg_parse.parseForest;
			fsm_test_next = cfg_parse.nextSymbols.flatMap { $0 };
		} else {
			fsm_test_error = "Could not read rule"
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
	let result: ABNFRulelist<UInt32>.CFG.ParseTree;
	let rule: ABNFRulelist<UInt32>.CFG.ParseTreeKey;
	@Environment(SelectedCharset.self) private var charset;
	var body: some View {
		let production: ABNFRulelist<UInt32>.CFG.ParseTree.Production = result.dictionary[rule]![0];
		Branch {
			BranchLabel(rule.name[0].description)
			ForEach(Array(production.body), id: \.self) {
				switch $0 {
					case .terminal(let t):
						Text(charset.describe(t));
					case .nonterminal(let t):
						// TODO: Make this condition configurable
						if t.length > 0 {
							if t.name.count == 1 { ParseTreeResult(result: result, rule: t); }
							else { ParseTreeFlatten(result: result, rule: t); }
						}
				}
			}
		}
	}
}

struct ParseTreeFlatten: View {
	let result: ABNFRulelist<UInt32>.CFG.ParseTree;
	let rule: ABNFRulelist<UInt32>.CFG.ParseTreeKey;
	@Environment(SelectedCharset.self) private var charset;
	var body: some View {
		let production: ABNFRulelist<UInt32>.CFG.ParseTree.Production = result.dictionary[rule]![0];
		ForEach(Array(production.body), id: \.self) {
			switch $0 {
				case .terminal(let t):
					Text(charset.describe(t));
				case .nonterminal(let t):
					// TODO: Make this condition configurable
					if t.length > 0 {
						if t.name.count == 1 { ParseTreeResult(result: result, rule: t); }
						else { ParseTreeFlatten(result: result, rule: t); }
					}
			}
		}
	}
}
