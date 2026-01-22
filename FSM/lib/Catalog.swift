import Foundation; // import `String(contentsOfFile:)`

public struct Catalog {
	public let root: String;

	public init(root: String) {
		self.root = root
	}

	// This must be able to:
	// - Load all rules in a file, and their dependencies
	// - Load select rules from a file, and their dependencies
	// - Load an arbritrary ABNFRule or ABNFRulelist, and their dependencies
	// - Rewrite rule labels when two files use the same label (be able to generate a coherent, combined ABNF document)
	// - Return an ABNFRulelist of the collected rules (original plus dependencies)
	// - Return a mapping of each collected rules back to its original file and original rule id/label
	// - Rule id and label should include just enough file path to know which absolute file we're talking about (this probably means: filenames within an ABNF fiile should be resolved relative to that file, but all file paths should be displayed in the output relative to the catalog root)
	/// Load the rules from an ABNF file, and all referenced rules.
	/// - Parameters:
	///   - path: File path to load, underneath ``root``
	///   - rulename: If non-nil, only load the named rule from the file and its dependencies
	/// - Returns: <#description#>
	public func load<T>(path: String, rulename: String? = nil) throws
		-> (rules: ABNFRulelist<T>, backward: Dictionary<String, (filename: String, ruleid: String)>)
	{
		// The list of files
		var importedFiles: Dictionary<String, ABNFRulelist<T>> = [:];

		func dereference(filename: String) throws -> ABNFRulelist<T> {
			let filePath = root + "/" + filename;
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
				.replacingOccurrences(of: "\n", with: "\r\n")
				.replacingOccurrences(of: "\r\r", with: "\r");
			return try ABNFRulelist<T>.parse(content.utf8);
		}

		// First let's get the root file
		let root_parsed = try dereference(filename: path);
		importedFiles[path] = root_parsed

		// The list of rules to be included from the root file (ignore others
		let root_rulenames: Array<String>;
		if let rulename {
			// If one rulename was specfied, find the dependencies for only that rule
			root_rulenames = [rulename.lowercased()].map { "{File: \(path) Rule: \($0)}"; };
		} else {
			// Otherwise assume we want all the rules from the file
			root_rulenames = root_parsed.ruleNames.map { "{File: \(path) Rule: \($0.lowercased())}"; }
		}

		// Replace all of the rules and imports in the file with an unambiguous identifier
		func collectImports(source_filename: String, rulelist: ABNFRulelist<T>)
			-> (ABNFRulelist<T>, Dictionary<String, (filename: String, ruleid: String)>)
		{
			var backwards: Dictionary<String, (filename: String, ruleid: String)> = [:]
			let mangled: ABNFRulelist<T> =
			rulelist
				.mapRulenames {
					let mangled = "{File: \(source_filename) Rule: \($0)}";
					return ABNFRulename<T>(id: mangled, label: mangled); // rulename.label
				}
				.mapElements {
					switch $0 {
					case .proseVal(let proseVal):
						let parts = proseVal.remark.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: false)
						guard parts.count >= 3 else { return $0 }
						guard parts[0] == "import" else { return $0 }
						let target_filename = String(parts[1]);
						let target_rulename = String(parts[2]);
						let mangled = "{File: \(target_filename) Rule: \(target_rulename)}";
						backwards[mangled] = (target_filename, target_rulename);
						return ABNFRulename(id: mangled, label: mangled).element; // target_rulename
					default:
						return $0;
					}
				}
			return (mangled, backwards);
		}

		let (root_dereferenced, root_references_backwards) = collectImports(source_filename: path, rulelist: root_parsed);
		var rulelist_all = root_dereferenced.rules.filter { root_rulenames.contains($0.rulename.id) }

		// Keep track of the source filenames and rule id in those files
		// The rule names to start will be the original names
		var references_backwards = root_references_backwards;

		return (rules: ABNFRulelist<T>(rules: rulelist_all), backward: references_backwards)
	}
}
