import FSM;
import Foundation

func grammar_abnf_html_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("grammar-abnf-html")) <file.abnf>");
	print("\tGernerate HTML page about the given grammar file");
}

func grammar_abnf_html_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3 else {
		catalog_list_help(arguments: arguments)
		return 1
	}
	let catalogPath = arguments[2];
	grammar_abnf_html_run(response: &stdout, filePath: catalogPath)
	return stdout.exitCode
}

func grammar_abnf_html_run(response res: inout some ResponseProtocol, filePath: String) {
	res.contentType = "application/xhtml+xml"

	let importedAbnf: Data? = getInput(filename: filePath);

	guard let importedAbnf else {
		res.status = .notFound
		res.end()
		return
	}
	guard let importedAbnfString = String(data: importedAbnf, encoding: .utf8) else {
		res.status = .notFound
		res.end()
		return
	}

	let root_parsed = try! ABNFRulelist<UInt32>.parse(importedAbnfString.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
	let rulelist = root_parsed.ruleNames;
	let firstRule = rulelist.first!;
	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let builtins = ABNFBuiltins<SymbolClassDFA<ClosedRangeAlphabet<UInt32>>>.dictionary;

	// Dereference rules referencing other files
	let rulelist_all_final = try! dereferenceABNFRulelist(root_parsed, {
		filename in
		let filePath = FileManager.default.currentDirectoryPath + "/catalog/" + filename
		let content = try String(contentsOfFile: filePath, encoding: .utf8)
		return try ABNFRulelist<UInt32>.parse(content.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
	});

	// builtins will be copied to the output
	let importedDict = try! rulelist_all_final.toPattern(as: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>.self, rules: builtins).mapValues { $0.minimized() }

	let expression: ABNFAlternation<UInt32> = try! ABNFAlternation<UInt32>.parse(firstRule.utf8);
	let fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>> = try! expression.toPattern(rules: importedDict)
	let regex: REPattern<UInt32> = fsm.toPattern()

	let title = "Contents of \(filePath)"
	let main_html = """

		<section>
		<h1>\(text_html(filePath))</h1>

		<h2>Source</h2>
		<pre><code>\(text_html(importedAbnfString))</code></pre>
		</section>
		<section>
			<h2>Info</h2>
			<dl>
				<dt>Rules</dt>
				<dd>\(root_parsed.ruleNames.joined(separator: ", "))</dd>
				<dt>Dependencies</dt>
				<dd></dd>
				<dt>Used Builtins</dt>
				<dd></dd>
			</dl>

			<h2>Alphabet</h2>
			<ul>
			</ul>

			<h2>Cited By</h2>
			<ul>
			</ul>
			<h2>Implementations</h2>
			<ul>
			</ul>
			<h2>Translations</h2>
			<section>
				<h3>Railroad Diagram</h3>
				<pre></pre>
			</section>
			<section>
				<h3>Swift Regular Expression</h3>
				<pre>\(regex.description)</pre>
			</section>
			<section>
				<h3>POSIX Extended Regular Expression</h3>
				<pre></pre>
			</section>
		</section>

	""".replacingOccurrences(of: "\t", with: "  ");
	res.status = .ok
	respond_themed_html(res: &res, title: title, main_html: main_html);
}
