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

struct CFGDocument: DocumentProtocol, PageProtocol, Hashable, Equatable, FileDocument {
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

		init(id: UUID = UUID(), name: String, body: [BodyElement], top: Bool) {
			self.id = id;
			self.name = name;
			self.body = body;
			self.top = top;
		}

		init(xmlElement: XMLElement) throws {
			guard xmlElement.name == "production" else {
				throw PageXMLError.unexpectedElement(expected: "production", actual: xmlElement.name)
			}
			self.id = UUID();
			self.name = xmlElement.attribute(forName: "name")?.stringValue ?? "";
			let topStr = xmlElement.attribute(forName: "top")?.stringValue?.lowercased() ?? "";
			self.top = topStr == "true" || topStr == "1";
			var body: [BodyElement] = [];
			for case let child as XMLElement in xmlElement.children ?? [] {
				switch child.name {
				case "nt":
					body.append(.nonterminal(child.stringValue ?? ""));
				case "t":
					let ranges: [TerminalRange] = try child.elements(forName: "range").map { try TerminalRange(xmlElement: $0) }
					body.append(.terminal(ranges));
				default:
					continue;
				}
			}
			self.body = body;
		}

		func makeXMLElement() throws -> XMLElement {
			let el = XMLElement(name: "production");
			var attrs: [String: String] = ["name": name];
			if top { attrs["top"] = "true" }
			el.setAttributesWith(attrs);
			for element in body {
				switch element {
				case .nonterminal(let nt):
					let ntEl = XMLElement(name: "nt");
					ntEl.setStringValue(nt, resolvingEntities: false);
					el.addChild(ntEl);
				case .terminal(let ranges):
					let tEl = XMLElement(name: "t");
					for range in ranges {
						tEl.addChild(range.makeXMLElement());
					}
					el.addChild(tEl);
				}
			}
			return el;
		}
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

		init(lower: UInt32, upper: UInt32) {
			self.lower = lower;
			self.upper = upper;
		}

		init(xmlElement: XMLElement) throws {
			guard xmlElement.name == "range" else {
				throw PageXMLError.unexpectedElement(expected: "range", actual: xmlElement.name)
			}
			guard let lowerStr = xmlElement.attribute(forName: "lower")?.stringValue,
			      let upperStr = xmlElement.attribute(forName: "upper")?.stringValue,
			      let lower = UInt32(lowerStr),
			      let upper = UInt32(upperStr) else {
				throw PageXMLError.invalidAttribute("lower/upper")
			}
			self.lower = lower
			self.upper = upper
		}

		func makeXMLElement() -> XMLElement {
			let el = XMLElement(name: "range")
			el.setAttributesWith([
				"lower": String(lower),
				"upper": String(upper),
			])
			return el
		}
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

	// MARK: PageProtocol XML
	static var xmlElementName: String { "cfg" }

	init(xmlElement: XMLElement) throws {
		guard xmlElement.name == Self.xmlElementName else {
			throw PageXMLError.unexpectedElement(expected: Self.xmlElementName, actual: xmlElement.name);
		}
		self.filepath = nil
		self.name = xmlElement.attribute(forName: "name")?.stringValue ?? "";
		self.charset = xmlElement.attribute(forName: "charset")?.stringValue ?? "UTF-32";
		self.productions = try xmlElement.elements(forName: "production").map { try Production(xmlElement: $0) }
	}

	func toXMLElement() throws -> XMLElement {
		let el = XMLElement(name: Self.xmlElementName);
		el.setAttributesWith([
			"name": name,
			"charset": charset,
		])
		for production in productions {
			el.addChild(try production.makeXMLElement());
		}
		return el;
	}

	// MARK: Editor

	struct EditorView: EditorViewBody {
		@Binding var document: CFGDocument
		let computed: GrammarAnalysis

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
								document.productions.append(Production(name: "X", body: [], top: false))
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
		let computed: GrammarAnalysis
		var body: some View { EmptyView() }
	}

	func toCFG(startRule: String?) -> ABNFRulelist<UInt32>.CFG {
		typealias G = ABNFRulelist<UInt32>.CFG
		func ruleName(_ name: String) -> CFGRuleName { CFGRuleName(.rule(name)) }
		let namedProductions: [G.Production] = productions.map { p in
			G.Production(name: ruleName(p.name), body: p.body.map { element in
				switch element {
				case .nonterminal(let name):
					return .nonterminal(ruleName(name))
				case .terminal(let ranges):
					return .terminal(ranges.map(\.closedRange))
				}
			})
		}
		let start = startRule.flatMap { name in namedProductions.contains(where: { $0.name == ruleName(name) }) ? ruleName(name) : nil }
		?? namedProductions.first?.name
		guard let start else { return G() }
		return G(start: start, productions: namedProductions)
	}

	func toCFGArray(startRule: String?) -> CFGArray<ClosedRangeAlphabet<UInt32>> {
		CFGArray(toCFG(startRule: startRule))
	}

	func updateParser(_ parser: GrammarAnalysis) {
		let snapshot = self
		let selectedRulename = parser.selectedRulename
		parser.runUpdate {
			var seenAll = Set<String>();
			var all: [String] = [];
			var seenTops = Set<String>();
			var tops: [String] = [];
			for p in snapshot.productions {
				if seenAll.insert(p.name).inserted { all.append(p.name) }
				if p.top, seenTops.insert(p.name).inserted { tops.append(p.name) }
			}
			let primary = snapshot.productions.first?.name
			if Task.isCancelled { return }
			await MainActor.run {
				parser.primaryRuleName = primary
				parser.topRuleNames = tops
				parser.allRuleNames = all
			}
			let cfg = snapshot.toCFG(startRule: selectedRulename ?? primary)
			let empty = cfg.productions.isEmpty
			if Task.isCancelled { return }
			await MainActor.run {
				parser.selectedRule_cfg = empty ? nil : cfg
				parser.selectedRule_cfga = empty ? nil : CFGArray(cfg)
				parser.selectedRule_chomskyClass = empty ? nil : cfg.chomskyClass()
				parser.selectedRule_memoryRequirements = empty ? nil : cfg.memoryRequirements()
			}
		}
	}
}
