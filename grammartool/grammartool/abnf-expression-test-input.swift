import Foundation;
import FSM;

func abnf_expression_test_input_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-expression-test-input")) <expression> <input>");
	print("\tTests the given input against the given ABNF expression");
}

func abnf_expression_test_input(arguments: Array<String>){
	guard arguments.count == 4  else {
		abnf_expression_test_input_help(arguments: arguments);
		return;
	}
	let abnfExpression = arguments[2];
	let input = arguments[3];

	let builtins = ABNFBuiltins<DFA<Array<UInt32>>>.dictionary;
	let abnfTree: ABNFAlternation<UInt32>
	do { abnfTree = try ABNFAlternation<UInt32>.parse(abnfExpression.utf8); }
	catch {
		print("Could not parse ABNF");
		return;
	}

	let fsm: DFA<Array<UInt32>>;
	do { fsm = try abnfTree.toPattern(rules: builtins); }
	catch {
		print("Could not convert ABNF to DFA");
		return;
	}

	if(fsm.contains(input.unicodeScalars.map{ $0.value })){
		print("Accepted")
	}else{
		print("Rejected")
	}
}
