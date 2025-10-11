import FSM;
import Foundation;
private typealias Symbol = UInt32;

func abnf_to_railroad_js_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-railroad-js")) <filepath> <expression>");
	print("\tReads <filepath> and converts <rulename> to a railroad script for railroad.js");
}

func abnf_to_railroad_js_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4 else {
		print(arguments.count);
		abnf_to_railroad_js_help(arguments: arguments);
		return 1;
	}
	let imported = getInput(filename: arguments[2]);
	let dereferencedRulelist: ABNFRulelist<Symbol>
	do {
		let importedRulelist = try ABNFRulelist<Symbol>.parse(imported!);
		dereferencedRulelist = try dereferenceABNFRulelist(importedRulelist, {
			filename in
			let filePath = FileManager.default.currentDirectoryPath + "/catalog/" + filename
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
			return try ABNFRulelist<Symbol>.parse(content.utf8)
		});
	} catch {
		print("Could not parse input")
		print(error)
		return 2;
	}

	// Available function calls:
	// class DiagramMultiContainer extends FakeSVG
	// class Diagram extends DiagramMultiContainer
	// class ComplexDiagram extends FakeSVG
	// class Sequence extends DiagramMultiContainer
	// class Stack extends DiagramMultiContainer
	// class OptionalSequence extends DiagramMultiContainer
	// class AlternatingSequence extends DiagramMultiContainer
	// class Choice extends DiagramMultiContainer
	// class HorizontalChoice extends DiagramMultiContainer
	// class MultipleChoice extends DiagramMultiContainer
	// class Optional extends FakeSVG
	// class OneOrMore extends FakeSVG
	// class ZeroOrMore extends FakeSVG
	// class Group extends FakeSVG
	// class Start extends FakeSVG
	// class End extends FakeSVG
	// class Terminal extends FakeSVG
	// class NonTerminal extends FakeSVG
	// class Comment extends FakeSVG
	// class Skip extends FakeSVG
	// class Block extends FakeSVG
	// class TextDiagram

	let rule = dereferencedRulelist.dictionary[arguments[3]];
	guard let rule else {
		print(stderr, "Error: No such rule: \(arguments[3])");
		exit(1);
	}
	print(generateDiagram(rule));
	return 0
}

func abnf_to_railroad_svg_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-railroad-svg")) <filepath> <expression>");
	print("\tReads <filepath> and converts <rulename> to a railroad script for railroad.js");
}

func abnf_to_railroad_svg_args(arguments: Array<String>) -> Int32 {
	guard arguments.count == 4 else {
		print(arguments.count);
		abnf_to_railroad_svg_help(arguments: arguments);
		return 1;
	}
	let imported: Data? = getInput(filename: arguments[2]);
	guard let imported else { return 1 }
	// builtins will be copied to the output
	let dereferencedRulelist: ABNFRulelist<Symbol>
	do {
		let importedRulelist = try ABNFRulelist<Symbol>.parse(imported);
		dereferencedRulelist = try dereferenceABNFRulelist(importedRulelist, {
			filename in
			let filePath = FileManager.default.currentDirectoryPath + "/catalog/" + filename
			let content = try String(contentsOfFile: filePath, encoding: .utf8)
			return try ABNFRulelist<Symbol>.parse(content.utf8)
		});
	} catch {
		print("Could not parse input")
		print(error)
		return 2;
	}
	let rule = dereferencedRulelist.dictionary[arguments[3]];
	guard let rule else {
		print(stderr, "Error: No such rule: \(arguments[3])");
		exit(1);
	}

	// Create the second process: node bin/railroad.js
	let node = Process()
	node.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	node.arguments = ["node", "bin/railroad.js", "svg"]

	let inputPipe = Pipe()
	let outputPipe = Pipe()
	node.standardInput = inputPipe
	node.standardOutput = outputPipe
	node.standardError = FileHandle.standardError

	do {
		try node.run()
		if let scriptData = generateDiagram(rule).data(using: .utf8) {
			inputPipe.fileHandleForWriting.write(scriptData)
		}
		try! inputPipe.fileHandleForWriting.close()
		node.waitUntilExit()
		let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
		if let outputString = String(data: outputData, encoding: .utf8) {
			print(outputString, terminator: "")
		}
	} catch {
		print("Error running node: \(error)")
		return 3
	}

	return node.terminationStatus
}

private func generateDiagram(_ rule: ABNFRule<Symbol>) -> String {
	return "Diagram(Start({label: \(text_json(rule.rulename.label))}), \(processAlternation(rule.alternation)));";

	func processAlternation(_ alternation: ABNFAlternation<Symbol>) -> String {
		if(alternation.matches.count == 1){
			return processSequence(alternation.matches[0])
		}
		let elements = alternation.matches.map(processSequence)
		return "Choice(0, \(elements.joined(separator: ", ")))"
	}

	func processSequence(_ sequence: ABNFConcatenation<Symbol>) -> String {
		if(sequence.repetitions.count == 1){
			return processRepetition(sequence.repetitions[0])
		}
		let elements = sequence.repetitions.map(processRepetition)
		return "Sequence(\(elements.joined(separator: ", ")))"
	}

	func processRepetition(_ repetition: ABNFRepetition<Symbol>) -> String {
		if repetition.min == 0 && repetition.max == 1 {
			return "Optional(\(processElement(repetition.repeating)))"
		} else if repetition.min == 1 && repetition.max == 1 {
			return processElement(repetition.repeating)
		} else if repetition.min == 0 && repetition.max == nil {
			return "ZeroOrMore(\(processElement(repetition.repeating)))"
		} else if repetition.min == 1 && repetition.max == nil {
			return "OneOrMore(\(processElement(repetition.repeating)))"
		} else {
			var sequence: Array<String> = [];
			let element = processElement(repetition.repeating);
			for _ in 0..<repetition.min {
				sequence.append(element)
			}
			if repetition.max == nil {
				return "Sequence(\(sequence.joined(separator: ", ")), ZeroOrMore(\(element)))"
			} else if repetition.max! > repetition.min {
				for _ in repetition.min..<repetition.max! {
					sequence.append("Optional(\(element))")
				}
			}
			return "Sequence(\(sequence.joined(separator: ", ")))"
		}
	}

	func processElement(_ element: ABNFElement<Symbol>) -> String {
		switch element {
			case .rulename(let r):
				return "NonTerminal(\(text_json(r.label)), {href: \(text_json(r.label+".html"))})";
			case .group(let g):
				return "Group(\(processAlternation(g.alternation)))";
			case .option(let o):
				return "Optional(\(processAlternation(o.optionalAlternation)))";
			case .charVal(let c):
				if c.sequence.isEmpty {
					return "Skip()"
				}
				// FIXME: This is supposed to be case-insensitive
				return "Terminal(\(text_json(String(decoding: c.sequence, as: UTF32.self))))";
			case .numVal(let n):
				return "NonTerminal(\(text_json(n.description)))";
			case .proseVal(let p):
				return "Comment(\(text_json(p.description)))";
		}
	}

	func text_json(_ input: String) -> String {
		return "\"" + input
			.replacingOccurrences(of: "\r", with: "\\r")
			.replacingOccurrences(of: "\n", with: "\\n")
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\"", with: "\\\"")
		+ "\"";
	}
}
