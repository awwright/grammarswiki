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
	var rulelist_all_dict = rulelist_all_final.dictionary
	let definition_dependencies = rulelist_all_final.dependencies(rulename: rulename)

	// TODO: Add railroad diagram
	// TODO: Add GraphViz diagram

	// builtins will be copied to the output
	// TODO: Add Swift NSRegularExpression
	let fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>;
	var result_fsm_dict: Dictionary<String, SymbolClassDFA<ClosedRangeAlphabet<UInt32>>> = builtins;
	let regex_swift_str: String;
	let regex_egrep_str: String;

	if definition_dependencies.recursive.isEmpty {
		do {
			// FIXME: toClosedRangePattern should just be toPattern otherwise I'm going to keep shooting myself in the foot with the much slower toPattern
			for rulename in definition_dependencies.dependencies {
				let definition = rulelist_all_dict[rulename]
				guard let definition else { continue }
				let pat = try definition.toClosedRangePattern(rules: result_fsm_dict);
				result_fsm_dict[rulename] = pat.minimized()
			}
			if let rule_fsm = result_fsm_dict[rulename] {
				fsm = rule_fsm
				let regex: REPattern<UInt32> = fsm.toPattern()
				regex_swift_str = REDialectBuiltins.swift.encode(regex);
				regex_egrep_str = REDialectBuiltins.posixExtended.encode(regex);
			} else {
				fsm = .empty
				regex_swift_str = "[recursive]"
				regex_egrep_str = "[recursive]"
			}
		} catch {
			fsm = .empty
			regex_swift_str = "[error]"
			regex_egrep_str = "[error]"
		}
	} else {
		fsm = .empty
		regex_swift_str = "[recursive]"
		regex_egrep_str = "[recursive]"
	}

	// The "Alphabet" lists the partitions of characters that can be found in valid strings, and where characters in a partition are all interchangable with respect to the validity of the string
	let alphabet_parts: Array<String> = fsm.alphabet.map {
		"\($0)"
	}
	let alphabet_parts_html: String = alphabet_parts.map {
		"\t\t\t<li><code>" + text_html($0) + "</code></li>\n"
	}.joined(separator: "")

	let definition_list_html = definition_dependencies.dependencies.reversed().map {
		let rule = rulelist_all_dict[$0]
		guard let rule else {
			// TODO: Detect if this is a builtin rule or just an unknown rule
			// And display the builtin rules, maybe
			//return "\t\t\t<li><code>; Unknown rule: " + text_html($0) + "</code></li>\n"
			return ""
		}
		// TODO: If the rule is imported from a different grammar, link to that one directly
		return "" + text_html(rule.description.replacingOccurrences(of: "\r\n", with: "")) + "\n\n"
	}.joined()

	// Used Builtins
	let used_builtins_html = definition_dependencies.builtins.map {
		"<a href=\"\(text_attr("../abnf-core/\($0).html"))\">" + text_html($0) + "</a>"
	}.joined(separator: ", ")

	let title = "Rule \(rulename) in \(filePath)"

	// TODO: Render this ahead-of-time and link rule names and prose to their targets
	let head_html = """
		<link rel="stylesheet" href="https://unpkg.com/@highlightjs/cdn-assets@11.11.1/styles/xcode.min.css"/>
		<script type="module">
			import hljs from 'https://unpkg.com/@highlightjs/cdn-assets@11.11.1/es/highlight.min.js';
			import abnf from 'https://unpkg.com/@highlightjs/cdn-assets@11.11.1/es/languages/abnf.min.js';
			hljs.registerLanguage('abnf', abnf);
			document.querySelectorAll('#source').forEach(el => {
			hljs.highlightElement(el, { language: 'abnf' });
			});
		</script>

	""";
	let main_html = """

		<section>
			<h1>From \(text_html(filePath)) rule: \(text_html(rulename))</h1>

			<h2>Definition</h2>
			<pre id="source">
	\(definition_list_html)\t\t</pre>
		</section>
		<section>
			<h2>Info</h2>
			<dl>
				<dt>Rulename</dt>
				<dd>\(text_html(rulename))</dd>
				<dt>Dependencies</dt>
				<dd>\(text_html(definition_dependencies.dependencies.joined(separator: ", ")))</dd>
				<dt>Used Builtins</dt>
				<dd>\(used_builtins_html)</dd>
			</dl>

			<h2>Alphabet</h2>
			<ul>
	\(alphabet_parts_html)\t\t</ul>

			<h2>Translations</h2>
			<section>
				<h3>Swift Regular Expression</h3>
				<pre>\(text_html(regex_swift_str))</pre>
			</section>
			<section>
				<h3>POSIX Extended Regular Expression</h3>
				<pre>\(text_html(regex_egrep_str))</pre>
			</section>
		</section>

	""".replacingOccurrences(of: "\t", with: "  ");
	res.status = .ok
	respond_themed_html(res: &res, title: title, head_html: head_html, main_html: main_html);
}
