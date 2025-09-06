# This file will update whenever the file listing in catalog/ does
# Changes to this file in turn regenerates indexes and file listings
-include .targets.mk

# Read some user configuration
-include .env

CLI=./bin/grammartool
PUBLISH_TARGET ?= ./publish_target

all: bin/grammartool all-htdocs

all-htdocs: htdocs/scripts/search-index.js

# htdocs/index.xhtml: .targets.mk $(CLI)
# 	$(CLI) index-html catalog/ > $@

# htdocs/catalog/%.html: catalog/%.abnf $(CLI)
# 	@mkdir -p htdocs/catalog
# 	$(CLI) grammar-abnf-html $< > $@

htdocs/scripts/search-index.js:
	node bin/build-search-index.js htdocs/catalog/*.html htdocs/catalog/*/*.html > $@

.targets.mk:
	# Update .targets.mk only when the files in catalog/ change
	@tmp=$$(mktemp); \
	echo 'CATALOG_ABNF_SRC = \\' > $$tmp; \
	ls catalog/*.abnf | tr '\n' ' ' >> $$tmp; \
	echo '' >> $$tmp; \
	if cmp -s .targets.mk $$tmp; then \
		rm $$tmp; \
	else \
		mv $$tmp .targets.mk; \
	fi

bin/grammartool: FSM/lib/*.swift grammartool/grammartool/*.swift
	xcodebuild -workspace Grammars.xcworkspace -scheme grammartool -configuration Release SYMROOT=$(PWD)/build
	cp $(PWD)/build/Release/grammartool $@

clean:
	rm -f htdocs/index.xhtml $(patsubst catalog/%.abnf,htdocs/catalog/%.html,$(CATALOG_ABNF_SRC))

publish:
	test -n "$(PUBLISH_TARGET)"
	rsync -av --exclude='.*' htdocs/ "$(PUBLISH_TARGET)"

.PHONY: all all-htdocs clean publish
