import SwiftUI;
import FSM;

struct CFGContentView: View {
	public var grammar: SymbolCFG<UInt32>;
	public var charset: Charset;

	@State private var selectedDialect: String = "bnf"
	@State private var selectedRange: Bool = false
	@State private var selectedEliminateUseless: Bool = true
	@State private var selectedEliminateEpsilon: Bool = false
	@State private var selectedForm: String = ""
	@State private var selectedMatchType: String = "b"
	@State private var selectedCharset: String = ""

	var body: some View {
		ScrollView {
			Form {
				Picker("Dialect", selection: $selectedDialect) {
					Text("BNF").tag("bnf")
				}

				Toggle("Range operator", isOn: $selectedRange)

				Toggle("Eliminate useless prodictions", isOn: $selectedEliminateEpsilon)

				// TODO: If this is selected, and epsilon is in the language, then include epsilon in the set of start symbols.
				// Because ordinarily "eliminate epsilon" removes it from the resulting language.
				Toggle("Eliminate epsilon", isOn: $selectedEliminateUseless)

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
				Picker("Sort", selection: $selectedMatchType) {
					Text("Breadth-first").tag("b")
					Text("Depth-first").tag("d")
					Text("Alphabetical").tag("a")
				}
				.pickerStyle(.segmented)
			}
			.pickerStyle(.menu)
			.formStyle(.grouped)

			VStack(alignment: .leading) {
				Text("\u{2192} \(grammar.start)")
				Spacer()
				let dictionary = grammar.dictionary
				let ruleNames = grammar.ruleNames;
				ForEach(ruleNames, id: \.self) { (ruleName: String) in
					let rules = dictionary[ruleName] ?? []
					Text("\(ruleName)").font(.headline);
					if rules.isEmpty {
						Text("\t= \u{2205}");
					}
					ForEach(rules, id: \.self) { rule in
						HStack {
							Text("\t\u{2192} ")
							ForEach(rule.production, id: \.self) { (token: SymbolCFG<UInt32>.Term) in
								switch token {
								case .symbol(let sym): Text(charset.toQuoted(sym)).monospaced()
//								case .range(let lower, let upper): Text(charset.toQuoted(lower) + "\u{22EF}" + charset.toQuoted(upper)).monospaced()
								case .variable(let name): Text(name)
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
