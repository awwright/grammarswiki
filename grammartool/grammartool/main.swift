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

typealias Char = UInt32;

//print(getInput()/*!*/);
let rulelist = ABNFRulelist<Char>.parse(getInput()!)!;

let parsedRules: Dictionary<String, DFA<Array<Char>>> = rulelist.toPattern(as: DFA<Array<Char>>.self)
print(parsedRules.keys);
//print(rulelist.description);

guard arguments.count >= 3 else {
	exit(0);
}

let rulename = arguments[2]
guard let fsm = parsedRules[rulename] else {
	print("Could not compile \(rulename)");
	exit(1);
}
print(fsm.toViz());
var pattern: SimpleRegex<Char> = fsm.toPattern()
print(pattern.description)
print(pattern.toPattern(as: ABNFAlternation<Char>.self).description)
