import Foundation;
import FSM;

func abnf_expression_test_input_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-expression-test-input")) <expression> <input>");
	print("\tTests the given input against the given ABNF expression");
}

func abnf_expression_test_input(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4  else {
		abnf_expression_test_input_help(arguments: arguments);
		return 1;
	}
	let abnfExpression = arguments[2];
	let input = arguments[3];

	let builtins = ABNFBuiltins<DFA<UInt32>>.dictionary;
	let abnfTree: ABNFAlternation<UInt32>
	do { abnfTree = try ABNFAlternation<UInt32>.parse(abnfExpression.utf8); }
	catch {
		print("Could not parse ABNF");
		return 2;
	}

	let fsm: DFA<UInt32>;
	do { fsm = try abnfTree.toPattern(rules: builtins); }
	catch {
		print("Could not convert ABNF to DFA");
		return 2;
	}

	if(fsm.contains(input.unicodeScalars.map{ $0.value })){
		print("Accepted")
	}else{
		print("Rejected")
	}
	return 0
}
