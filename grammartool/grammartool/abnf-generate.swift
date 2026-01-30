import FSM;
import Foundation;
private typealias Symbol = UInt32;
private typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<Symbol>>;

func abnf_generate_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-generate")) [<filepath>] <expression>");
	print("\tGenerate instances of <expression> separated by a newline (importing rules from <filepath>)");
}

func abnf_generate_args(arguments: Array<String>) -> Int32 {
	guard arguments.count >= 3 && arguments.count <= 4 else {
		print(arguments.count);
		abnf_generate_help(arguments: arguments);
		return 1;
	}

	let filepath: String?;
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
	let fsm: DFA;
	do {
		let catalog = Catalog(root: FileManager.default.currentDirectoryPath);
		let (expression, dereferencedRulelist, _): (expression: ABNFAlternation<Symbol>, rules: ABNFRulelist<Symbol>, backward: Dictionary<String, (filename: String, ruleid: String)>)
			= try catalog.loadExpression(path: filepath ?? "", expression: expressionStr);
		importedDict = try dereferencedRulelist.toClosedRangePattern(as: DFA.self, rules: builtins).mapValues { $0.minimized().normalized() }
		fsm = try expression.toPattern(rules: importedDict)
	} catch {
		print("Could not parse input")
		print(error)
		return 2;
	}

	var iterator: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>.Iterator = fsm.makeIterator()
	// TODO: configurable separator
	while let next = iterator.next() {
		print(String(decoding: next, as: Unicode.UTF32.self))
	}
	return 0;
}
