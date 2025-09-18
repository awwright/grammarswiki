# grammars UI App

A simple macOS app for browsing protocols and grammars.

## Dependencies

* CodeEditorView

## Stories

### Features

* Browse a comprehensive catalog of context-free grammars defined for use in open standards and Internet protocols.

* write my own grammars, for internal applications or for specifying changes to protocols, or for proposing new standard protocols.

* specify extension points, specifying what the default behavior is, and who is allowed to define changes to the default behavior.

* browse examples and documentation for the existing protocols.

* fork a grammar to make edits to it; and compare the fork for all of the changes from the original.

* Click links and edit documentation embedded in the comments

* Jump to definitions and see usage of a rule in the same file, and other files in the project or catalog

* embed existing protocols in the new protocols, as desired (for example, JSON or date/time formats).

* run example inputs to the grammars and see how it parses

* perform computations on the languge, such as the union, intersection, or concatenation, and test the languages for ambiguity. If a language is ambiguous, it should be able to identify the strings that are and are not ambiguous

* configure options on the language, like excluding certain rules because they are deprecated.

* export the grammar into a language for my progrmaming environment, for example, as a regular expression, or code for a parser generator.

* translate from one language to another, and make edits to the generated translation and have it propogate back to the source document.

* visualize a plot of the grammar, in various formats, like a railroad diagram, state machine, etc.

* write normalization patterns and make equivalencies between strings, for example, specifying that a string is case-insensitive, or specifying escape patterns for certain characters.

* Ability to import code from programming languages and parse it into a context-free grammar

