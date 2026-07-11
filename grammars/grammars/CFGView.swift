import SwiftUI;
import FSM;

enum CFGContentView_SortOrder {
	case breadthFirst;
	case depthFirst;
	case name;
}

enum CFGContentView_Dialect {
	case bnf;
	case swift_cfg;
}

enum CFGContentView_Form {
	case none;
	case chomsky;
	case greibach;
}

struct CFGContentView: View {
	public var grammar: ABNFRulelist<UInt32>.CFG;

	@State private var selectedRange: Bool = false
	@State private var selectedEliminateUseless: Bool = true
	@State private var selectedEliminateEpsilon: Bool = false
	@State private var selectedEliminateUnitProd: Bool = false
	@State private var selectedForm: CFGContentView_Form = .none
	@State private var selectedSortOrder: CFGContentView_SortOrder = .breadthFirst
	@State private var selectedCharset: String = ""
	@State private var selectedDialect: CFGContentView_Dialect = .bnf

	var filteredGrammar: ABNFRulelist<UInt32>.CFG {
		var grammar = self.grammar;
		if selectedEliminateUseless { grammar = grammar.eliminateUseless(); }
		if selectedEliminateEpsilon { grammar = grammar.eliminateEpsilon(); }
		if selectedEliminateUnitProd { grammar = grammar.eliminateUnitProduction(); }
		// Run this again because "eliminate unit productions" often adds many useless productions
		if selectedEliminateUseless { grammar = grammar.eliminateUseless(); }
		return grammar;
	}

	var sortedRules: Array<ABNFRulelist<UInt32>.CFG.Variable> {
		switch selectedSortOrder {
			case .breadthFirst: grammar.ruleNames;
			case .depthFirst: grammar.ruleNamesDepthFirst;
			case .name: grammar.ruleNames.sorted();
		}
	}

	var body: some View {
		let grammar = self.filteredGrammar;
		ScrollView {
			Form {
				Toggle("Eliminate useless prodictions", isOn: $selectedEliminateUseless)

				Toggle("Eliminate epsilon productions", isOn: $selectedEliminateEpsilon)

				Toggle("Eliminate unit productions", isOn: $selectedEliminateUnitProd)

				Picker("Normalize", selection: $selectedForm) {
					Text("None").tag(CFGContentView_Form.none)
					Text("Chomsky").tag(CFGContentView_Form.chomsky)
					Text("Greibach").tag(CFGContentView_Form.greibach)
				}
				.pickerStyle(.segmented)

				Picker("Charset", selection: $selectedCharset) {
					Text("Preserve").tag("")
					Text("UTF-8").tag("UTF-8")
					Text("UTF-16").tag("UTF-16")
					Text("UTF-32").tag("UTF-32")
					Text("ISO-8859-1 (Latin-1)").tag("ISO-8859-1")
				}

				// TODO: Disable this if it seems like it wouldn't make a difference
				Picker("Sort Rules", selection: $selectedSortOrder) {
					Text("Breadth-first").tag(CFGContentView_SortOrder.breadthFirst)
					Text("Depth-first").tag(CFGContentView_SortOrder.depthFirst)
					Text("Alphabetical").tag(CFGContentView_SortOrder.name)
				}
				.pickerStyle(.segmented)

				// TODO: collapse tail recursive rules like:
				// rule = epsilon / element rule
				// into: rule = element*
				//Toggle("Kleene star operator", isOn: $selectedRange)
				//Toggle("Optional group operator", isOn: $selectedRange)

				Picker("Dialect", selection: $selectedDialect) {
					Text("BNF").tag(CFGContentView_Dialect.bnf)
					Text("Swift CFG").tag(CFGContentView_Dialect.swift_cfg)
				}
			}
			.pickerStyle(.menu)
			.formStyle(.grouped)

			VStack(alignment: .leading) {
				switch selectedDialect {
				case .bnf:
					CFGContentView_BNF(grammar: grammar, ruleNames: self.sortedRules, selectedEliminateEpsilon: selectedEliminateEpsilon)
				case .swift_cfg:
					CFGContentView_SwiftCFG(grammar: grammar, ruleNames: self.sortedRules)
				}
			}
			.frame(maxWidth: .infinity, alignment: .topLeading)
		}
	}
}

struct CFGContentView_BNF: View {
	let grammar: ABNFRulelist<UInt32>.CFG
	let ruleNames: Array<ABNFRulelist<UInt32>.CFG.Variable>
	let selectedEliminateEpsilon: Bool

	@Environment(SelectedCharset.self) private var charset;

	var body: some View {
		Text(generatedCode)
			.textSelection(.enabled)
			.frame(maxWidth: .infinity, alignment: .topLeading)
	}

	private var generatedCode: AttributedString {
		var result = AttributedString();

		// Start symbols
		if !grammar.start.isEmpty {
			for rulename in grammar.start {
				var arrow = AttributedString("\u{2192}");
				arrow.font = .headline;
				result += arrow + " " + AttributedString(rulename.description) + "\n";
			}
		} else {
			var empty = AttributedString("\u{2192} \u{2205}\n");
			empty.foregroundColor = .secondary;
			result += empty;
		}

		// Show epsilon, if it was eliminated earlier
		if selectedEliminateEpsilon && self.grammar.contains([]) {
			var epsilon = AttributedString("\u{2192} \u{3B5}\n");
			epsilon.foregroundColor = .orange;
			result += epsilon;
		}
		// Empty line
		result += "\n";

		let dictionary = grammar.dictionary

		for ruleName in ruleNames {
			let rules = dictionary[ruleName] ?? [];

			// Rule name (headline)
			var namePart = AttributedString(ruleName.description);
			namePart.font = .headline;
			result += namePart + "\n";

			if rules.isEmpty {
				result += "\u{2192} \u{2205}\n";
				continue;
			}

			for rule in rules {
				var arrow = AttributedString("\t\u{2192}")
				arrow.foregroundColor = .secondary
				result += arrow

				if rule.body.isEmpty {
					var eps = AttributedString(" \u{3B5}\n")
					eps.foregroundColor = .orange
					result += eps
				} else {
					for token in rule.body {
						switch token {
						case .terminal(let sym):
							var term = AttributedString(charset.describe(sym));
							term.font = .body.monospaced();
							term.foregroundColor = .purple;
							result += " " + term;

						case .nonterminal(let name):
							result += " " + AttributedString(name.description);

						default:
							result += " " + AttributedString(String(describing: token));
						}
					}
					result += "\n";
				}
			}

			// Empty line between rules
			result += "\n";
		}

		return result;
	}
}

struct CFGContentView_SwiftCFG: View {
	let grammar: ABNFRulelist<UInt32>.CFG
	let ruleNames: Array<ABNFRulelist<UInt32>.CFG.Variable>

	var body: some View {
		Text(generatedCode)
			.font(.system(.body, design: .monospaced))
			.textSelection(.enabled)
			.frame(maxWidth: .infinity, alignment: .topLeading)
	}

	/// Swift source that reconstructs `grammar` as an `ABNFRulelist<UInt32>.CFG`.
	private var generatedCode: String {
		if grammar.start.isEmpty && grammar.productions.isEmpty {
			return "ABNFRulelist<UInt32>.CFG()";
		}

		let dictionary = grammar.dictionary;

		var lines: [String] = [];
		lines.append("ABNFRulelist<UInt32>.CFG(");
		if grammar.start.count == 1 {
			lines.append("\tstart: \(swiftVariable(grammar.start.first!)),");
		} else {
			lines.append("\tstartSet: [");
			for start in grammar.start {
				lines.append("\t\t\(swiftVariable(start)),");
			}
			// Preserve the empty-start case so the generated code matches the value.
			if grammar.start.isEmpty {
				// nothing; empty array
			}
			lines.append("\t],");
		}
		lines.append("\tproductions: [");

		for ruleName in ruleNames {
			let rules = dictionary[ruleName] ?? []
			for rule in rules {
				lines.append(contentsOf: swiftProduction(rule).map { "\t\t\($0)" });
			}
		}

		// Emit any remaining productions not reached via ruleNames ordering (should be rare).
		let listed = Set(ruleNames);
		for production in grammar.productions where !listed.contains(production.name) {
			lines.append(contentsOf: swiftProduction(production).map { "\t\t\($0)" });
		}

		lines.append("\t]");
		lines.append(")");
		return lines.joined(separator: "\n");
	}

	/// Formats a single production as one or more source lines (including a trailing comma).
	private func swiftProduction(_ rule: ABNFRulelist<UInt32>.CFG.Production) -> [String] {
		let name = swiftVariable(rule.name);
		if rule.body.isEmpty {
			return [".init(name: \(name), body: []),"];
		}
		let elements = rule.body.map(swiftBodyElement);
		if elements.count == 1 {
			return [".init(name: \(name), body: [\(elements[0])]),"];
		}
		var lines: [String] = [];
		lines.append(".init(");
		lines.append("\tname: \(name),");
		lines.append("\tbody: [");
		for element in elements {
			lines.append("\t\t\(element),");
		}
		lines.append("\t]");
		lines.append("),");
		return lines;
	}

	/// Formats a `CFGRuleName` as a `CFGRuleName` array literal.
	private func swiftVariable(_ name: CFGRuleName) -> String {
		let components = name.components.map { component -> String in
			switch component {
				case .rule(let s): ".rule(\(s.debugDescription))"
				case .alternate(let i): ".alternate(\(i))"
				case .concat(let i): ".concat(\(i))"
				case .repetition(let i): ".repetition(\(i))"
				case .star: ".star"
				case .optional: ".optional"
			}
		}
		return "[\(components.joined(separator: ", "))]";
	}

	/// Formats a production body element.
	private func swiftBodyElement(_ element: ABNFRulelist<UInt32>.CFG.BodyElement) -> String {
		switch element {
			case .terminal(let sym): ".terminal(\(swiftTerminal(sym)))"
			case .nonterminal(let name): ".nonterminal(\(swiftVariable(name)))"
		}
	}

	/// Formats a `ClosedRangeAlphabet` symbol class as `[lower...upper, ...]`.
	private func swiftTerminal(_ sym: ClosedRangeAlphabet<UInt32>.SymbolClass) -> String {
		let ranges = sym.map { range -> String in "\(swiftHex(range.lowerBound))...\(swiftHex(range.upperBound))" }
		return "[\(ranges.joined(separator: ", "))]";
	}

	private func swiftHex(_ value: UInt32) -> String {
		"0x\(String(value, radix: 16, uppercase: true))"
	}
}
