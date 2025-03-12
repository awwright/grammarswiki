import Foundation;
import FSM;

func abnf_expression_test_input_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-expression-test-input")) <expression> <input>");
	print("\tTests the given input against the given ABNF expression");
}

func abnf_expression_test_input(arguments: Array<String>){
	guard arguments.count != 4  else {
		abnf_expression_test_input_help(arguments: arguments);
		return;
	}
	let abnfExpression = arguments[2];
	let input = arguments[3];
	let abnfTree = ABNFAlternation<UInt8>.parse(abnfExpression.utf8);
	guard let abnfTree else {
		print("Could not parse ABNF");
		return;
	}
	let fsm = try? abnfTree.toPattern(as: DFA<Array<UInt8>>.self, rules: ABNFBuiltins<DFA<Array<UInt8>>>.dictionary);
	guard let fsm else {
		print("Internal error (could not convert ABNF to DFA)");
		return;
	}
	if(fsm.contains(input.utf8)){
		print("Accepted")
	}else{
		print("Rejected")
	}
}
