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
	let catalog = Catalog(root: FileManager.default.currentDirectoryPath + "");
	let rule = ABNFRulename<UInt32>(label: rulename);
	let ruleid = rule.id; // ABNFRulename automatically normalizes the rule label
	let (rulelist_source, rulelist_merged, rulelist_backwards): (source: Dictionary<String, ABNFRulelist<UInt32>>, merged: ABNFRulelist<UInt32>, [String: (filename: String, ruleid: String)]) = try! catalog.load(path: filePath, rulenames: [ruleid])
	let rulelist = rulelist_merged.ruleNames;

	guard rulelist.contains(ruleid) else {
		res.status = .notFound
		res.end()
		return
	}

	let rules_dict = rulelist_merged.dictionary;
	let rules_labels = rules_dict.mapValues { $0.rulename.label }
	// rule should be guaranteed to exist due to `guard rulelist.contains(rulename)` above
	let expression = rules_dict[ruleid]!
	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let builtins = ABNFBuiltins<SymbolClassDFA<ClosedRangeAlphabet<UInt32>>>.dictionary;
	let definition_dependencies = rulelist_merged.dependencies(rulename: ruleid)

	// First, print the rules as defined.
	// This page includes only the rules necessary to define the top rule, including foreign rules.
	// This means that we don't include comments for the time being (which comments are associated with each rule? Sometimes hard to say.)
	var rule_links: Dictionary<String, String> = [:];
	builtins.keys.forEach { rule_links[$0] = "../abnf-core/\($0.uppercased()).html" };
	// FIXME: Why does rules_labels sometimes not map?
	rulelist_backwards.forEach { rule_links[$0.key] = "../\($0.value.filename.replacingOccurrences(of: ".abnf", with: ""))/\(rules_labels[$0.value.ruleid] ?? $0.value.ruleid).html" };

	let definition_list_html = definition_dependencies.dependencies.reversed().map {
		let rule = rules_dict[$0]
		guard let rule else {
			// TODO: Detect if this is a builtin rule or just an unknown rule
			// And display the builtin rules, maybe
			//return "\t\t\t<li><code>; Unknown rule: " + text_html($0) + "</code></li>\n"
			return ""
		}
		return rule_to_html(rule, links: rule_links);
	}.joined()

	let rr: RailroadNode = expression.toRailroad()
	let railroad_svg_html: String = toContainerNode(rr).toSVGNode(offset: .init(x: 0, y: 0)).toSVG();

	// TODO: Add GraphViz diagram

	// builtins will be copied to the output
	// TODO: Add Swift NSRegularExpression
	let fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>;
	var result_fsm_dict: Dictionary<String, SymbolClassDFA<ClosedRangeAlphabet<UInt32>>> = builtins;
	let regex_es_str: String;
	let regex_swift_str: String;
	let regex_egrep_str: String;

	if definition_dependencies.recursive.isEmpty {
		do {
			// FIXME: toClosedRangePattern should just be toPattern otherwise I'm going to keep shooting myself in the foot with the much slower toPattern
			for depname in definition_dependencies.dependencies {
				let definition = rules_dict[depname]
				guard let definition else { continue }
				let pat = try definition.toClosedRangePattern(rules: result_fsm_dict);
				result_fsm_dict[depname] = pat.minimized()
			}
			if let rule_fsm = result_fsm_dict[ruleid] {
				fsm = rule_fsm
				let regex: REPattern<UInt32> = fsm.toPattern()
				regex_es_str = REDialectBuiltins.ecmascriptLiteral.encodeWhole(regex.factorRepetition());
				regex_swift_str = REDialectBuiltins.swift.encode(regex.factorRepetition());
				regex_egrep_str = REDialectBuiltins.posixExtended.encode(regex);
			} else {
				fsm = .empty
				regex_es_str = "[no fsm]"
				regex_swift_str = "[no fsm]"
				regex_egrep_str = "[no fsm]"
			}
		} catch {
			fsm = .empty
			regex_es_str = "[error]"
			regex_swift_str = "[error]"
			regex_egrep_str = "[error]"
		}
	} else {
		fsm = .empty
		regex_es_str = "[recursive]"
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

	// Dependencies: rules depended upon by the top rule, with links using original labels from source
	// This is pretty much just the rule names from definition_list_html but with links and listed in reverse order
	// TODO: This should list iself only if the rule is recursive (i.e. not regular)!
	let dependencies_html = definition_dependencies.dependencies.dropLast().map { dep in
		//print(dep);
		guard let (filename, original_id) = rulelist_backwards[dep] else {
			// TODO: Implicitly load abnf-core.abnf when dereferencing rules, and just use that file
			if builtins[dep] != nil {
				return "<a href=\"../abnf-core/\(text_attr(dep.uppercased())).html\">\(text_html(dep.uppercased()))</a>";
			}
			return text_html(dep);
		}
		guard let source_rules = rulelist_source[filename] else { return text_html(dep); }
		guard let defining_rule = source_rules.dictionary[original_id] else { return text_html(dep); }
		let original_label = defining_rule.rulename.label;
		let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent;
		if filename == filePath {
			let link_path = "\(original_label).html";
			return "<a href=\"\(text_attr(link_path))\">\(text_html(original_label))</a>";
		} else {
			let link_path = "../\(base)/\(original_label).html";
			return "<a href=\"\(text_attr(link_path))\">\(text_html(base))#\(text_html(original_label))</a>";
		}
	}.joined(separator: ", ");

	// Used Builtins
	let used_builtins_html = definition_dependencies.builtins.map {
		"<a href=\"\(text_attr("../abnf-core/\($0.uppercased()).html"))\">" + text_html($0.uppercased()) + "</a>"
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
				<dd>\(dependencies_html)</dd>
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
				<h3>ECMAScript/JavaScript Regular Expression Literal</h3>
				<pre>\(text_html(regex_es_str))</pre>
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
