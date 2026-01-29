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

	let filepath: String?
	let expressionStr: String;
	if(arguments.count == 4){
		filepath = arguments[2];
		expressionStr = arguments[3];
	} else {
		filepath = nil
		expressionStr = arguments[2];
	}

	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let builtins = ABNFBuiltins<DFA>.dictionary;

	// builtins will be copied to the output
	let importedDict: [String : DFA];
	let expression: ABNFAlternation<Symbol>;
	let fsm: DFA;
	do {
		let catalog = Catalog(root: FileManager.default.currentDirectoryPath);
		// First parse the provided expression, to see if it references any rule names
		let expression = try ABNFAlternation<Symbol>.parse(expressionStr.utf8);

		if let filepath {
			let (dereferencedRulelist, _): (rules: ABNFRulelist<UInt32>, backward: Dictionary<String, (filename: String, ruleid: String)>) = try catalog.load(path: filepath, rulenames: Array(expression.referencedRules))
			importedDict = try dereferencedRulelist.toClosedRangePattern(as: DFA.self, rules: builtins).mapValues { $0.minimized().normalized() }
		} else {
			importedDict = [:]
		}

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
