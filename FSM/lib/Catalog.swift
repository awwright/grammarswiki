import Foundation; // import `String(contentsOfFile:)`

public struct Catalog {
	public let root: String;

	public init(root: String) {
		self.root = root
	}

	// Load the rules from an ABNF file, and all referenced rules
	public func load<T>(path: String) throws
		-> (rules: ABNFRulelist<T>, backward: Dictionary<String, (filename: String, ruleid: String)>)
	{
		func dereference(filename: String) throws -> ABNFRulelist<T> {
			let filePath = root + "/" + filename;
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
				.replacingOccurrences(of: "\n", with: "\r\n")
				.replacingOccurrences(of: "\r\r", with: "\r");
			return try ABNFRulelist<T>.parse(content.utf8);
		}
		return try dereferenceABNFRulelist(dereference(filename: path), dereference: dereference);
	}
}
