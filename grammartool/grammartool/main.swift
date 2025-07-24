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

struct StdioResponse: ResponseProtocol {
	var status: ResponseStatus
	
	var contentType: String

	var exitCode: Int32 {
		switch status {
			case .ok: return 0
			default: return 1
		}
	}

	func write(_ part: Array<UInt8>) {
		print(part, terminator: "")
	}
	
	func writeLn(_ part: String) {
		print(part)
	}
	
	func end() {
		// No-op
	}
}

let programName = arguments.count >= 2 ? arguments[1] : nil;
let exitCode: Int32;
var stdout = StdioResponse(status: .error, contentType: "application/octet-stream");

// If this is a CGI environment, then pass this to the CGI handler
// See <cgi.swift> for a simple Apache configuration to call this
if arguments.count == 1 && ProcessInfo.processInfo.environment["REQUEST_URI"] != nil {
	exit(cgi(arguments: arguments));
}

exitCode = switch programName {
	case "abnf-expression-test-input": abnf_expression_test_input_args(arguments: arguments);
	case "abnf-list-rules": abnf_list_rules_args(arguments: arguments);
	case "abnf-to-regex": abnf_to_regex_args(arguments: arguments);
	case "abnf-to-regex-tests": abnf_to_regex_tests_args(arguments: arguments);
	case "abnf-equivalent-inputs": abnf_equivalent_inputs_args(arguments: arguments);
	case "catalog-list": catalog_list_args(arguments: arguments);
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
