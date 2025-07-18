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
let exitCode: Int32;

exitCode = switch programName {
	case "abnf-expression-test-input": abnf_expression_test_input(arguments: arguments);
	case "abnf-list-rules": abnf_list_rules(arguments: arguments);
	case "abnf-to-regex": abnf_to_regex(arguments: arguments);
	case "abnf-to-regex-tests": abnf_to_regex_tests(arguments: arguments);
	case "abnf-equivalent-inputs": abnf_equivalent_inputs(arguments: arguments);
	case "catalog-list": catalog_list(arguments: arguments);
	default: defaultExitCode();
}

func defaultExitCode() -> Int32 {
	print("Usage: \(arguments[0]) <commands> [commands options...]");
	print("Tests an input against a grammar description");
	print("");
	abnf_expression_test_input_help(arguments: arguments);
	abnf_list_rules_help(arguments: arguments);
	abnf_to_regex_help(arguments: arguments);
	abnf_equivalent_inputs_help(arguments: arguments);
	catalog_list_help(arguments: arguments);
	return 1;
}

exit(exitCode)
