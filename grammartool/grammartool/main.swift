import Foundation;
import FSM;

let arguments = CommandLine.arguments

func getInput(filename: String?) -> Data? {
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

func bold(_ text: String) -> String {
	return "\u{1B}[1m\(text)\u{1B}[0m"
}

let programName = arguments.count >= 2 ? arguments[1] : nil;

switch programName {
	case "abnf-expression-test-input": abnf_expression_test_input(arguments: arguments);
	case "abnf-to-regex": abnf_to_regex(arguments: arguments);
	case "abnf-equivalent-inputs": abnf_equivalent_inputs(arguments: arguments);

	default:
	print("Usage: \(arguments[0]) <commands> [commands options...]");
	print("Tests an input against a grammar description");
	print("");
	abnf_expression_test_input_help(arguments: arguments);
	abnf_to_regex_help(arguments: arguments);
	abnf_equivalent_inputs_help(arguments: arguments);
}
