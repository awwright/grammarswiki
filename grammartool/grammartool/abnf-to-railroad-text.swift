import FSM;
import Foundation;
private typealias Symbol = UInt32;
private typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<Symbol>>;

func abnf_to_railroad_text_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-railroad-text")) [<filepath>] <expression>");
	print("\tReads <filepath> and converts <expression> to a text art railroad diagram");
}

func abnf_to_railroad_text_args(arguments: Array<String>) -> Int32 {
	// TODO: Add an argument to limit the width of the diagram by wrapping
	let filepath: String?
	let expressionStr: String;
	if arguments.count == 3 {
		filepath = nil;
		expressionStr = arguments[2];
	} else if arguments.count == 4 {
		filepath = arguments[2];
		expressionStr = arguments[3];
	} else {
		abnf_to_railroad_text_help(arguments: arguments);
		return 1;
	}

	let userExpression: ABNFAlternation<Symbol>
	let dereferencedRulelist: ABNFRulelist<Symbol>
	do {
		let catalog = Catalog(root: FileManager.default.currentDirectoryPath);
		let (_e, _r, _): (expression: ABNFAlternation<Symbol>, rules: ABNFRulelist<Symbol>, backward: Dictionary<String, (filename: String, ruleid: String)>)
			= try catalog.loadExpression(path: filepath, expression: expressionStr);
		userExpression = _e;
		dereferencedRulelist = _r;
	} catch {
		print("Could not parse input")
		print(error)
		return 2;
	}

	let rule: ABNFAlternation<Symbol>;
	if let singleRule = dereferencedRulelist.rules.first,	singleRule.rulename.id == expressionStr.lowercased() {
		// If expression matches a single rule, pull that rule directly
		rule = singleRule.alternation;
	} else {
		// Otherwise, generate a diagram of the expression, and expand rule references within it
		rule = userExpression;
	}

	let rr: RailroadTextNode = rule.toRailroad()
	for line in rr.lines {
		print(line)
	}
	return 0
}
