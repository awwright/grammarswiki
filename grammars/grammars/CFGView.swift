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

	func filteredGrammar() -> ABNFRulelist<UInt32>.CFG {
		var grammar = self.grammar;
		if selectedEliminateUseless { grammar = grammar.eliminateUseless(); }
		if selectedEliminateEpsilon { grammar = grammar.eliminateEpsilon(); }
		if selectedEliminateUnitProd { grammar = grammar.eliminateUnitProduction(); }
		// Run this again because "eliminate unit productions" often adds many useless productions
		if selectedEliminateUseless { grammar = grammar.eliminateUseless(); }
		return grammar;
	}

	var body: some View {
		let grammar = self.filteredGrammar();
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
				Toggle("Kleene star operator", isOn: $selectedRange)
				Toggle("Optional group operator", isOn: $selectedRange)

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
					CFGContentView_BNF(grammar: grammar, selectedEliminateEpsilon: selectedEliminateEpsilon, selectedSortOrder: selectedSortOrder)
				case .swift_cfg:
					CFGContentView_SwiftCFG(grammar: grammar, selectedSortOrder: selectedSortOrder)
				}
			}
			.frame(maxWidth: .infinity, alignment: .topLeading)
		}
	}
}

struct CFGContentView_BNF: View {
	let grammar: ABNFRulelist<UInt32>.CFG
	let selectedEliminateEpsilon: Bool
	let selectedSortOrder: CFGContentView_SortOrder

	@Environment(SelectedCharset.self) private var charset;

	var body: some View {
		ForEach(grammar.start, id: \.self) { rulename in
			Text("\u{2192} \(rulename)")
		}
		if selectedEliminateEpsilon && self.grammar.contains([]) {
			// If the "eliminate epsilon productions" option removed epsilon from the language, add it back here
			Text("\u{2192} \u{3B5}") // Epsilon
		}
		if grammar.start.isEmpty {
			Text("\u{2192} \u{2205}")
		}
		Spacer()
		let dictionary = grammar.dictionary
		let ruleNames = switch(selectedSortOrder) {
			case .breadthFirst: grammar.ruleNames;
			case .depthFirst: grammar.ruleNamesDepthFirst;
			case .name: grammar.ruleNames.sorted();
		}
		ForEach(ruleNames, id: \.self) { (ruleName: ABNFRulelist<UInt32>.CFG.Variable) in
			let rules = dictionary[ruleName] ?? []
			Text("\(ruleName)").font(.headline);
			if rules.isEmpty {
				Text("\t= \u{2205}");
			}
			ForEach(rules, id: \.self) { rule in
				// FIXME: This will squish rather than wrap
				HStack {
					Text("\t\u{2192} ")
					ForEach(rule.body, id: \.self) { (token: ABNFRulelist<UInt32>.CFG.BodyElement) in
						switch token {
							case .terminal(let sym): Text(charset.describe(sym)).monospaced()
							case .nonterminal(let name): Text(name.description)
							default: Text(String(describing: token))
						}
					}
					if rule.body.isEmpty {
						Text("\u{3B5}") // Epsilon
					}
				}
			}
			Spacer()
		}

	}
}

struct CFGContentView_SwiftCFG: View {
	let grammar: ABNFRulelist<UInt32>.CFG
	let selectedSortOrder: CFGContentView_SortOrder

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
		let ruleNames: [ABNFRulelist<UInt32>.CFG.Variable] = switch selectedSortOrder {
			case .breadthFirst: grammar.ruleNames
			case .depthFirst: grammar.ruleNamesDepthFirst
			case .name: grammar.ruleNames.sorted()
		}

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
