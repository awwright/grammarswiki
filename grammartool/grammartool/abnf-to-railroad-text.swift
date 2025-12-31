import FSM;
import Foundation;
private typealias Symbol = UInt32;
private typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<Symbol>>;

func abnf_to_railroad_text_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-railroad-text")) <filepath> <expression>");
	print("\tReads <filepath> and converts <rulename> to a text art railroad diagram");
}

func abnf_to_railroad_text_args(arguments: Array<String>) -> Int32 {
	// TODO: Add an argument to limit the width of the diagram by wrapping
	guard arguments.count == 4 else {
		print(arguments.count);
		abnf_to_railroad_text_help(arguments: arguments);
		return 1;
	}
	let imported: Data? = getInput(filename: arguments[2]);
	guard let imported else { return 1 }
	// builtins will be copied to the output
	let dereferencedRulelist: ABNFRulelist<Symbol>
	do {
		let importedRulelist = try ABNFRulelist<Symbol>.parse(imported);
		func dereference(filename: String) throws -> ABNFRulelist<Symbol> {
			let filePath = FileManager.default.currentDirectoryPath + "/catalog/" + filename
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
			return try ABNFRulelist<Symbol>.parse(content.utf8)
		}
		dereferencedRulelist = try dereferenceABNFRulelist(importedRulelist, dereference: dereference).rules;
	} catch {
		print("Could not parse input")
		print(error)
		return 2;
	}
	let rule = dereferencedRulelist.dictionary[arguments[3]];
	guard let rule else {
		print(stderr, "Error: No such rule: \(arguments[3])");
		exit(1);
	}
	let rr: RailroadTextNode = rule.toRailroad()
	for line in rr.lines {
		print(line)
	}
	return 0
}
