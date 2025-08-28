import FSM;
import Foundation;
private typealias Symbol = UInt32;
private typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<Symbol>>;

func abnf_to_railroad_help(arguments: Array<String>) {
	print("\(arguments[0]) \(bold("abnf-to-railroad")) <filepath> <expression>");
	print("\tReads <filepath> and converts <rulename> to a railroad script for railroad.js");
}

func abnf_to_railroad_args(arguments: Array<String>) -> Int32 {
	guard arguments.count >= 3 && arguments.count <= 4 else {
		print(arguments.count);
		abnf_to_railroad_help(arguments: arguments);
		return 1;
	}

	let imported: Data?;
	let expressionIndex: Array.Index
	if(arguments.count == 4){
		imported = getInput(filename: arguments[2]);
		expressionIndex = 3;
	} else {
		imported = nil
		expressionIndex = 2;
	}

	// Prepare the list of builtin rules, which the imported dict and expression can refer to
	let builtins = ABNFBuiltins<DFA>.dictionary;

	// builtins will be copied to the output
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
			return "Optional(\(processElement(repetition.element)))"
		} else if repetition.min == 1 && repetition.max == 1 {
			return processElement(repetition.element)
		} else if repetition.min == 0 && repetition.max == nil {
			return "ZeroOrMore(\(processElement(repetition.element)))"
		} else if repetition.min == 1 && repetition.max == nil {
			return "OneOrMore(\(processElement(repetition.element)))"
		} else {
			return "NonTerminal('Repeat')"
		}
	}

	func processElement(_ element: ABNFElement<Symbol>) -> String {
		"\"\(element.description)\""
	}

	print("Diagram(");
	print(processAlternation(dereferencedRulelist.dictionary[arguments[3]]!.alternation));
	print(");");

	return 0
}
