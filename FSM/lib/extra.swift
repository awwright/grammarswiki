
func graphvizLabelEscapedString(_ input: String) -> String {
	var result = "\""
	result.reserveCapacity(input.count + 2)
	for char in input {
		switch char {
			case "\"": result += "\\\""
			case "\\": result += "\\\\"
			//case "{", "}", "|", "<", ">":
			//	// Escape only in record labels
			//	result += "\\\(char)"
			case "\n": result += "\\n" // Preserve as Graphviz newline
			case "\t": result += "\\t" // Optional: Graphviz doesn’t define \t, but often preserved
			case "\r": result += "\\r" // Optional: could use \l or \r for alignment
			default: result += String(char)
		}
	}
	result += "\""
	return result
}
