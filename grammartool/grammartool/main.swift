import Foundation;
import FSM;

let arguments = CommandLine.arguments
//guard arguments.count > 1 else {
//	print("Usage: \(arguments[0]) <filename>")
//	print("Also accepts stdin input after file processing (Ctrl+D or Ctrl+Z to end)")
//	exit(1)
//}
print(arguments);

func getInput() -> Data? {
	// Check command-line arguments
	let filename: String?

	if arguments.count > 1 {
		filename = arguments[1]
	} else {
		filename = nil
	}

	if let filename {
		// Read raw bytes from file
		do {
			let fileURL = URL(fileURLWithPath: filename)
			return try Data(contentsOf: fileURL)
		} catch {
			print("Error reading file '\(filename)': \(error)")
			return nil
		}
	} else {
		// Read raw bytes from stdin
		let data = FileHandle.standardInput.availableData
		return data.isEmpty ? nil : data
	}
}

typealias Char = UInt8;

//print(getInput()/*!*/);
let rulelist = ABNFRulelist<Char>.parse(getInput()!)!;
let defaultRuleName = rulelist.rules.first?.rulename.label
print(defaultRuleName)
print(rulelist.description)

let parsedRules: Dictionary<String, DFA<Array<Char>>> = rulelist.toPattern(as: DFA<Array<Char>>.self)
print(parsedRules.keys);

guard arguments.count >= 3 else {
	exit(0);
}

let expression = arguments[2]
guard let alternation = ABNFAlternation<Char>.parse(expression.utf8) else {
	print("Could not compile \(expression)");
	exit(1);
}

let fsm = alternation.toPattern(as: DFA<Array<Char>>.self, rules: parsedRules).minimized()
print(fsm.toViz());
var pattern: SimpleRegex<Char> = fsm.toPattern()
print(pattern.description)
print(pattern.toPattern(as: ABNFAlternation<Char>.self).description)
