import SwiftUI;
import FSM;

extension CFGSymbol where Symbol == UInt32 {
	var displayString: String {
		switch self {
		case .terminal(let sym):
			return String(UnicodeScalar(sym)!)
		case .rule(let name):
			return name
		}
	}
}

struct CFGContentView: View {
	public var grammar: SymbolCFG<UInt32>;
	var body: some View {
		ScrollView {
			ForEach(grammar.rules, id: \.self) { rule in
				Text("\(rule.name) \u{2192} \(rule.production.map(\.displayString).joined(separator: " "))")
			}
		}
	}
}
