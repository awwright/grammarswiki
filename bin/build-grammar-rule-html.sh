#!/bin/zsh
set -x
for grammar_path in catalog/*.abnf; do
	grammar=${grammar_path%%.abnf}
	mkdir htdocs/$grammar
	for rulename in $(bin/grammartool abnf-list-rulenames $grammar_path); do
		bin/grammartool grammar-abnf-rule-html $grammar_path $rulename > htdocs/$grammar/$rulename.html
	done
done
