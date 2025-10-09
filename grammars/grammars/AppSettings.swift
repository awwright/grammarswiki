import SwiftUI

// Preferences view
struct SettingsView: View {
	@AppStorage("showAlphabet") private var showAlphabet: Bool = true
	@AppStorage("showStateCount") private var showStateCount: Bool = true
	@AppStorage("showFSM") private var showFSM: Bool = true
	@AppStorage("showRegex") private var showRegex: Bool = true
	@AppStorage("showExport") private var showExport: Bool = true
	@AppStorage("showInstances") private var showInstances: Bool = true
	@AppStorage("showTestInput") private var showTestInput: Bool = true
	@AppStorage("regexDialect") private var regexDialect: String = RegexDialect.swift.rawValue
	@AppStorage("graphvizEnabled") private var graphvizEnabled: Bool = false
	@AppStorage("graphvizDot") private var graphvizDot: String = ""
	@AppStorage("wiresharkEnabled") private var wiresharkEnabled: Bool = false
	@AppStorage("wiresharkExts") private var wiresharkExts: String = ""

	var body: some View {
		TabView {
			Tab("Display", systemImage: "eye") {
				Form {
					Toggle("Show Alphabet", isOn: $showAlphabet)
					Toggle("Show State Count", isOn: $showStateCount)
					Toggle("Show FSM", isOn: $showFSM)
					Toggle("Show Regex", isOn: $showRegex)
					Toggle("Show GraphViz", isOn: $showExport)
					Toggle("Show Example Instances", isOn: $showInstances)
					Toggle("Show Test Input", isOn: $showTestInput)
					Picker("Regex Dialect", selection: $regexDialect) {
						ForEach(RegexDialect.allCases) { dialect in
							Text(dialect.rawValue).tag(dialect.rawValue)
						}
					}
				}
			}
			Tab("Tools", systemImage: "book.and.wrench") {
				Form {
					Section("Graphviz") {
						Toggle("Preview with Graphviz", isOn: $graphvizEnabled)
						TextField("dot file path", text: $graphvizDot)
					}
					Section("Wireshark") {
						Toggle("Wireshark Extensions", isOn: $wiresharkEnabled)
						TextField("Extensions path", text: $wiresharkExts)
					}
				}
			}
		}
		.frame(width: 450, alignment: .leading)
		.formStyle(.grouped)
		.padding()
	}
}

// Enum to represent regex dialects
enum RegexDialect: String, CaseIterable, Identifiable {
	case swift = "Swift"            // Swift regular expression parser
	case nsregularrxpression = "NSRegularExpression" // Swift and Obj-C regular expressions
	case posix = "POSIX Basic"      // Standard POSIX regular expressions
	case eposix = "POSIX Extended"  // Extended POSIX regular expressions (egrep)
	case pcre = "PCRE"              // Perl-Compatible Regular Expressions
	case ecmascript = "ECMAScript"  // ECMAScript (JavaScript-style regex)
	case java = "Java"              // Java's regex (java.util.regex)
	case python = "Python"          // Python's re module
	case ruby = "Ruby"              // Ruby's regex
	case perl = "Perl"              // Perl's native regex
	case re2 = "RE2"                // Google's RE2 regex engine
	case rust = "Rust"              // Rust's regex crate
	case go = "Go"                  // Go's regexp package
	case pcre2 = "PCRE2"            // Updated PCRE version
	case IRegexp = "I-Regexp"       // RFC 9485

	var id: String { self.rawValue }
}

#Preview {
	SettingsView()
}
