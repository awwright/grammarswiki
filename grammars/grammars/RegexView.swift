import SwiftUI
import FSM

struct RegexContentView: View {
	@Binding var rule_fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>?
	@State private var regexDescription: String?
	@State private var error: String?
	//@State private var option_exclude_rules: String = ""

	@AppStorage("regexDialect") private var regexDialect: String = RegexDialect.posix.rawValue

	var body: some View {
		VStack(spacing: 0) {
			Form {
				Section(header: Text("Format Options").font(.headline)) {
					Picker("Regex Dialect", selection: $regexDialect) {
						ForEach(RegexDialect.allCases) { dialect in
							Text(dialect.rawValue).tag(dialect.rawValue)
						}
					}
					.pickerStyle(.menu)
					.frame(width: 300)

					//TextField("Exclude rules", text: $option_exclude_rules);
				}
			}
			.padding()

			Button(action: {
				if let copyText = regexDescription {
#if os(macOS)
					let pasteboard = NSPasteboard.general
					pasteboard.clearContents()
					pasteboard.setString(copyText, forType: .string)
#elseif os(iOS)
					UIPasteboard.general.string = copyText
#endif
				}
			}) {
				Text("Copy to Clipboard")
			}
			.padding()
			.disabled(regexDescription == nil)

			ScrollView {
				if let regexDescription = regexDescription {
					Text(regexDescription)
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
						.padding()
						.border(Color.gray, width: 1)
				} else if let error = error {
					Text("Error: \(error)")
						.foregroundColor(.red)
				} else {
					Text("Building...")
						.foregroundColor(.gray)
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onAppear { computeRegexDescription() }
		.onChange(of: rule_fsm) { computeRegexDescription() }
	}

	private func computeRegexDescription() {
		regexDescription = nil
		error = nil
		guard let fsm = rule_fsm else {
			return
		}
		Task.detached(priority: .utility) {
			let regex: REPattern<UInt32> = fsm.toPattern()
			let description = regex.description
			await MainActor.run {
				regexDescription = description
				error = nil
			}
		}
	}
}
