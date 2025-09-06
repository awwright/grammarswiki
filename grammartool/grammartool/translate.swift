import FSM;
import Foundation;
private typealias Symbol = UInt32;
private typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<Symbol>>;

func translate_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("translate")) <source> <target>");
	print("\tConverts stdin of type <source> to an equivalent string of type <target>. If source = target, this normalizes the string.");
}

func translate_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4 else {
		print(arguments.count);
		translate_help(arguments: arguments);
		return 1;
	}

	// TODO: This only works over stdin for now, maybe later pass a filename
	let imported: Data? = FileHandle.standardInput.availableData
	guard let imported else {
		fatalError("Failed to read input")
	}

	// Load the input as ASCII, I guess
	// TODO: In the future, we will need to convert between UTF-8, UTF-16, and UTF-32
	let bytes = Array<UInt8>(imported);
	let pattern: SymbolDFA<UInt8> = [ bytes ];
	// TODO: Apply homomorphism here, that converts <from> -> <to>
	let fsm1 = pattern
	// The first string that the transformed FSM outputs is the normal form
	let string = fsm1.makeIterator().next()
	guard let string else {
		fatalError("No equivalent form in specified format")
	}
	// Print the raw bytes from `string` to stdout
	FileHandle.standardOutput.write(Data(string))
	return 0
}
