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
	var rules: [CFGDocument.Rule]?
}

struct CFGDocument: DocumentProtocol, PageProtocol, Hashable, Equatable, FileDocument {
	let id = UUID()
	var filepath: URL?
	var name: String
	var charset: String

	/// Named rules in document order
	var rules: [Rule]

	var type: String { "CFG" }

	/// A variable (nonterminal) defined with its expansions (productions)
	struct Rule: Hashable, Codable, Equatable, Identifiable {
		var id: UUID = UUID()
		var name: String
		/// "top" marks rules intended for external/public use
		var top: Bool
		var productions: [Production]

		enum CodingKeys: String, CodingKey { case id, name, top, productions }

		init(id: UUID = UUID(), name: String, top: Bool, productions: [Production]) {
			self.id = id;
			self.name = name;
			self.top = top;
			self.productions = productions;
		}

		init(xmlElement: XMLElement) throws {
			guard xmlElement.name == "rule" else {
				throw PageXMLError.unexpectedElement(expected: "rule", actual: xmlElement.name)
			}
			self.id = UUID();
			self.name = xmlElement.attribute(forName: "name")?.stringValue ?? "";
			let topStr = xmlElement.attribute(forName: "top")?.stringValue?.lowercased() ?? "";
			self.top = topStr == "true" || topStr == "1";
			self.productions = try xmlElement.elements(forName: "production").map { try Production(xmlElement: $0) }
		}

		func makeXMLElement() throws -> XMLElement {
			let el = XMLElement(name: "rule");
			var attrs: [String: String] = ["name": name];
			if top { attrs["top"] = "true" }
			el.setAttributesWith(attrs);
			for production in productions {
				el.addChild(try production.makeXMLElement());
			}
			return el;
		}
	}

	/// Alternative of a rule
	///
	/// An empty body forms the empty string (epsilon)
	struct Production: Hashable, Codable, Equatable, Identifiable {
		var id: UUID = UUID()
		var body: [BodyElement]

		enum CodingKeys: String, CodingKey { case id, body }

		init(id: UUID = UUID(), body: [BodyElement]) {
			self.id = id;
			self.body = body;
		}

		init(xmlElement: XMLElement) throws {
			guard xmlElement.name == "production" else {
				throw PageXMLError.unexpectedElement(expected: "production", actual: xmlElement.name)
			}
			self.id = UUID();
			var body: [BodyElement] = [];
			for case let child as XMLElement in xmlElement.children ?? [] {
				switch child.name {
				case "v":
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
			for element in body {
				switch element {
				case .nonterminal(let nt):
					let ntEl = XMLElement(name: "v");
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
		self.rules = [];
	}

	init(filepath: URL?, name: String, charset: String, rules: [Rule]) {
		self.filepath = filepath;
		self.name = name;
		self.charset = charset;
		self.rules = rules;
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
		self.rules = decoded.rules ?? [];
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let payload = CFGDocumentFile(
			name: self.name.isEmpty ? nil : self.name,
			charset: self.charset,
			rules: self.rules.isEmpty ? nil : self.rules
		);
		let encoder = JSONEncoder();
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys];
		let data = try encoder.encode(payload);
		return FileWrapper(regularFileWithContents: data);
	}

	func duplicate() -> Self {
		Self(filepath: nil, name: name + " Copy", charset: charset, rules: rules)
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
		self.rules = try xmlElement.elements(forName: "rule").map { try Rule(xmlElement: $0) }
	}

	func toXMLElement() throws -> XMLElement {
		let el = XMLElement(name: Self.xmlElementName);
		el.setAttributesWith([
			"name": name,
			"charset": charset,
		])
		for rule in rules {
			el.addChild(try rule.makeXMLElement());
		}
		return el;
	}

	// MARK: Editor

	struct EditorView: EditorViewBody {
		@Binding var document: CFGDocument
		let computed: RulelistAnalysis

		var body: some View {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					GroupBox("Document") {
						VStack(alignment: .leading) {
							TextField("Charset", text: $document.charset)
						}
						.padding(4)
					}

					ForEach($document.rules) { $rule in
						GroupBox("Rule") {
							VStack(alignment: .leading, spacing: 8) {
								HStack {
									TextField("Rule name", text: $rule.name)
										.font(.system(.headline, design: .monospaced))
										.frame(minWidth: 120)

									Button {
										rule.top.toggle()
									} label: {
										Image(systemName: rule.top ? "star.fill" : "star")
									}
									.help(rule.top ? "Top-level / exported rule" : "Internal rule")

									Spacer()

									Button(role: .destructive) {
										document.rules.removeAll { $0.id == rule.id }
									} label: {
										Image(systemName: "trash")
									}
									.help("Remove this rule")
								}

								if rule.productions.isEmpty {
									Text("∅ empty language (no productions)")
										.foregroundStyle(.secondary)
										.padding(.leading, 4)
								}

								ForEach($rule.productions) { $production in
									HStack(alignment: .center, spacing: 6) {
										if let index = rule.productions.firstIndex(where: { $0.id == production.id }) {
											Text("\(index + 1).")
												.foregroundStyle(.secondary)
												.frame(width: 28, alignment: .trailing)
												.monospacedDigit()
										}
										Text("\u{2192}").foregroundStyle(.secondary)
										TextField(
											"body",
											text: .constant(production.body.description),
											prompt: Text(production.body.isEmpty ? "\u{03B5}" : "")
										)
										.font(.system(.body, design: .monospaced))
										.textFieldStyle(.roundedBorder)

										Button(role: .destructive) {
											rule.productions.removeAll { $0.id == production.id }
										} label: {
											Image(systemName: "trash")
										}
										.help("Remove this production")
									}
								}

								Button {
									rule.productions.append(Production(body: []))
								} label: {
									Label("Add production", systemImage: "plus")
								}
								.help("Add an alternative. An empty body is ε; delete all productions for the empty language.")
							}
						}
					}

					VStack(alignment: .leading, spacing: 16) {
						if document.rules.isEmpty {
							Text("No rules defined")
								.foregroundStyle(.secondary)
						}

						Button {
							let name = document.rules.isEmpty ? "S" : "R\(document.rules.count + 1)"
							document.rules.append(Rule(name: name, top: document.rules.isEmpty, productions: []))
						} label: {
							Label("Add rule", systemImage: "plus.rectangle")
						}
						.help("Add a named rule with no productions (empty language)")
					}
					.padding(4)
				}
				.padding()
			}
		}
	}

	// MARK: Rule info
	struct RuleInfoView: RuleInfoViewBody {
		@Binding var document: CFGDocument
		let rule: RuleAnalysis
		var body: some View { EmptyView() }
	}

	func toCFG(startRule: String?) -> ABNFRulelist<UInt32>.CFG {
		typealias G = ABNFRulelist<UInt32>.CFG
		func ruleName(_ name: String) -> CFGRuleName { CFGRuleName(.rule(name)) }
		var dict: Dictionary<CFGRuleName, Array<G.Alternative>> = [:];
		for rule in rules {
			let key = ruleName(rule.name);
			if dict[key] == nil { dict[key] = []; }
			for production in rule.productions {
				let body: G.Alternative = production.body.map { element in
					switch element {
					case .nonterminal(let name):
						return .nonterminal(ruleName(name))
					case .terminal(let ranges):
						return .terminal(ranges.map(\.closedRange))
					}
				}
				dict[key, default: []].append(body);
			}
		}
		let start = startRule.flatMap { name in dict[ruleName(name)] != nil ? ruleName(name) : nil }
		?? rules.first.map { ruleName($0.name) }
		guard let start else { return G() }
		return G(start: start, rules: dict)
	}

	func toCFGArray(startRule: String?) -> CFGArray<ClosedRangeAlphabet<UInt32>> {
		CFGArray(toCFG(startRule: startRule))
	}

	func updateParser(_ parser: RulelistAnalysis) {
		let snapshot = self
		parser.runUpdate {
			var seenAll = Set<String>();
			var all: [String] = [];
			var seenTops = Set<String>();
			var tops: [String] = [];
			for rule in snapshot.rules {
				if seenAll.insert(rule.name).inserted { all.append(rule.name) }
				if rule.top, seenTops.insert(rule.name).inserted { tops.append(rule.name) }
			}
			var referencedRuleNames: Dictionary<String, Array<String>> = {
				var referencedRuleNames: Dictionary<String, Array<String>> = [:];
				var seenRefs: Dictionary<String, Set<String>> = [:];
				for name in all {
					referencedRuleNames[name] = [];
				}
				for rule in snapshot.rules {
					for production in rule.productions {
						for element in production.body {
							guard case .nonterminal(let name) = element, name.isEmpty == false else { continue }
							if seenRefs[rule.name, default: []].insert(name).inserted {
								referencedRuleNames[rule.name, default: []].append(name);
							}
						}
					}
				}
				return referencedRuleNames;
			}();
			let primary = snapshot.rules.first?.name
			if Task.isCancelled { return }
			await MainActor.run {
				parser.primaryRuleName = primary;
				parser.topRuleNames = tops;
				parser.allRuleNames = all;
				parser.referencedRuleNames = referencedRuleNames;
				let old = parser.parsed(Array<Rule>.self)
				if old != snapshot.rules {
					parser.parsedSource = snapshot.rules;
					parser.parseRevision += 1;
				}
			}
		}
	}

	func compileRule(_ ruleName: String, from list: RulelistAnalysis, into rule: RuleAnalysis) {
		guard let rules = list.parsed(Array<Rule>.self) else { return }
		var compileSource = self
		compileSource.rules = rules
		rule.runCompile(ruleName: ruleName, from: list) { revision in
			if compileSource.rules.contains(where: { $0.name == ruleName }) == false {
				await MainActor.run {
					rule.error = "Unknown rule \(ruleName)";
					rule.compiledRevision = revision;
				}
				return
			}
			let cfg = compileSource.toCFG(startRule: ruleName);
			if Task.isCancelled { return }
			await MainActor.run {
				rule.error = nil;
				rule.cfg = cfg;
				rule.cfga = CFGArray(cfg);
				rule.chomskyClass = cfg.chomskyClass();
				rule.memoryRequirements = cfg.memoryRequirements();
				rule.compiledRevision = revision;
			}
		}
	}
}
