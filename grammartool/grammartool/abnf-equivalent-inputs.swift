import FSM;

func abnf_equivalent_inputs_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-equivalent-inputs")) <expression> <input>");
	print("\tPrints all the strings that are equivalent to <input> under the ABNF expression <expression>, separated by a newline.");
}

func abnf_equivalent_inputs_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4 else {
		abnf_equivalent_inputs_help(arguments: arguments);
		print(arguments.count);
		return 1;
	}
	let abnfExpression = arguments[2];
	let input = arguments[3];
	abnf_equivalent_inputs_run(response: &stdout, abnfExpression: abnfExpression, input: input);
	return stdout.exitCode;
}

func abnf_equivalent_inputs_run(response r: inout some ResponseProtocol, abnfExpression: String, input: String) {
	let abnfTree: ABNFAlternation<UInt32>;
	do { abnfTree = try ABNFAlternation<UInt32>.parse(abnfExpression.utf8); }
	catch {
		r.writeLn("Could not parse ABNF");
		r.writeLn(error.localizedDescription);
		r.status = .error;
		return
	}
	let fsm: SymbolDFA<UInt32> = try! abnfTree.toPattern(rules: ABNFBuiltins<SymbolDFA<UInt32>>.dictionary);

	let equivalent = fsm.equivalentInputs(input: input.flatMap{ $0.unicodeScalars.map(\.value) });
	guard let equivalent else {
		r.writeLn("Input is non-live (input rejects, and no additional input will transition to an accepting state)");
		r.status = .error;
		return;
	}

	r.status = .ok;
	r.writeLn(equivalent.toViz())
	for item in equivalent {
		r.writeLn(String(describing: item))
	}
	r.end()
}
