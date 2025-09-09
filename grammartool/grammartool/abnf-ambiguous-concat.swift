import FSM;

func abnf_ambiguous_concat_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-ambiguous-concat")) <expression1> <expression2>");
	print("\tDetermines if there are multiple ways to split a string from <expression1> and <expression2> back into their parts.");
}

func abnf_ambiguous_concat_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4 else {
		abnf_ambiguous_concat_help(arguments: arguments);
		print(arguments.count);
		return 1;
	}
	let abnfExpression = arguments[2];
	let input = arguments[3];
	abnf_ambiguous_concat_run(response: &stdout, abnfExpression: abnfExpression, input: input);
	return stdout.exitCode;
}

func abnf_ambiguous_concat_run(response r: inout some ResponseProtocol, abnfExpression: String, input: String) {
	// Parse the first two arguments as ABNF
	// Don't forget to quote the ABNF in your shell so it appears as a single argument.
	let abnfTree1: ABNFAlternation<UInt32>;
	do { abnfTree1 = try ABNFAlternation<UInt32>.parse(abnfExpression.utf8); }
	catch {
		r.writeLn("Could not parse ABNF");
		r.writeLn(error.localizedDescription);
		r.status = .error;
		return
	}
	let fsm1: SymbolDFA<UInt32> = try! abnfTree1.toPattern(rules: ABNFBuiltins<SymbolDFA<UInt32>>.dictionary);

	let abnfTree2: ABNFAlternation<UInt32>;
	do { abnfTree2 = try ABNFAlternation<UInt32>.parse(abnfExpression.utf8); }
	catch {
		r.writeLn("Could not parse ABNF");
		r.writeLn(error.localizedDescription);
		r.status = .error;
		return
	}
	let fsm2: SymbolDFA<UInt32> = try! abnfTree2.toPattern(rules: ABNFBuiltins<SymbolDFA<UInt32>>.dictionary);

	// The theory behind this is that for all strings in A++B,
	// there is some end state in A that matches a start state in B.
	// However if the string is ambiguous, there
	let repeat1 = SymbolDFA<UInt32>.union(fsm1.finals.sorted().map {
		fsm1.subpaths(source: $0, target: fsm1.finals);
	});
	let repeat2 = fsm2.subpaths(source: fsm2.initial, target: [fsm2.initial]).intersection(fsm2);
	let overlap = repeat1.minimized().subtracting(SymbolDFA.epsilon).minimized();

	r.status = .ok;
	// TODO: Show a tuple of (prefix, overlap, sufix)
	r.writeLn(overlap.toViz())
	r.end()
}
