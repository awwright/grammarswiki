import FSM;
import Foundation;
private typealias Symbol = UInt32;
private typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<Symbol>>;

func abnf_to_regex_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-regex")) [<filepath>] <expression>");
	print("\tConverts <expression> to a regular expression, optionally importing rules from <filepath>");
}

func abnf_to_regex_args(arguments: Array<String>) -> Int32 {
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
	let builtins = ABNFBuiltins<DFA>.dictionary;

	// builtins will be copied to the output
	let importedDict: [String : DFA];
	let expression: ABNFAlternation<Symbol>;
	let fsm: DFA;
	do {
		let importedRulelist = try ABNFRulelist<Symbol>.parse(imported!);
		let dereferencedRulelist = try dereferenceABNFRulelist(importedRulelist, {
			filename in
			let filePath = FileManager.default.currentDirectoryPath + "/catalog/" + filename
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
			return try ABNFRulelist<Symbol>.parse(content.utf8)
		});
		importedDict = try dereferencedRulelist.toPattern(as: DFA.self, rules: builtins).mapValues { $0.minimized() }
		expression = try ABNFAlternation<Symbol>.parse(arguments[expressionIndex].utf8);
		fsm = try expression.toPattern(rules: importedDict)
	} catch {
		print("Could not parse input")
		print(error)
		return 2;
	}
	let regex: REPattern<Symbol> = fsm.toPattern()
	print(REDialectBuiltins.swift.encode(regex))
	return 0
}
