import FSM;
import Foundation

func abnf_to_regex_tests_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-regex-test")) [<filepath>] <expression>");
	print("\tConverts <expression> to a regular expression, optionally importing rules from <filepath>");
}

func abnf_to_regex_tests_args(arguments: Array<String>) -> Int32 {
	guard arguments.count >= 3 && arguments.count <= 4 else {
		print(arguments.count);
		abnf_to_regex_tests_help(arguments: arguments);
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
	let builtins = ABNFBuiltins<SymbolClassDFA<ClosedRangeAlphabet<UInt8>>>.dictionary;
	let importedRulelist = try! ABNFRulelist<UInt8>.parse(imported!);

	// builtins will be copied to the output
	let importedDict = try! importedRulelist.toPattern(as: SymbolClassDFA<ClosedRangeAlphabet<UInt8>>.self, rules: builtins).mapValues { $0.minimized() }
	let expression: ABNFAlternation<UInt8>;
	do { expression = try ABNFAlternation<UInt8>.parse(arguments[expressionIndex].utf8); }
	catch {
		print("Could not parse input")
		return 2;
	}

	let fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt8>> = try! expression.toPattern(rules: importedDict)

	// Generate the regular expression
	let regex: REPattern<UInt8> = fsm.toPattern()
	let regexString = regex.description;
	let regexStringQuoted = bashSingleQuote(regexString)

	// Generate some instances
	var iterator: DFA<UInt8>.Iterator = fsm.makeIterator();
	for i in 0..<1000 {
		let instance: Array<UInt8>? = iterator.next();
		guard let instance else { continue }
		let instanceString: String = String(decoding: instance, as: Unicode.UTF8.self);
		print("echo \(bashSingleQuote(instanceString)) | egrep \(regexStringQuoted); echo $?")
		if i == 999 {
			print ("# Early stop");
			break;
		}
	}
	return 0
}

func bashSingleQuote(_ input: String) -> String {
	"'\(input.replacingOccurrences(of: "'", with: "'\\''"))'"
}
