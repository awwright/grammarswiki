import FSM;
import Foundation; // Import `FileManager`

func abnf_dereference_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-list-rules")) <filepath> [<rulename>]");
	print("\tParses <filepath> and imports in any rules that are not defined in the file. If <rulename> is specified, only that rule and its dependencies will be loaded.");
}

func abnf_dereference_args(arguments: Array<String>) -> Int32 {
	// Resolve arguments[2] against the current working directory
	let filename = arguments[2];
	let filepath = FileManager.default.currentDirectoryPath + "/" + filename;
	// Find the ditectory of filepath
	let directory = URL(fileURLWithPath: filepath).deletingLastPathComponent().path;
	// Assume the catalog root is the directory where filepath is found
	// TODO: resolve all references relative to the file location
	let catalog = Catalog(root: directory);
	let rulenames: Array<String>? = arguments.count > 3 ? [arguments[3]] : nil;
	print(bold("filepath"), filepath);
	print(bold("rulename"), rulenames?.joined(separator: ", ") ?? "*");
	print("");

	let rules: ABNFRulelist<UInt32>;
	do {
		let (rules, mapping): (ABNFRulelist<UInt32>, [String: (String, String)]) = try catalog.load(path: filename, rulenames: rulenames);
		print(bold("rules"));
		print(rules);

		print(bold("mapping"));
		for (k, v) in mapping {
			print("\(k) -> \(v.0) -> \(v.1)")
		}
	} catch {
		print("\(bold("ERROR")): \(error)")
		return 1;
	}

	return 0;
}
