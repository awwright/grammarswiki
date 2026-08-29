import SwiftUI
import FSM
import Foundation

/// A combinator page: the language is the union of the named operand rules.
///
/// Operands are other rules in the notebook (or this document). The page exposes one
/// rule of its own (``ruleName``) whose language is the union of those operands.
struct UnionPage: PageProtocol, Hashable, Equatable {
	let id = UUID()
	var name: String
	var charset: String

	/// Ordered list of rule names whose languages are unioned.
	var operands: [Operand]

	var type: String { "Union" }

	/// One named rule included in the union.
	struct Operand: Hashable, Equatable, Identifiable {
		var id: UUID = UUID()
		var rulename: String
	}

	init() {
		self.name = "";
		self.charset = "UTF-32";
		self.operands = [];
	}

	init(name: String, charset: String = "UTF-32", operands: [Operand] = []) {
		self.name = name;
		self.charset = charset;
		self.operands = operands;
	}

	// MARK: PageProtocol XML
	static var xmlElementName: String { "union" }

	init(xmlElement: XMLElement) throws {
		guard xmlElement.name == Self.xmlElementName else {
			throw PageXMLError.unexpectedElement(expected: Self.xmlElementName, actual: xmlElement.name);
		}
		self.name = xmlElement.attribute(forName: "name")?.stringValue ?? "";
		self.charset = xmlElement.attribute(forName: "charset")?.stringValue ?? "UTF-32";
		self.operands = xmlElement.elements(forName: "ref").map { Operand(rulename: $0.stringValue ?? "") };
	}

	func toXMLElement() throws -> XMLElement {
		let el = XMLElement(name: Self.xmlElementName);
		el.setAttributesWith([
			"name": name,
			"charset": charset,
		]);
		for operand in operands {
			let ref = XMLElement(name: "ref");
			ref.setStringValue(operand.rulename, resolvingEntities: false);
			el.addChild(ref);
		}
		return el;
	}

	/// Primary / only rule name exposed to notebook analysis.
	var ruleName: String { name.isEmpty ? "S" : name }

	/// Non-empty operand names in document order, duplicates kept (union is idempotent).
	var operandNames: [String] {
		operands.map(\.rulename).filter { $0.isEmpty == false }
	}

	/// Open CFG: this rule as a choice of operand nonterminals (no inlining).
	func toOpenCFG() -> ABNFRulelist<UInt32>.CFG {
		let start = CFGRuleName(.rule(ruleName));
		let productions: [ABNFRulelist<UInt32>.CFG.Production] = operandNames.filter { $0 != ruleName }.map { name in
			.init(name: start, body: [.nonterminal(CFGRuleName(.rule(name)))])
		};
		return ABNFRulelist<UInt32>.CFG(start: start, productions: productions);
	}

	/// Railroad diagram: choice of each operand as a nonterminal.
	func toRailroad() -> RailroadNode {
		let items: [RailroadNode] = operandNames.map { name in
			.NonTerminal(text: name, attributes: [:])
		};
		if items.isEmpty {
			return .Choice(items: [], attributes: [:]);
		}
		if items.count == 1 {
			return items[0];
		}
		return .Choice(items: items, attributes: [:]);
	}

	// MARK: PageProtocol

	@ViewBuilder
	static func pageEditor(_ page: Binding<Self>) -> some View {
		UnionPageEditor(page: page)
	}

	func updateParser(_ parser: RulelistAnalysis) {
		let snapshot = self;
		parser.runUpdate {
			let ruleName = snapshot.ruleName;
			let refs = snapshot.operandNames.filter { $0 != ruleName };
			let recursive = snapshot.operandNames.filter { $0 == ruleName };
			if Task.isCancelled { return }
			await MainActor.run {
				parser.primaryRuleName = ruleName;
				parser.topRuleNames = [ruleName];
				parser.allRuleNames = [ruleName];
			}
			let cfg = snapshot.toOpenCFG();
			let cfga = CFGArray(cfg);
			let rr: RailroadNode = .Diagram(
				start: .Start(label: ruleName, attributes: [:]),
				sequence: [snapshot.toRailroad()],
				end: .End(label: nil, attributes: [:]),
				attributes: [:]
			);
			let chomskyClass = cfg.chomskyClass();
			let memoryRequirements = cfg.memoryRequirements();
			if Task.isCancelled { return }
			await MainActor.run {
				parser.selectedRule_cfg = cfg;
				parser.selectedRule_cfga = cfga;
				parser.selectedRule_rr = rr;
				parser.selectedRule_chomskyClass = chomskyClass;
				parser.selectedRule_memoryRequirements = memoryRequirements;
				parser.selectedRule_dependencies = [ruleName] + refs;
				parser.selectedRule_undefined = refs;
				parser.selectedRule_recursive = recursive;
			}
		}
	}
}

// MARK: - Editor

private struct UnionPageEditor: View {
	@Binding var page: UnionPage

	// TODO: Get the list of externally available rule names from somewhere
	var availableNames: [String] { [] }

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if page.operands.isEmpty {
				Text("Empty language (no rules)")
					.foregroundStyle(.secondary)
			}

			ForEach($page.operands) { $operand in
				HStack(alignment: .center, spacing: 8) {
					if let index = page.operands.firstIndex(where: { $0.id == operand.id }) {
						Text("\(index + 1).")
							.foregroundStyle(.secondary)
							.frame(width: 28, alignment: .trailing)
							.monospacedDigit()
					}

					TextField("Rule name", text: $operand.rulename, prompt: Text("rule"))
						.font(.system(.body, design: .monospaced))
						.textFieldStyle(.roundedBorder)

					// If there is a list of external rule names, show a picker for it
					if availableNames.isEmpty == false {
						Menu {
							ForEach(availableNames, id: \.self) { name in
								Button(name) { operand.rulename = name }
							}
						} label: {
							Image(systemName: "filemenu.and.selection")
						}
						.help("Choose a rule from this notebook")
					}

					Button(role: .destructive) {
						page.operands.removeAll { $0.id == operand.id }
					} label: {
						Image(systemName: "trash")
					}
					.help("Remove this rule")
				}
			}

			Button {
				page.operands.append(UnionPage.Operand(rulename: ""))
			} label: {
				Label("Add rule", systemImage: "plus.rectangle")
			}
		}
	}
}
