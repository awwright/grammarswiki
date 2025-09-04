#!/bin/zsh
set -ex
for grammar_path in catalog/*.abnf; do
	grammar=${grammar_path%%.abnf}
	# Just in case you also want to generate the grammar index page
	#bin/grammartool grammar-abnf-html $grammar_path > htdocs/$grammar.html
	test -d htdocs/$grammar || mkdir htdocs/$grammar
	for rulename in $(bin/grammartool abnf-list-rulenames $grammar_path); do
		bin/grammartool grammar-abnf-rule-html $grammar_path $rulename > htdocs/$grammar/$rulename.html
	done
done
