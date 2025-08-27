import FSM;
import Foundation

func grammar_abnf_rule_html_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("grammar-abnf-rule-html")) <file.abnf> <rulename>");
	print("\tGernerate HTML page about a single rule within the given grammar file");
}

func grammar_abnf_rule_html_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4 else {
		grammar_abnf_rule_html_help(arguments: arguments)
		return 1
	}
	let filePath = arguments[2];
	let rulename = arguments[3];
	grammar_abnf_rule_html_run(response: &stdout, filePath: filePath, rulename: rulename)
	return stdout.exitCode
}

func grammar_abnf_rule_html_run(response res: inout some ResponseProtocol, filePath: String, rulename: String) {
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

	guard rulelist.contains(rulename) else {
		res.status = .notFound
		res.end()
		return
	}

	let rules_dict = root_parsed.dictionary
	// rule should be guaranteed to exist due to `guard rulelist.contains(rulename)` above
	let expression = rules_dict[rulename]!
	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let builtins = ABNFBuiltins<SymbolClassDFA<ClosedRangeAlphabet<UInt32>>>.dictionary;

	// Dereference rules referencing other files
	let rulelist_all_final = try! dereferenceABNFRulelist(root_parsed, {
		filename in
		let filePath = FileManager.default.currentDirectoryPath + "/catalog/" + filename
		let content = try String(contentsOfFile: filePath, encoding: .utf8)
		return try ABNFRulelist<UInt32>.parse(content.replacingOccurrences(of: "\n", with: "\r\n").replacingOccurrences(of: "\r\r", with: "\r").utf8)
	});
	let rulelist_all_dict = rulelist_all_final.dictionary

	// builtins will be copied to the output
	//let importedDict = try! rulelist_all_final.toPattern(as: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>.self, rules: builtins).mapValues { $0.minimized() }
	//let fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>> = try! expression.toPattern(rules: importedDict)
	//let regex: REPattern<UInt32> = fsm.toPattern()
	let regex_str = ""

	// Build definition
	let definition_dependencies = rulelist_all_final.dependencies(rulename: rulename)
	let definition_list = definition_dependencies.dependencies.reversed().map {
		rulelist_all_dict[$0]?.description ?? ""
	}
	let definition_list_html = definition_list.map { "\t\t\t\t<li><code>" + text_html($0.replacingOccurrences(of: "\r\n", with: "")) + "</code></li>\n" }.joined()

	let title = "Rule \(rulename) in \(filePath)"
	let main_html = """

		<section>
		<h1>From \(text_html(filePath)) rule: \(text_html(rulename))</h1>

		<h2>Definition</h2>
		<ul>\(definition_list_html)
		</ul>

		</section>
		<section>
			<h2>Info</h2>
			<dl>
				<dt>Rulename</dt>
				<dd>\(text_html(rulename))</dd>
				<dt>Dependencies</dt>
				<dd>\(text_html(definition_dependencies.dependencies.joined(separator: ", ")))</dd>
				<dt>Used Builtins</dt>
				<dd>\(text_html(definition_dependencies.builtins.joined(separator: ", ")))</dd>
			</dl>


			<h2>Alphabet</h2>
			<ul>
			</ul>

			<h2>Translations</h2>
			<section>
				<h3>Railroad Diagram</h3>
				<pre></pre>
			</section>
			<section>
				<h3>Swift Regular Expression</h3>
				<pre>\(regex_str)</pre>
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
