import FSM;

// Map the following ABNF rules to the following span names; but don't nest the spans, instead the innermost ABNF rule "wins"
// See <https://highlightjs.readthedocs.io/en/latest/css-classes-reference.html> for list of possible class names
// WSP / c-nl => (unwrapped)
// comment => hljs-comment
// "<" URI-reference ">" => <a href="">
// rulename => hljs-attribute
// "=" / "=/" => hljs-operator
// builtin rule name => hljs-keyword
// char-val => hljs-string
// num-val => hljs-symbol
// external rule name => <a href="">

// TODO: Eventually, print the whitespace/comments too
// TODO: If the rule is imported from a different grammar, link the rulename to its definition
/// Convert the given ABNFRule to HTML
/// - Parameters:
///   - rule: The rule to convert to HTML
///   - links: A list of rule names mapped to the URL that they should link to when used in a definition value
/// - Returns: String of HTML
func rule_to_html(_ rule: ABNFRule<UInt32>, links: Dictionary<String, String>) -> String {
	return "<span class=\"hljs-attribute\">\(text_html(rule.rulename.description))</span> <span class=\"hljs-operator\">\(text_html(rule.definedAs.description))</span> \(alternation_to_html(rule.alternation, links: links))\n\n"
}
func alternation_to_html(_ alternation: ABNFAlternation<UInt32>, links: Dictionary<String, String>) -> String {
	// Iterate over elements in the alternation
	alternation.matches.map { concatenation in
		concatenation.repetitions.map { repetition in
			let rangeop = Character(UnicodeScalar(repetition.rangeop))
			let repeat_html =
			if let max = repetition.max {
				if repetition.min == 1 && max == 1 { "" }
				else if(repetition.min == max && repetition.rangeop == 0x2A){ "\(repetition.min)" }
				else if repetition.min == 0 { "\(rangeop)\(max)" }
				else{ "\(repetition.min)\(rangeop)\(max)" }
			} else {
				if repetition.min == 0 { "\(rangeop)" }
				else{ "\(repetition.min)\(rangeop)" }
			}
			let expression_html =
			switch repetition.repeating {
				case .rulename(let r):
					if let uri = links[r.label] { "<a href=\"\(text_html(uri))\" class=\"hljs-variable\">" + text_html(r.description) + "</a>" }
					else { "<span class=\"hljs-variable\">" + text_html(r.description) + "</span>" }
				case .group(let o): "( " + alternation_to_html(o.alternation, links: links) + " )";
				case .option(let o): "[ " + alternation_to_html(o.optionalAlternation, links: links) + " ]";
				case .charVal(let c): "<span class=\"hljs-string\">" + text_html(c.description) + "</span>";
				case .numVal(let n): "<span class=\"hljs-number\">" + text_html(n.description) + "</span>";
				case .proseVal(let p): "<span class=\"hljs-formula\">" + text_html(p.description) + "</span>";
			};
			return repeat_html + expression_html;
		}.joined(separator: " ")
	}.joined(separator: " / ")
}
