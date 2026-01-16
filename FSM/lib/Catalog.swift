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
	/// Load the rules from an ABNF file, and all referenced rules.
	/// - Parameters:
	///   - path: <#path description#>
	///   - rulename: <#rulename description#>
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
		let root_parsed = try dereference(filename: path);

		let root_rulenames: Array<String>;
		if let rulename {
			// If one rulename was specfied, find the dependencies for only that rule
			root_rulenames = [rulename];
		} else {
			// Otherwise assume we want all the rules from the file
			root_rulenames = root_parsed.ruleNames
		}
		print(root_rulenames);

		let (root_references, root_dereferenced, references_backwards) = collectImports(from: root_parsed);

		return try dereferenceABNFRulelist(root_parsed, dereference: dereference);
	}
}
