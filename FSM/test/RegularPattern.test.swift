import Testing;
@testable import FSM;

// This file runs the same tests on a whole bunch of different conforming types.
// Swift doesn't have an obvious way to do this, so there's lots of boilerplate in this file.

private protocol RegularPatternBuilderData: RegularPatternBuilder {
	associatedtype FSM: DFAProtocol;
	static var alpha: Self { get };
	static var beta: Self { get };
	var fsm: FSM { get };
}

extension ABNFAlternation: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<Symbol>;
	static var alpha: ABNFAlternation<Symbol> { .symbol(1) }
	static var beta: ABNFAlternation<Symbol> { .symbol(2) }
	var fsm: SymbolDFA<Symbol> { try! self.toPattern() }
}

extension SymbolClassDFA: RegularPatternBuilderData where Alphabet.Symbol: BinaryInteger, Alphabet.Element == SymbolClass {
	typealias FSM = SymbolClassDFA<Alphabet>;
	static var alpha: SymbolClassDFA<Alphabet> { .symbol(1) }
	static var beta: SymbolClassDFA<Alphabet> { .symbol(2) }
	var fsm: FSM { self.toPattern() }
}

extension SymbolClassNFA: RegularPatternBuilderData where Alphabet.Symbol: BinaryInteger {
	typealias FSM = SymbolClassDFA<Alphabet>;
	static var alpha: SymbolClassNFA<Alphabet> { .symbol(1) }
	static var beta: SymbolClassNFA<Alphabet> { .symbol(2) }
	var fsm: FSM { self.toDFA().fsm }
}

extension REPattern<UInt8>: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<UInt8>;
	static var alpha: REPattern<UInt8> { .symbol(1) }
	static var beta: REPattern<UInt8> { .symbol(2) }
	var fsm: SymbolDFA<UInt8> { self.toPattern() }
}

extension SimpleRegex: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<Symbol>;
	static var alpha: SimpleRegex<Symbol> { .symbol(1) }
	static var beta: SimpleRegex<Symbol> { .symbol(2) }
	var fsm: SymbolDFA<Symbol> { self.toPattern() }
}

private struct RegularPatternBuilderTests {
	// "Pattern Type"
	struct PT: CustomDebugStringConvertible {
		var type: any RegularPatternBuilderData.Type
		var debugDescription: String { "\(type)" }
//		var alpha: any RegularPatternBuilderData
//		var beta: any RegularPatternBuilderData
		init<T: RegularPatternBuilderData>(_ type: T.Type, _ alpha: T, _ beta: T) {
			self.type = type
//			self.alpha = alpha
//			self.beta = beta
		}
	}

	static var allTests = [
		PT(ABNFAlternation<UInt8>.self, .symbol(1), .symbol(2)),
		PT(SymbolDFA<UInt8>.self, .symbol(1), .symbol(2)),
		PT(SymbolClassNFA<SymbolAlphabet<UInt8>>.self, .symbol(1), .symbol(2)),
		PT(RangeDFA<UInt8>.self, .symbol(1), .symbol(2)),
		PT(REPattern<UInt8>.self, .symbol(1), .symbol(2)),
		PT(SimpleRegex<UInt8>.self, .symbol(1), .symbol(2)),
	];

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func toPattern_empty(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			#expect(T.empty == T.empty)
			#expect(T.empty != T.epsilon)
			#expect(T.empty != T.alpha)
			#expect(T.empty != T.beta)
			#expect(T.empty.fsm == T.empty.fsm)
			#expect(T.empty.fsm != T.epsilon.fsm)
			#expect(T.empty.fsm != T.alpha.fsm)
			#expect(T.empty.fsm != T.beta.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_epsilon(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			#expect(T.epsilon != T.empty)
			#expect(T.epsilon == T.epsilon)
			#expect(T.epsilon != T.alpha)
			#expect(T.epsilon != T.beta)
			#expect(T.epsilon.fsm != T.empty.fsm)
			#expect(T.epsilon.fsm == T.epsilon.fsm)
			#expect(T.epsilon.fsm != T.alpha.fsm)
			#expect(T.epsilon.fsm != T.beta.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_data(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			#expect(T.alpha != T.empty)
			#expect(T.alpha != T.epsilon)
			#expect(T.alpha == T.alpha)
			#expect(T.alpha != T.beta)
			#expect(T.alpha.fsm != T.empty.fsm)
			#expect(T.alpha.fsm != T.epsilon.fsm)
			#expect(T.alpha.fsm == T.alpha.fsm)
			#expect(T.alpha.fsm != T.beta.fsm)
			#expect(T.beta != T.empty)
			#expect(T.beta != T.epsilon)
			#expect(T.beta != T.alpha)
			#expect(T.beta == T.beta)
			#expect(T.beta.fsm != T.empty.fsm)
			#expect(T.beta.fsm != T.epsilon.fsm)
			#expect(T.beta.fsm != T.alpha.fsm)
			#expect(T.beta.fsm == T.beta.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_union(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			#expect(T.empty.union(T.empty).fsm == T.empty.fsm)
			#expect(T.empty.union(T.epsilon).fsm == T.epsilon.fsm)
			#expect(T.epsilon.union(T.empty).fsm == T.epsilon.fsm)
			#expect(T.epsilon.union(T.epsilon).fsm == T.epsilon.fsm)
			#expect(T.alpha.union(T.empty).fsm == T.alpha.fsm)
			#expect(T.alpha.union(T.epsilon).fsm == T.alpha.fsm.union(T.epsilon.fsm))
			#expect(T.alpha.union(T.alpha).fsm == T.alpha.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_concatenate(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			#expect(T.empty.concatenate(T.empty).fsm == T.empty.fsm)
			#expect(T.empty.concatenate(T.epsilon).fsm == T.empty.fsm)
			#expect(T.epsilon.concatenate(T.empty).fsm == T.empty.fsm)
			#expect(T.epsilon.concatenate(T.epsilon).fsm == T.epsilon.fsm)
			#expect(T.alpha.concatenate(T.empty).fsm == T.empty.fsm)
			#expect(T.alpha.concatenate(T.epsilon).fsm == T.alpha.fsm)
			#expect(T.alpha.concatenate(T.epsilon).concatenate(T.beta).fsm == T.alpha.fsm.concatenate(T.beta.fsm))
			#expect(T.alpha.concatenate(T.alpha).fsm == T.concatenate([ T.alpha, T.alpha ]).fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_star(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			#expect(T.empty.star().fsm == T.empty.fsm.star())
			#expect(T.epsilon.star().fsm == T.epsilon.fsm.star())
			#expect(T.alpha.star().fsm == T.alpha.fsm.star())
		}
		test(helper.type)
	}
}
