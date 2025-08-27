import FSM;
import Foundation

func abnf_list_rulenames_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-list-rulenames")) [<filepath>]");
	print("\tParses <filepath> as ABNF and lists names of rules defined in the file, newline-delimited");
}

func abnf_list_rulenames_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3 else {
		abnf_list_rulenames_help(arguments: arguments);
		return 1;
	}

	let imported: Data? = getInput(filename: arguments[2]);
	guard let imported else {
		print("No data found at \(arguments[2])");
		return 1;
	}

	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let importedRulelist = try! ABNFRulelist<UInt8>.parse(imported);

	for rulename in importedRulelist.ruleNames {
		print(rulename);
	}

	return 0
}
