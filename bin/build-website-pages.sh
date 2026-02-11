#!/bin/zsh
set -ex
pushd catalog

# Build only the index pages
for grammar_path in number.abnf rfc3986-uri.abnf rfc3987-iri.abnf rfc4647-langrange.abnf rfc5322-email.abnf rfc5646-langtag.abnf rfc6570-uri-template.abnf rfc8259-json-number.abnf; do
	grammar=${grammar_path%%.abnf}
	../bin/grammartool grammar-abnf-html $grammar_path > ../htdocs/catalog/$grammar.html
done

# Build index and rule pages
for grammar_path in abnf-core.abnf abnf-syntax.abnf rfc3339-datetime.abnf; do
	grammar=${grammar_path%%.abnf}
	../bin/grammartool grammar-abnf-html $grammar_path > ../htdocs/catalog/$grammar.html
	test -d ../htdocs/catalog/$grammar || mkdir ../htdocs/catalog/$grammar
	for rulename in $(../bin/grammartool abnf-list-rulenames $grammar_path); do
		../bin/grammartool grammar-abnf-rule-html $grammar_path $rulename > ../htdocs/catalog/$grammar/$rulename.html
	done
done
