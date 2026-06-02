import SwiftUI
import FSM

struct RuleInformationView: View {
	let content_rulelist: ABNFRulelist<UInt32>?;
	let grammar: ABNFRulelist<UInt32>.CFG?;
	let selectedRule: String?;
	let rule_fsm: DFA<ClosedRangeAlphabet<UInt32>>?;
	let rule_alphabet: ClosedRangeAlphabet<UInt32>?;

	@AppStorage("expandedRule_deps") private var rule_deps_expanded = true
	@AppStorage("expandedRule_builtin") private var rule_builtin_expanded = true
	@AppStorage("expandedRule_undefined") private var rule_undefined_expanded = true
	@AppStorage("expandedRule_recursive") private var rule_recursive_expanded = true
	@AppStorage("expandedAlphabet") private var alphabet_expanded = true
	@Environment(SelectedCharset.self) private var charset;

	@AppStorage("showAlphabet") private var showAlphabet: Bool = true
	@AppStorage("showStateCount") private var showStateCount: Bool = true
	@AppStorage("showFSM") private var showFSM: Bool = true

	@State private var fsm_expanded = true

	@State private var content_cfg_complexityClass: Int? = nil
	@State private var content_cfg_chomskyClass: Int? = nil
	@State private var content_cfg_memoryRequirements: Int? = nil

	var body: some View {
		if let content_rulelist, let selectedRule {
			let deps = content_rulelist.dependencies(rulename: selectedRule)
			DisclosureGroup("Rule Dependencies", isExpanded: $rule_deps_expanded, content: {
				Text(String(deps.dependencies.reversed().joined(separator: ", ")))
			})
			if(deps.builtins.isEmpty == false){
				DisclosureGroup("Implicit Builtins", isExpanded: $rule_builtin_expanded, content: {
					Text(String(deps.builtins.joined(separator: ", ")))
				})
			}
			if(deps.undefined.isEmpty == false){
				DisclosureGroup("Undefined Rules", isExpanded: $rule_undefined_expanded, content: {
					Text(String(deps.undefined.joined(separator: ", ")))
				})
			}
			if(deps.recursive.isEmpty == false){
				DisclosureGroup("Recursive Rules", isExpanded: $rule_recursive_expanded, content: {
					Text(String(deps.recursive.joined(separator: ", ")))
				})
			}
		}

		if showAlphabet {
			DisclosureGroup("Alphabet", isExpanded: $alphabet_expanded, content: {
				if let rule_alphabet: ClosedRangeAlphabet<UInt32> = rule_alphabet {
					let rule_alphabet_sorted: [ClosedRangeAlphabet<UInt32>.SymbolClass] = Array(rule_alphabet)
					ForEach(rule_alphabet_sorted, id: \.self) {
						(part: ClosedRangeAlphabet<UInt32>.SymbolClass) in
						Text(charset.describe(part)).frame(maxWidth: .infinity, alignment: .leading).padding(1).border(Color.gray, width: 0.5)
					}
				}else{
					Text("Computing alphabet...")
						.foregroundColor(.gray)
				}
			})
		}

		if showStateCount {
			DisclosureGroup("Language Info", isExpanded: $fsm_expanded, content: {
				Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
					GridRow(alignment: .top) {
						Text("Complexity Class").font(.headline).gridColumnAlignment(.trailing)
						// Higher numbers are more complicated:
						// TODO: Read this from the CFG or PDA
						DisclosureGroup("4: Context-free") {
							VStack(alignment: .leading) {
								Text("0: Finite")
								Text("1: Regular")
								Text("2: Deterministic Pushdown")
								Text("3: Unambiguous Context-free")
								Text("4: Context-Free").bold()
							}.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
					if let content_cfg_chomskyClass {
						GridRow(alignment: .top) {
							Text("Chomsky Class").font(.headline).gridColumnAlignment(.trailing)
							// Higher numbers have more limitations and more functionality:
							let label = switch content_cfg_chomskyClass {
							case 0: "0: Unrestricted"
							case 1: "1: Context-sensitive"
							case 2: "2: Context-free"
							case 3: "3: Regular"
							case 4: "4: Finite choice"
							default: "(Unknown)"
							};
							DisclosureGroup(label) {
								VStack(alignment: .leading) {
									Text("0: Unrestricted").bold(content_cfg_chomskyClass == 0)
									Text("1: Context-sensitive").bold(content_cfg_chomskyClass == 1)
									Text("2: Context-free").bold(content_cfg_chomskyClass == 2)
									Text("3: Regular").bold(content_cfg_chomskyClass == 3)
									Text("4: Finite choice").bold(content_cfg_chomskyClass == 4)
								}.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
					}
					if let content_cfg_memoryRequirements {
						GridRow(alignment: .top) {
							Text("Memory Complexity").font(.headline).gridColumnAlignment(.trailing)
							// TODO: Can I deduplicate these labels somehow?
							let label = switch content_cfg_memoryRequirements {
							case 0: "O(1): Constant"
							case 1: "O(log n): Logrimithic"
							case 2: "O(n): Linear"
							case 3: "O(n log n): Log-linear"
							case 4: "O(n²): Quadratic"
							case 5: "O(n³): Cubic"
							default: "(Unknown)"
							};
							DisclosureGroup(label) {
								VStack(alignment: .leading) {
									Text("O(1): Constant").bold(content_cfg_memoryRequirements == 0)
									Text("O(log n): Logrimithic").bold(content_cfg_memoryRequirements == 1)
									Text("O(n): Linear").bold(content_cfg_memoryRequirements == 2)
									Text("O(n log n): Log-linear").bold(content_cfg_memoryRequirements == 3)
									Text("O(n²): Quadratic").bold(content_cfg_memoryRequirements == 4)
									Text("O(n³): Cubic").bold(content_cfg_memoryRequirements == 5)
								}.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
					}
					GridRow(alignment: .top) {
						Text("CPU Complexity").font(.headline).gridColumnAlignment(.trailing)
						Text("(Undetermined)")
					}
					if let rule_fsm {
						GridRow(alignment: .top) {
							Text("FSM States").font(.headline).gridColumnAlignment(.trailing)
							Text(String(rule_fsm.states.count))
						}
					}
					// TODO: Estimate entropy by measuring selection of states per byte
				}
			})
		}
	}
	
}
