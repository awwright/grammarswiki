import FSM;

func abnf_equivalent_inputs_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-equivalent-inputs")) <expression> <input>");
	print("\tPrints all the strings that are equivalent to <input> under the ABNF expression <expression>, separated by a newline.");
}

func abnf_equivalent_inputs(arguments: Array<String>){
	guard arguments.count == 4 else {
		abnf_equivalent_inputs_help(arguments: arguments);
		print(arguments.count);
		return;
	}
	let abnfExpression = arguments[2];
	let input = arguments[3];
	let abnfTree: ABNFAlternation<UInt32>;
	do { abnfTree = try ABNFAlternation<UInt32>.parse(abnfExpression.utf8); }
	catch {
		print("Could not parse ABNF");
		print(error.localizedDescription);
		return;
	}
	let fsm: DFA<Array<UInt32>> = try! abnfTree.toPattern(rules: ABNFBuiltins<DFA<Array<UInt32>>>.dictionary);

	let equivalent = fsm.equivalentInputs(input: input.flatMap{ $0.unicodeScalars.map(\.value) });
	guard let equivalent else {
		print("Input is non-live (input rejects, and no additional input will transition to an accepting state)");
		return;
	}
	print(equivalent.toViz())
	for item in equivalent {
		print(item)
	}
}
