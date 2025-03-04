# Grammars.wiki

# Website

To run the website:

	$ node httpd/httpd.js

The website organized into the following taxonomy:


## 1. Concept

Concepts are essentially just brief encyclopedia pages to review a topic and link to the specifications that relate to it. When a protocol or some technology is broken up into multiple specification documents, perhaps because some are optional extensions to the core specification, they should all be described in a single "concept" article.

For example, Web, HTTP, URIs, Datetime, JSON, etc.

For the most part, concepts describe the up-to-date understanding.


## 2. Specification

A specification page describes which grammars are found within a specification. These are provided so you can read a specification, and look up all of the information on the grammars that it describes.

Specifications may also be imported from obsolete documents, for historical purposes.


## 3. Grammar

A grammar consists of a start grammar rule, plus additional rules that the start rule depends on. It also carries lots of information on usage and implementation status that individual rules are unlikely to have.

On the website, a grammar page describes the grammar, and provides various translations into 


## 4. Grammar rule

A grammar rule is a single rule that's found within a grammar. A grammar rule may contain references to other grammar rules.

The primary difference from a grammar is that a grammar rule is usually not used directly by developers, but typically only by a grammar, and so isn't listed in the list of grammars.


# Toolchain

The toolchain is the utilities that are capable of consuming and reasoning about grammars.

The input must define:

- The grammar
- Relationship of the grammar to other definitions
	- Particularly: history over time
- Equivalence schemes — which partitions of documents are supposed to be equivalent? e.g. whitespace.
	- Normalized forms — within an equivalence scheme, which form is preferred?
	- Possibility of multiple normal forms

Output targets:
- Railroad diagram
- Regular expressions, in a variety of dialects (when the grammar describes a regular language)
- Translations to languages, e.g. YACC
- Normalization function (in a variety of programming languages)

## Usage

A grammar is provided as a file on the filesystem. When identifying a grammar, provide a file path.

Grammars can contain many rules, which are themselves languages. If no rule name is provided, by default the first rule defined in the grammar will be used.


## parse-abnf

Parse an abnf file for rules. Extracts a (minimal) syntax tree that can be used to initialize a grammar.
The parser strictly implements ABNF, which requires CRLF line endings (including on the last line).
The parser is a bare-bones recursive descent parser so it will fail to parse the entire file if it can't parse any part of it.

```
$ node bin/parse-abnf.js catalog/abnf-syntax.abnf
```



# Catalog

The builtin library includes the following things:

Described grammars:
- RFC3339 Datetime
	- Date-time
	- Year
	- Time of day
	- Time Interval
- RFC3986 URI
- RFC3987 IRI
- RFC9110 HTTP fields
- RFC9112 HTTP message format
- JSON
- MIME messages
- IP addresses (in various flavors)
- Hostnames (in various flavors)
- Email addresses
	- Relevant obsolete grammars separated
	- Equivalence scheme for double quoted vs token forms
- Multipart encoding
	- Describe how multipart is a class of media type syntaxes all with different boundary markers.
