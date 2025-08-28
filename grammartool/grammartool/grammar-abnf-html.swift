import FSM;
import Foundation

func grammar_abnf_html_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("grammar-abnf-html")) <file.abnf>");
	print("\tGernerate HTML page about the given grammar file");
}

func grammar_abnf_html_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 3 else {
		grammar_abnf_html_help(arguments: arguments)
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

	// FIXME: This is a super hack
	let rulename = filePath.split(separator: "/").last!.replacingOccurrences(of: ".abnf", with: "")
	let rulenames_list_html = root_parsed.ruleNames.map {
		"<a href=\"\(text_attr("\(rulename)/\($0).html"))\">\(text_html($0))</a>"
	}.joined(separator: ", ")

	// Used Builtins
	let used_builtins_html = root_parsed.referencedRules.intersection(builtins.keys).sorted().map {
		"<a href=\"\(text_attr("abnf-core/\($0).html"))\">" + text_html($0) + "</a>"
	}.joined(separator: ", ")

	// builtins will be copied to the output
	//let importedDict = try! rulelist_all_final.toPattern(as: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>.self, rules: builtins).mapValues { $0.minimized() }

	let title = "Contents of \(filePath)"
	let head_html = """
		<link rel="stylesheet" href="https://unpkg.com/@highlightjs/cdn-assets@11.11.1/styles/xcode.min.css"/>
		<script src="https://unpkg.com/@highlightjs/cdn-assets@11.11.1/highlight.min.js"></script>
		<script src="https://unpkg.com/@highlightjs/cdn-assets@11.11.1/languages/abnf.min.js"></script>
		<script type="application/ecmascript">
		document.addEventListener('DOMContentLoaded', function() { hljs.highlightElement(document.getElementById('source')); });
		</script>

	""";

	let main_html = """

			<section>
				<h1>\(text_html(filePath))</h1>
				<div id="introduction-body"></div>
				<h2>Source</h2>
				<pre id="source"><code>\(text_html(importedAbnfString))</code></pre>
			</section>
			<section id="info">
				<h2>Info</h2>
				<dl>
					<dt>Rules</dt>
					<dd>\(rulenames_list_html)</dd>
					<dt>Dependencies</dt>
					<dd></dd>
					<dt>Used Builtins</dt>
					<dd>\(used_builtins_html)</dd>
				</dl>
			</section>
			<section id="alphabet">
				<h2>Alphabet</h2>
				<ul id="alphabet-list">
				</ul>
			</section>
			<section id="cited-by">
				<h2>Cited By</h2>
				<ul>
				</ul>
				<h2>Implementations</h2>
				<ul>
				</ul>
			</section>
	\t
	""".replacingOccurrences(of: "\t", with: "  ");
	res.status = .ok
	respond_themed_html(res: &res, title: title, head_html: head_html, main_html: main_html);
}
