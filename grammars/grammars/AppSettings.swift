import SwiftUI

// Preferences view
struct SettingsView: View {
	@AppStorage("showAlphabet") private var showAlphabet: Bool = true
	@AppStorage("showStateCount") private var showStateCount: Bool = true
	@AppStorage("showRegex") private var showRegex: Bool = true
	@AppStorage("showExport") private var showExport: Bool = true
	@AppStorage("showInstances") private var showInstances: Bool = true
	@AppStorage("showTestInput") private var showTestInput: Bool = true
	@AppStorage("regexDialect") private var regexDialect: String = RegexDialect.swift.rawValue
	@AppStorage("graphvizEnabled") private var graphvizEnabled: Bool = false
	@AppStorage("graphvizDot") private var graphvizDot: String = ""
	@AppStorage("ragelEnabled") private var ragelEnabled: Bool = false
	@AppStorage("ragelPath") private var ragelPath: String = ""
	@AppStorage("wiresharkEnabled") private var wiresharkEnabled: Bool = false
	@AppStorage("wiresharkExts") private var wiresharkExts: String = ""

	var body: some View {
		TabView {
			Tab("Display", systemImage: "eye") {
				Form {
					Toggle("Show Alphabet", isOn: $showAlphabet)
					Toggle("Show Language Info", isOn: $showStateCount)
					Toggle("Show Regex", isOn: $showRegex)
					Toggle("Show FSM", isOn: $showExport)
					Toggle("Show Instances", isOn: $showInstances)
					Toggle("Show Input", isOn: $showTestInput)
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
						TextField("'dot' executable path", text: $graphvizDot)
					}
					Section("Ragel") {
						Toggle("Ragel Compiler", isOn: $ragelEnabled)
						TextField("'ragel' executable path", text: $ragelPath)
					}
					Section("Wireshark") {
						Toggle("Wireshark Extensions", isOn: $wiresharkEnabled)
						TextField("Extensions directory path", text: $wiresharkExts)
					}
				}
			}
			Tab("Reset", systemImage: "arrow.counterclockwise") {
				Form {
					Section {
						ForEach(Self.userPaths, id:\.self) { filepath in
							LabeledContent("Preferences path") {
								Button {
									NSWorkspace.shared.selectFile(filepath.path, inFileViewerRootedAtPath: "")
								} label: {
									Text(filepath.path)
									Image(systemName: "magnifyingglass.circle.fill")
								}
								.buttonStyle(.plain)
								.foregroundStyle(.secondary)
							}
						}
					}
					// TODO: Operations to move user preferences to trash
					//Section {
					//	Button("Reset Settings", role: .destructive) {}
					//	Button("Reset User Catalog", role: .destructive) {}
					//	Button("Reset Regex Presets", role: .destructive) {}
					//} footer: {
					//	Text("The selected preferences and data are moved to the trash")
					//}
					//Section {
					//	Button("Factory Reset", role: .destructive) {}
					//} footer: {
					//	Text("Resets all of the above")
					//}
				}
			}
		}
		.frame(width: 450, alignment: .leading)
		.formStyle(.grouped)
		.padding()
	}

	static var userPaths: Array<URL> {
		guard let bundleID = Bundle.main.bundleIdentifier else { return [] }
		let fm = FileManager.default;
		let possiblePaths: Array<URL> = [
			// Non-sandboxed
			"~/Library/Preferences/\(bundleID).plist",
			// Sandboxed
			"~/Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist"
		].compactMap {
			let path = NSString(string: $0).expandingTildeInPath;
			guard fm.fileExists(atPath: path) else { return nil; }
			return URL(fileURLWithPath: path);
		}
		return possiblePaths;
	}
}

// Enum to represent regex dialects
// TODO: Remove this, read available regex dialects from AppModel
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
