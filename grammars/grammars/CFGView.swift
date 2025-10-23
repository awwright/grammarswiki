import SwiftUI;
import FSM;

struct CFGContentView: View {
	public var grammar: SymbolCFG<UInt32>;
	public var charset: Charset;

	@State private var selectedDialect: String = "bnf"

	var body: some View {
		ScrollView {
			Form {
				Picker("Dialect", selection: $selectedDialect) {
					Text("BNF").tag("bnf")
				}
			}
			.pickerStyle(.menu)
			.formStyle(.grouped)

			VStack(alignment: .leading) {
				Text("\u{2192} \(grammar.start)")
				Spacer()
				let dictionary = grammar.dictionary
				let ruleNames = grammar.ruleNames;
				ForEach(ruleNames, id: \.self) { ruleName in
					let rules = dictionary[ruleName] ?? []
					Text("\(ruleName)").font(.headline);
					if rules.isEmpty {
						Text("\t= \u{2205}");
					}
					ForEach(rules, id: \.self) { rule in
						HStack {
							Text("\t\u{2192} ")
							ForEach(rule.production, id: \.self) { (token: CFGSymbol<UInt32>) in
								switch token {
								case .terminal(let sym): Text(charset.toQuoted(sym)).monospaced()
								case .range(let lower, let upper): Text(charset.toQuoted(lower) + "\u{22EF}" + charset.toQuoted(upper)).monospaced()
								case .rule(let name): Text(name)
								default: Text(String(describing: token))
								}
							}
							if rule.production.isEmpty {
								Text("\u{3B5}") // Epsilon
							}
						}
					}
					Spacer()
				}
			}
			.frame(maxWidth: .infinity, alignment: .topLeading)
		}
	}
}
