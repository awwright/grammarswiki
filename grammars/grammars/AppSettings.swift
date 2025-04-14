import SwiftUI

// Preferences view
struct SettingsView: View {
	@AppStorage("showAlphabet") private var showAlphabet: Bool = true
	@AppStorage("showStateCount") private var showStateCount: Bool = true
	@AppStorage("showFSM") private var showFSM: Bool = true
	@AppStorage("showRegex") private var showRegex: Bool = true
	@AppStorage("showGraphViz") private var showGraphViz: Bool = true
	@AppStorage("showInstances") private var showInstances: Bool = true
	@AppStorage("showTestInput") private var showTestInput: Bool = true
	@AppStorage("regexDialect") private var regexDialect: String = RegexDialect.posix.rawValue

	var body: some View {
		Form {
			Section(header: Text("Pattern Display Options").font(.headline)) {
				Toggle("Show Alphabet", isOn: $showAlphabet)
				Toggle("Show State Count", isOn: $showStateCount)
				Toggle("Show FSM", isOn: $showFSM)
				Toggle("Show Regex", isOn: $showRegex)
				Toggle("Show GraphViz", isOn: $showGraphViz)
				Toggle("Show Example Instances", isOn: $showInstances)
				Toggle("Show Test Input", isOn: $showTestInput)
				Picker("Regex Dialect", selection: $regexDialect) {
					ForEach(RegexDialect.allCases) { dialect in
						Text(dialect.rawValue).tag(dialect.rawValue)
					}
				}
				.pickerStyle(.menu) // Use a dropdown menu style
				.frame(width: 300)
			}
		}
		.padding()
	}
}

// Enum to represent regex dialects
enum RegexDialect: String, CaseIterable, Identifiable {
	case posix = "POSIX"            // Standard POSIX regular expressions
	case pcre = "PCRE"              // Perl-Compatible Regular Expressions
	case ecma = "ECMA"              // ECMAScript (JavaScript-style regex)
	case java = "Java"              // Java's regex (java.util.regex)
	case python = "Python"          // Python's re module
	case ruby = "Ruby"              // Ruby's regex
	case perl = "Perl"              // Perl's native regex
	case re2 = "RE2"                // Google's RE2 regex engine
	case rust = "Rust"              // Rust's regex crate
	case go = "Go"                  // Go's regexp package
	case pcre2 = "PCRE2"            // Updated PCRE version

	var id: String { self.rawValue }
}

#Preview {
	SettingsView()
}
