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

struct CFGContentView: View {
	public var grammar: ABNFRulelist<UInt32>.CFG;

	@State private var selectedRange: Bool = false
	@State private var selectedEliminateUseless: Bool = true
	@State private var selectedEliminateEpsilon: Bool = false
	@State private var selectedEliminateUnitProd: Bool = false
	@State private var selectedForm: String = ""
	@State private var selectedSortOrder: CFGContentView_SortOrder = .breadthFirst
	@State private var selectedCharset: String = ""
	@State private var selectedDialect: CFGContentView_Dialect = .bnf

	func filteredGrammar() -> ABNFRulelist<UInt32>.CFG {
		var grammar = self.grammar;
		if selectedEliminateUseless { grammar = grammar.eliminateUseless(); }
		if selectedEliminateEpsilon { grammar = grammar.eliminateEpsilon(); }
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
					Text("None").tag("")
					Text("Chomsky").tag("c")
					Text("Greibach").tag("g")
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
				Picker("Sort", selection: $selectedSortOrder) {
					Text("Breadth-first").tag("b")
					Text("Depth-first").tag("d")
					Text("Alphabetical").tag("a")
				}
				.pickerStyle(.segmented)

				// TODO: collapse tail recursive rules like:
				// rule = epsilon / element rule
				// into: rule = element*
				Toggle("Kleene star operator", isOn: $selectedRange)
				Toggle("Optional group operator", isOn: $selectedRange)

				Picker("Dialect", selection: $selectedDialect) {
					Text("BNF").tag(CFGContentView_Dialect.bnf)
				}
			}
			.pickerStyle(.menu)
			.formStyle(.grouped)

			VStack(alignment: .leading) {
				CFGContentView_BNF(grammar: grammar, selectedEliminateEpsilon: selectedEliminateEpsilon, selectedSortOrder: selectedSortOrder)
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
