import SwiftUI
import FSM
import Foundation

/// A Finite Choice page: a language that is exactly a finite set of strings.
/// Any listed string matches; nothing else does.
struct FCDocument: PageProtocol, Hashable, Equatable {
	let id = UUID()
	var name: String
	var charset: String

	/// The core editable data: ordered list of alternative matching strings.
	var choices: [Choice]

	var type: String { "FC" }

	/// One alternative string in the finite choice.
	struct Choice: Hashable, Equatable, Identifiable {
		var id: UUID = UUID()
		var string: String
	}

	init() {
		self.name = "";
		self.charset = "UTF-32";
		self.choices = [];
	}

	init(name: String, charset: String = "UTF-32", choices: [Choice] = []) {
		self.name = name;
		self.charset = charset;
		self.choices = choices;
	}

	// MARK: PageProtocol XML
	static var xmlElementName: String { "fc" }

	init(xmlElement: XMLElement) throws {
		guard xmlElement.name == Self.xmlElementName else {
			throw PageXMLError.unexpectedElement(expected: Self.xmlElementName, actual: xmlElement.name);
		}
		self.name = xmlElement.attribute(forName: "name")?.stringValue ?? "";
		self.charset = xmlElement.attribute(forName: "charset")?.stringValue ?? "UTF-32";
		self.choices = xmlElement.elements(forName: "s").map { Choice(string: $0.stringValue ?? "") };
	}

	func toXMLElement() throws -> XMLElement {
		let el = XMLElement(name: Self.xmlElementName);
		el.setAttributesWith([
			"name": name,
			"charset": charset,
		]);
		for choice in choices {
			let s = XMLElement(name: "s");
			s.setStringValue(choice.string, resolvingEntities: false);
			el.addChild(s);
		}
		return el;
	}

	/// Primary / only rule name exposed to notebook analysis.
	var ruleName: String { name.isEmpty ? "S" : name }

	/// Build a DFA that accepts exactly the listed strings (union of verbatim paths).
	func toDFA() -> DFA<ClosedRangeAlphabet<UInt32>> {
		let parts: [DFA<ClosedRangeAlphabet<UInt32>>] = choices.map { choice in
			let symbols = choice.string.unicodeScalars.map { UInt32($0.value) }
			return DFA<ClosedRangeAlphabet<UInt32>>(verbatim: symbols);
		}
		return DFA.union(parts).minimized();
	}

	/// Build a CFG with one production per string under a single start symbol.
	func toCFG() -> ABNFRulelist<UInt32>.CFG {
		let start = CFGRuleName(.rule(ruleName))
		let productions: [ABNFRulelist<UInt32>.CFG.Production] = choices.map { choice in
			let body: [ABNFRulelist<UInt32>.CFG.BodyElement] = choice.string.unicodeScalars.map { scalar in
				.terminal(ClosedRangeAlphabet.symbol(UInt32(scalar.value)))
			}
			return .init(name: start, body: body);
		}
		return ABNFRulelist<UInt32>.CFG(start: start, productions: productions);
	}

	/// Railroad diagram: choice of each literal string (ε shown as Skip).
	func toRailroad() -> RailroadNode {
		let items: [RailroadNode] = choices.map { choice in
			if choice.string.isEmpty {
				return .Skip(attributes: [:]);
			}
			return .Terminal(text: choice.string, attributes: [:]);
		}
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
		FCPageEditor(page: page)
	}

	@Observable class Parser: DocumentParserProtocol {
		typealias Document = FCDocument

		required init() {
			document = nil;
			self._task = Task{};
			document_error = nil;
			topRuleNames = [];
			allRuleNames = [];
		}

		deinit { _task.cancel() }

		var document: Document? { didSet { _update(); } }
		var document_error: String? = nil
		var primaryRuleName: String? = nil
		var topRuleNames: Array<String> = []
		var allRuleNames: Array<String> = []

		var selectedRulename: String? { didSet { _update(); } }
		var selectedRule_error: String? = nil
		var selectedRule_alphabet: ClosedRangeAlphabet<UInt32>? = nil
		var selectedRule_fsm: DFA<ClosedRangeAlphabet<UInt32>>? = nil
		var selectedRule_cfg: ABNFRulelist<UInt32>.CFG? = nil
		var selectedRule_cfga: CFGArray<ClosedRangeAlphabet<UInt32>>? = nil
		var selectedRule_rr: RailroadNode? = nil
		var selectedRule_complexityClass: Int? = nil
		var selectedRule_chomskyClass: Int? = nil
		var selectedRule_memoryRequirements: Int? = nil

		var _task: Task<(), Never>
		func _update() {
			_task.cancel();
			document_error = nil;
			selectedRule_error = nil;

			_task = Task {
				guard let document else { return }
				let ruleName = document.ruleName;
				if Task.isCancelled { return }
				await MainActor.run {
					self.primaryRuleName = ruleName;
					self.topRuleNames = [ruleName];
					self.allRuleNames = [ruleName];
				}

				// Finite choice is a single language; analyze regardless of selectedRulename.
				if Task.isCancelled { return }
				let selectedRule_fsm = document.toDFA();
				let selectedRule_alphabet = selectedRule_fsm.alphabet;
				let selectedRule_cfg = document.toCFG();
				let selectedRule_cfga = CFGArray(selectedRule_cfg);
				let selectedRule_rr: RailroadNode = .Diagram(
					start: .Start(label: ruleName, attributes: [:]),
					sequence: [document.toRailroad()],
					end: .End(label: nil, attributes: [:]),
					attributes: [:]
				);
				let selectedRule_chomskyClass = selectedRule_cfg.chomskyClass();
				let selectedRule_memoryRequirements = selectedRule_cfg.memoryRequirements();
				if Task.isCancelled { return }
				await MainActor.run {
					self.selectedRule_alphabet = selectedRule_alphabet;
					self.selectedRule_fsm = selectedRule_fsm;
					self.selectedRule_cfg = selectedRule_cfg;
					self.selectedRule_cfga = selectedRule_cfga;
					self.selectedRule_rr = selectedRule_rr;
					self.selectedRule_chomskyClass = selectedRule_chomskyClass;
					self.selectedRule_memoryRequirements = selectedRule_memoryRequirements;
				}
			}
		}
	}
}

// MARK: - Editor

private struct FCPageEditor: View {
	@Binding var page: FCDocument

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if page.choices.isEmpty {
				Text("Empty set language")
					.foregroundStyle(.secondary)
			}

			// Bind via $page.choices so each row is identity-stable, not index-stable.
			ForEach($page.choices) { $choice in
				HStack(alignment: .center, spacing: 8) {
					if let index = page.choices.firstIndex(where: { $0.id == choice.id }) {
						Text("\(index + 1).")
							.foregroundStyle(.secondary)
							.frame(width: 28, alignment: .trailing)
							.monospacedDigit()
					}

					TextField("String", text: $choice.string, prompt: Text("ε"))
						.font(.system(.body, design: .monospaced))
						.textFieldStyle(.roundedBorder)

					Button(role: .destructive) {
						page.choices.removeAll { $0.id == choice.id }
					} label: {
						Image(systemName: "trash")
					}
					.help("Remove this string")
				}
			}

			Button {
				page.choices.append(FCDocument.Choice(string: ""))
			} label: {
				Label("Add string", systemImage: "plus.rectangle")
			}
		}
	}
}
