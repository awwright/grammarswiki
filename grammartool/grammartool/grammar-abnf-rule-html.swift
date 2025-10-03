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
	let definition_dependencies = rulelist_all_final.dependencies(rulename: rulename)

	// First, print the rules as defined.
	// This page includes only the rules necessary to define the top rule, including foreign rules.
	// This means that we don't include comments for the time being (which comments are associated with each rule? Sometimes hard to say.)
	var rule_links: Dictionary<String, String> = [:];
	builtins.keys.forEach { rulename in rule_links[rulename] = "../abnf-core/\(rulename).html" };
	let definition_list_html = definition_dependencies.dependencies.reversed().map {
		let rule = rulelist_all_dict[$0]
		guard let rule else {
			// TODO: Detect if this is a builtin rule or just an unknown rule
			// And display the builtin rules, maybe
			//return "\t\t\t<li><code>; Unknown rule: " + text_html($0) + "</code></li>\n"
			return ""
		}
		return rule_to_html(rule, links: rule_links);
	}.joined()

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
				regex_swift_str = REDialectBuiltins.swift.encode(regex.factorRepetition());
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
	// TODO: Show hex codes in addition to printable
	// TODO: Name the corresponding Unicode character ranges, if any
	func printable(_ chr: UInt32) -> String {
		if chr <= 0x20 {
			return String(UnicodeScalar(0x2400 + chr)!)
		} else if chr < 0x7F {
			return String(UnicodeScalar(chr)!)
		} else if chr == 0x7F {
			return "\u{2421}"
		} else {
			// chr >= 0x80
			return String("U+" + String(chr, radix: 16).uppercased())
		}
	}
	let alphabet_parts: Array<String> = fsm.alphabet.map {
		// An alphabet partition has one or more closed ranges
		$0.map {
			r in
			if r.lowerBound == r.upperBound {
				printable(r.lowerBound)
			} else {
				"\(printable(r.lowerBound))\u{2026}\(printable(r.upperBound))"
			}
		}.joined(separator: " ")
	}
	let alphabet_parts_html: String = alphabet_parts.map {
		"\t\t\t<li><code>" + text_html($0) + "</code></li>\n"
	}.joined(separator: "")

	let railroad_svg_html: String = (try? grammar_abnf_rule_html_railroad_svg_pipeline(filePath, rulename)) ?? "Error"

	// Used Builtins
	let used_builtins_html = definition_dependencies.builtins.map {
		"<a href=\"\(text_attr("../abnf-core/\($0).html"))\">" + text_html($0) + "</a>"
	}.joined(separator: ", ")

	let title = "Rule \(rulename) in \(filePath)"

	// TODO: Inclue comments that appear to be related to the rule
	let head_html = """
		<link rel="stylesheet" href="https://unpkg.com/@highlightjs/cdn-assets@11.11.1/styles/xcode.min.css"/>

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
				<h3>Railroad Diagram</h3>
				<div>\(railroad_svg_html)</div>
			</section>
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

func grammar_abnf_rule_html_railroad_svg_pipeline(_ arg1: String, _ arg2: String) throws -> String {
	// Create the first process: bin/grammartool abnf-to-railroad arg1 arg2
	let grammartool = Process()
	grammartool.executableURL = URL(fileURLWithPath: "bin/grammartool")
	grammartool.arguments = ["abnf-to-railroad", arg1, arg2]

	// Create the second process: node bin/railroad.js
	let node = Process()
	node.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	node.arguments = ["node", "bin/railroad.js"]

	// Create a pipe to connect the processes
	let pipe = Pipe()
	grammartool.standardOutput = pipe
	node.standardInput = pipe

	// Create a pipe to capture the final output
	let outputPipe = Pipe()
	node.standardOutput = outputPipe

	// Run the processes
	try grammartool.run()
	try node.run()

	// Wait for both processes to complete
	grammartool.waitUntilExit()
	node.waitUntilExit()

	// Read the output
	let outputData = try outputPipe.fileHandleForReading.readToEnd()
	guard let output = outputData,
			let outputString = String(data: output, encoding: .utf8) else {
		throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read pipeline output"])
	}

	return outputString
}
