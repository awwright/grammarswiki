import FSM;
import Foundation

func abnf_to_regex_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-regex")) [<filepath>] <expression>");
	print("\tConverts <expression> to a regular expression, optionally importing rules from <filepath>");
}

func abnf_to_regex(arguments: Array<String>) -> Int32 {
	guard arguments.count >= 3 && arguments.count <= 4 else {
		print(arguments.count);
		abnf_to_regex_help(arguments: arguments);
		return 1;
	}

	let imported: Data?;
	let expressionIndex: Array.Index
	if(arguments.count == 4){
		imported = getInput(filename: arguments[2]);
		expressionIndex = 3;
	} else {
		imported = nil
		expressionIndex = 2;
	}

	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let builtins = ABNFBuiltins<DFA<UInt8>>.dictionary;
	let importedRulelist = try! ABNFRulelist<UInt8>.parse(imported!);

	// builtins will be copied to the output
	let importedDict = try! importedRulelist.toPattern(as: DFA<UInt8>.self, rules: builtins).mapValues { $0.minimized() }
	let expression: ABNFAlternation<UInt8>;
	do { expression = try ABNFAlternation<UInt8>.parse(arguments[expressionIndex].utf8); }
	catch {
		print("Could not parse input")
		return 2;
	}

	let fsm: DFA<UInt8> = try! expression.toPattern(rules: importedDict)

	let regex: SimpleRegex<UInt8> = fsm.toPattern()
	print(regex.description)
	return 0
}
