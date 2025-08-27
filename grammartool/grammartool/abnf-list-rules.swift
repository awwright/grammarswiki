import FSM;
import Foundation

func abnf_list_rules_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-list-rules")) [<filepath>]");
	print("\tParses <filepath> as ABNF and lists information");
}

func abnf_list_rules_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3 else {
		abnf_list_rules_help(arguments: arguments);
		return 1;
	}

	let imported: Data? = getInput(filename: arguments[2]);
	guard let imported else {
		print("No data found at \(arguments[2])");
		return 1;
	}

	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let builtins = ABNFBuiltins<DFA<UInt8>>.dictionary;
	let importedRulelist = try! ABNFRulelist<UInt8>.parse(imported);

	for rulename in importedRulelist.ruleNames {
		let deps = importedRulelist.dependencies(rulename: rulename)
		print("\(bold(rulename)): \(deps)");
	}

	return 0
}
