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
		let (root_rulelist, root_backwards) = try dereference(source_filename: path)
		// Keep a list of imported files
		var all_dereferenced = [path: (root_rulelist, root_backwards)];
		// Keep track of the order the files were loaded in
		var all_path_priority = [path];
		var all_mangled: Dictionary<String, ABNFRulelist<T>> = [path: root_rulelist];
		var all_backwards = root_backwards;

		// Make the list of rules to be included in the resulting output
		let root_rulenames: Array<String>;
		if let rulename {
			// If one rulename was specfied, find the dependencies for only that rule
			root_rulenames = [rulename.lowercased()].map { "{File: \(path) Rule: \($0)}"; };
		} else {
			// Otherwise assume we want all the rules from the file
			root_rulenames = root_backwards.keys.sorted();
		}

		func dereference(source_filename: String) throws
			-> (ABNFRulelist<T>, Dictionary<String, (filename: String, ruleid: String)>)
		{
			let filePath = root + "/" + source_filename;
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
				.replacingOccurrences(of: "\n", with: "\r\n")
				.replacingOccurrences(of: "\r\r", with: "\r");
			let rulelist = try ABNFRulelist<T>.parse(content.utf8);

			var backwards: Dictionary<String, (filename: String, ruleid: String)> = [:]
			let mangled: ABNFRulelist<T> =
				rulelist
				.mapRulenames {
					let mangled = "{File: \(source_filename) Rule: \($0.label.lowercased())}";
					backwards[mangled] = (source_filename, $0.label.lowercased());
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
				};
			return (mangled, backwards);
		}

		// Load only the desired rules
		var required_rulelist = root_rulelist.rules.filter { root_rulenames.contains($0.rulename.id) };
		// Keep track of rules that have been added to the list
		var required_rulelist_set = Set(required_rulelist.map { $0.rulename.id });

		// Iterate through the rulelist, appending required rules as needed
		var i = 0;
		while i < required_rulelist.count {
			let r = required_rulelist[i];
			// Get a list of the rules that this rule refers to, and add those to the list as necessary
			for ref in r.referencedRules.sorted() {
				// Skip rules we have already loaded
				guard !required_rulelist_set.contains(ref) else { continue }

				// If the rule is from an external file, make sure it's loaded
				guard let (required_filename, required_rulename) = root_backwards[ref]
				else { continue; }

				if all_dereferenced[required_filename] == nil {
					let (ref_rulelist, ref_backwards) = try dereference(source_filename: required_filename);
					all_dereferenced[required_filename] = (ref_rulelist, ref_backwards);
					all_mangled[path] = ref_rulelist;
					for (k, v) in ref_backwards { all_backwards[k] = v; }
				}

				let (rulelist, _) = all_dereferenced[required_filename]!;

				// Determine which file we find the reference in
				for new_r in rulelist.rules.filter({ $0.rulename.id == ref }) {
					required_rulelist.append(new_r);
					required_rulelist_set.insert(new_r.rulename.id);
				}

			}
			i += 1;
		}

		// Now the rulenames in required_rulelist and all_backwards are unique... but also illegal.
		// Map them to their original rulenames, when they're unambiguous.
		let rules = ABNFRulelist<T>(rules: required_rulelist).mapRulenames { ABNFRulename(label: all_backwards[$0.label]!.ruleid) };
		let backward = all_backwards.filter { required_rulelist_set.contains($0.0) };

		return (rules: rules, backward: backward)
	}
}
