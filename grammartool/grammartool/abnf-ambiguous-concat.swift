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
	let abnf_lhs = arguments[2];
	let abnf_rhs = arguments[3];
	abnf_ambiguous_concat_run(response: &stdout, lhs: abnf_lhs, rhs: abnf_rhs);
	return stdout.exitCode;
}

func abnf_ambiguous_concat_run(response r: inout some ResponseProtocol, lhs: String, rhs: String) {
	// Parse the first two arguments as ABNF
	// Don't forget to quote the ABNF in your shell so it appears as a single argument.
	let abnfTree1: ABNFAlternation<UInt32>;
	do { abnfTree1 = try ABNFAlternation<UInt32>.parse(lhs.utf8); }
	catch {
		r.writeLn("Could not parse ABNF");
		r.writeLn(error.localizedDescription);
		r.status = .error;
		return
	}
	let fsm1: SymbolDFA<UInt32> = try! abnfTree1.toPattern(rules: ABNFBuiltins<SymbolDFA<UInt32>>.dictionary);

	let abnfTree2: ABNFAlternation<UInt32>;
	do { abnfTree2 = try ABNFAlternation<UInt32>.parse(rhs.utf8); }
	catch {
		r.writeLn("Could not parse ABNF");
		r.writeLn(error.localizedDescription);
		r.status = .error;
		return
	}
	let fsm2: SymbolDFA<UInt32> = try! abnfTree2.toPattern(rules: ABNFBuiltins<SymbolDFA<UInt32>>.dictionary);

	let nonprefix1 = fsm1.derive(fsm1).minimized();
	let nonprefix2 = fsm2.dock(fsm2).minimized();
	let overlap = nonprefix1.intersection(nonprefix2).minimized().normalized()
	let prefix1 = fsm1.dock(overlap);
	let prefix2 = fsm2.derive(overlap);
	// Verify that the language wasn't changed
	assert(SymbolDFA.concatenate([prefix1, overlap, prefix2]) == SymbolDFA.concatenate([fsm1, fsm2]))

	r.status = .ok;
	// TODO: Show a tuple of (prefix, overlap, sufix)
	// If overlap == epsilon, then the concatenation is unambiguous.
	// Otherwise, overlap can occur in any (non-epsilon) subsequence of the input
	r.writeLn(prefix1.minimized().normalized().toViz())
	r.writeLn(overlap.toViz())
	r.writeLn(prefix2.minimized().normalized().toViz())
	r.end()
}
