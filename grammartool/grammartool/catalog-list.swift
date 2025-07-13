import FSM;
import Foundation

func catalog_list_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("catalog-list")) <catlog-path>");
	print("\tRead <catalog-path> as a directory with .abnf files");
}

func catalog_list(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3 else {
		catalog_list_help(arguments: arguments)
		return 1
	}
	let catalogPath = arguments[2];

	let contents: [String];
	do {
		contents = try FileManager.default.contentsOfDirectory(atPath: arguments[2])
	} catch {
		print(error)
		contents = []
		return 1
	}
	for filename in contents {
		if filename.hasSuffix(".abnf") {
			//let filePath = catalogPath.appendingPathComponent(filename)
			// Remove fileExtension from the end of filename
			let name = filename
			print(name)
//			let content = FileManager.default.contents(atPath: catalogPath + "/" + name)
//			print(content ?? "")
		}
	}

	return 0
}
