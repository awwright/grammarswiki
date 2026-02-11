#!/bin/zsh
set -ex
pushd catalog
for grammar_path in *.abnf; do
	grammar=${grammar_path%%.abnf}
	# Just in case you also want to generate the grammar index page
	../bin/grammartool grammar-abnf-html $grammar_path > ../htdocs/catalog/$grammar.html
	test -d ../htdocs/catalog/$grammar || mkdir ../htdocs/catalog/$grammar
	for rulename in $(../bin/grammartool abnf-list-rulenames $grammar_path); do
		../bin/grammartool grammar-abnf-rule-html $grammar_path $rulename > ../htdocs/catalog/$grammar/$rulename.html
	done
done
