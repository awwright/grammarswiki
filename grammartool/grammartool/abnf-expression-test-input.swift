import Foundation;
import FSM;

func abnf_expression_test_input_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-expression-test-input")) <expression> <input>");
	print("\tTests the given input against the given ABNF expression");
}

func abnf_expression_test_input_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4  else {
		abnf_expression_test_input_help(arguments: arguments);
		return 1;
	}
	let abnfExpression = arguments[2];
	let input = arguments[3];
	abnf_expression_test_input_run(res: &stdout, abnfExpression: abnfExpression, input: input);
	return stdout.exitCode;
}

func abnf_expression_test_input_run(res: inout some ResponseProtocol, abnfExpression: String, input: String) -> Int32 {
	let builtins = ABNFBuiltins<DFA<UInt32>>.dictionary;
	let abnfTree: ABNFAlternation<UInt32>
	do { abnfTree = try ABNFAlternation<UInt32>.parse(abnfExpression.utf8); }
	catch {
		res.writeLn("Could not parse ABNF");
		return 2;
	}

	let fsm: DFA<UInt32>;
	do { fsm = try abnfTree.toPattern(rules: builtins); }
	catch {
		res.writeLn("Could not convert ABNF to DFA");
		return 2;
	}

	if(fsm.contains(input.unicodeScalars.map{ $0.value })){
		res.writeLn("Accepted")
	}else{
		res.writeLn("Rejected")
	}
	return 0
}
