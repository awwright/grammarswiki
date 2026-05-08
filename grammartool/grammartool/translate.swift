import FSM;
import Foundation;
private typealias Symbol = UInt32;

func translate_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("translate")) <source> <target>");
	print("\tConverts stdin of type <source> to an equivalent string of type <target>. If source = target, this normalizes the string.");
}

func translate_args(arguments: Array<String>) -> Int32 {
	let graph = HomomorphismGraph<UInt32>.builtin;
	guard arguments.count == 4 else {
		translate_help(arguments: arguments);
		print("Available charsets:");
		for name in graph.nodes.sorted() {
			print("\t\(name)");
		}
		return 1;
	}

	// TODO: This only works over stdin for now, maybe later pass a filename
	let source = arguments[2];
	let target = arguments[3];
	let imported: Data? = FileHandle.standardInput.availableData
	guard let imported else {
		fatalError("Failed to read input")
	}

	let tr = graph.find(source: source, target: target);
	guard let tr else {
		print("Could not find a homomorphism from \(source) to \(target)");
		exit(1);
	}
	let string = tr.tr(imported.map {UInt32($0)});
	guard let string else {
		fatalError("No equivalent form in specified format")
	}

	// Convert multibyte character sets to little-endian
	// Which is not network order, but typically expected by operatin systems
	switch target {
		case "UTF-16":
			var data = Data();
			data.reserveCapacity(string.count * MemoryLayout<UInt16>.size)
			for value in string {
				data.append(UInt8(truncatingIfNeeded: value));
				data.append(UInt8(truncatingIfNeeded: value >> 8));
			}
			FileHandle.standardOutput.write(data);

		case "UTF-32":
			var data = Data();
			data.reserveCapacity(string.count * MemoryLayout<UInt32>.size)
			for value in string {
				withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
			}
			FileHandle.standardOutput.write(data);

		default:
			// Most charsets are 8-bit
			var data = Data();
			data.reserveCapacity(string.count * MemoryLayout<UInt8>.size)
			data.append(contentsOf: string.map{UInt8($0 & 0xFF)})
			FileHandle.standardOutput.write(data);
	}
	return 0
}
