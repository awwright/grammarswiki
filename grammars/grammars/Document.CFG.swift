import SwiftUI
import FSM
import UniformTypeIdentifiers
import Foundation

extension UTType {
	static var cfgJsonDoc = UTType(exportedAs: "name.awwright.grammars.doc.cfgjson", conformingTo: .json)
}

/// On-disk representation for a .cfgjson file. Structured form matching CFG<ClosedRangeAlphabet<UInt32>>.
private struct CFGDocumentFile: Codable {
	var name: String?
	var start: [String]?
	var charset: String?
	var productions: [CFGDocument.Production]?
}

struct CFGDocument: DocumentProtocol, Hashable, Equatable, FileDocument {
	let id = UUID()
	var filepath: URL?
	var name: String
	var charset: String

	/// The core editable data: a real CFG over ClosedRangeAlphabet<UInt32>.
	var productions: [Production]

	var type: String { "CFG" }

	/// Structured production that can be losslessly mapped to/from CFG<ClosedRangeAlphabet<UInt32>>.Production
	struct Production: Hashable, Codable, Equatable, Identifiable {
		var id: UUID = UUID()
		var name: String
		var body: [BodyElement]
		/// "top" marks rules intended for external/public use
		var top: Bool

		enum CodingKeys: String, CodingKey { case id, name, body, top }
	}

	/// One element of a production body (RHS).
	enum BodyElement: Hashable, Codable, Equatable {
		case nonterminal(String)
		/// A terminal symbol class represented as zero or more disjoint closed ranges.
		/// Each range is [lower, upper] inclusive. Empty array means the empty class (no symbols).
		case terminal([TerminalRange])
	}

	/// A closed range over UInt32 codepoints / symbols.
	struct TerminalRange: Hashable, Codable, Equatable {
		var lower: UInt32
		var upper: UInt32
		var closedRange: ClosedRange<UInt32> { lower...upper }
	}

	static var readableContentTypes: [UTType] { [.cfgJsonDoc] }
	static var writableContentTypes: [UTType] { [.cfgJsonDoc] }

	init() {
		self.filepath = nil;
		self.name = "";
		self.charset = "UTF-32";
		self.productions = [];
	}

	init(filepath: URL?, name: String, charset: String, productions: [Production]) {
		self.filepath = filepath;
		self.name = name;
		self.charset = charset;
		self.productions = productions;
	}

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		let decoder = JSONDecoder();
		let decoded = try decoder.decode(CFGDocumentFile.self, from: data);
		self.filepath = nil;
		self.name = decoded.name ?? "";
		self.charset = decoded.charset ?? "UTF-32";
		self.productions = decoded.productions ?? [];
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let payload = CFGDocumentFile(
			name: self.name.isEmpty ? nil : self.name,
			charset: self.charset,
			productions: self.productions.isEmpty ? nil : self.productions
		);
		let encoder = JSONEncoder();
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys];
		let data = try encoder.encode(payload);
		return FileWrapper(regularFileWithContents: data);
	}

	func duplicate() -> Self {
		Self(filepath: nil, name: name + " Copy", charset: charset, productions: productions)
	}

	// MARK: Editor

	struct EditorView: EditorViewBody {
		@Binding var document: CFGDocument
		let computed: CFGDocument.Parser

		// Placeholder for empty value
		private let kEmpty = "<empty>"

		/// Distinct rule names in the order they first appear (productions first, then any extra start symbols).
		var ruleNames: [String] {
			var seen = Set<String>();
			var result: [String] = [];
			for p in document.productions {
				if seen.insert(p.name).inserted { result.append(p.name) }
			}
			return result;
		}

		var firstRuleName: String? { document.productions.first?.name }

		var body: some View {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					// Document metadata
					GroupBox("Document") {
						VStack(alignment: .leading) {
							TextField("Charset", text: $document.charset)
						}
						.padding(4)
					}

					GroupBox("Productions") {
						VStack(alignment: .leading, spacing: 12) {
							ForEach(Array(document.productions.enumerated()), id: \.offset) { (offset, prod) in
								VStack(alignment: .leading, spacing: 4) {
									HStack {
										TextField("LHS", text: Binding(
											get: { document.productions[offset].name },
											set: { document.productions[offset].name = $0 }
										))
										.font(.system(.headline, design: .monospaced))
										.frame(minWidth: 120)

										Button {
											document.productions[offset].top.toggle()
										} label: {
											Image(systemName: prod.top ? "star.fill" : "star")
										}
										.help(prod.top ? "Top-level / exported rule" : "Internal rule")

										Spacer()

										Button(role: .destructive) {
											document.productions.remove(at: offset)
										} label: {
											Image(systemName: "trash")
										}
									}

									// Body (RHS): single text field using ' ' " " [class] syntax
									HStack(alignment: .center, spacing: 6) {
										Text("\u{2192}").foregroundStyle(.secondary)
										TextField("body", text: .constant(document.productions[offset].body.description), prompt: Text(prod.body.isEmpty ? "\u{03B5}" : ""))
											.font(.system(.body, design: .monospaced))
											.textFieldStyle(.roundedBorder)
									}

									Divider()
								}
							}

							Button {
								document.productions.append(.init(name: "X", body: [], top: false))
							} label: {
								Label("Add production", systemImage: "plus.rectangle")
							}
						}
						.padding(4)
					}
				}
				.padding()
			}
		}
	}

	// MARK: Rule info
	struct RuleInfoView: EditorViewBody {
		@Binding var document: CFGDocument
		let computed: CFGDocument.Parser
		var body: some View { EmptyView() }
	}

	// MARK: Parser
	@Observable class Parser: DocumentParserProtocol {
		typealias Document = CFGDocument

		required init() {
			document = nil;
			self._task = Task{};
			document_error = nil;
			topRuleNames = [];
			allRuleNames = [];
		}

		deinit { _task.cancel() }

		var document: Document? { didSet { _update() } }
		var document_error: String? = nil
		var primaryRuleName: String? = nil
		var topRuleNames: Array<String> = []
		var allRuleNames: Array<String> = []

		var selectedRulename: String? { didSet { _update() } }
		var selectedRule_error: String? = nil
		var selectedRule_alphabet: ClosedRangeAlphabet<UInt32>? = nil
		var selectedRule_fsm: DFA<ClosedRangeAlphabet<UInt32>>? = nil
		var selectedRule_cfg: FSM.ABNFRulelist<UInt32>.CFG? = nil
		var selectedRule_rr: RailroadNode? = nil
		var selectedRule_complexityClass: Int? = nil
		var selectedRule_chomskyClass: Int? = nil
		var selectedRule_memoryRequirements: Int? = nil

		let builtins = ABNFBuiltins<DFA<ClosedRangeAlphabet<UInt32>>>.dictionary.mapValues { $0.minimized() }

		var _task: Task<(), Never>
		func _update() {
			_task.cancel();
			document_error = nil;

			_task = Task {
				guard let document else { return }
				let primary = document.productions.first?.name;
				let tops = document.productions.filter { $0.top }.map { $0.name };
				let all = document.productions.map { $0.name };
				if _task.isCancelled { return }
				await MainActor.run {
					self.primaryRuleName = primary;
					self.topRuleNames = tops;
					self.allRuleNames = all;
				}
			}
		}
	}
}
