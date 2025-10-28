import Testing;
@testable import FSM;

// This file runs the same tests on a whole bunch of different conforming types.
// Swift doesn't have an obvious way to do this, so there's lots of boilerplate in this file.

private protocol RegularPatternBuilderData: RegularPatternBuilder {
	associatedtype FSM: DFAProtocol;
	var fsm: FSM { get };
}

extension ABNFAlternation: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<Symbol>;
	var fsm: SymbolDFA<Symbol> { try! self.toPattern() }
}

extension SymbolClassDFA: RegularPatternBuilderData where Alphabet.Symbol: BinaryInteger, Alphabet.Element == SymbolClass {
	typealias FSM = SymbolClassDFA<Alphabet>;
	var fsm: FSM { self.toPattern() }
}

extension SymbolClassNFA: RegularPatternBuilderData where Alphabet.Symbol: BinaryInteger {
	typealias FSM = SymbolClassDFA<Alphabet>;
	var fsm: FSM { self.toDFA().fsm }
}

extension REPattern<UInt8>: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<UInt8>;
	var fsm: SymbolDFA<UInt8> { self.toPattern() }
}

extension SimpleRegex: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<Symbol>;
	var fsm: SymbolDFA<Symbol> { self.toPattern() }
}

private struct RegularPatternBuilderTests {
	// "Pattern Type"
	struct PT: CustomDebugStringConvertible {
		var type: any RegularPatternBuilderData.Type
		var alpha: any RegularPatternBuilderData
		var beta: any RegularPatternBuilderData
		var debugDescription: String { "\(type)" }
		init<T: RegularPatternBuilderData>(_ type: T.Type, _ alpha: T, _ beta: T) {
			self.type = type
			self.alpha = alpha
			self.beta = beta
		}
	}

	static var allTests = [
		PT(ABNFAlternation<UInt8>.self, .symbol(1), .symbol(2)),
		PT(SymbolDFA<UInt8>.self, .symbol(1), .symbol(2)),
		PT(SymbolClassNFA<SymbolAlphabet<UInt8>>.self, .symbol(1), .symbol(2)),
		PT(RangeDFA<UInt8>.self, .symbol(1), .symbol(2)),
		PT(RangeDFA<UInt8>.self, .symbol(range: [0...3, 8...9]), .symbol(range: [4...7])),
		PT(REPattern<UInt8>.self, .symbol(1), .symbol(2)),
		PT(SimpleRegex<UInt8>.self, .symbol(1), .symbol(2)),
	];

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func toPattern_empty(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			let alpha = helper.alpha as! T
			let beta = helper.beta as! T
			#expect(T.empty == T.empty)
			#expect(T.empty != T.epsilon)
			#expect(T.empty != alpha)
			#expect(T.empty != beta)
			#expect(T.empty.fsm == T.empty.fsm)
			#expect(T.empty.fsm != T.epsilon.fsm)
			#expect(T.empty.fsm != alpha.fsm)
			#expect(T.empty.fsm != beta.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_epsilon(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			let alpha = helper.alpha as! T
			let beta = helper.beta as! T
			#expect(T.epsilon != T.empty)
			#expect(T.epsilon == T.epsilon)
			#expect(T.epsilon != alpha)
			#expect(T.epsilon != beta)
			#expect(T.epsilon.fsm != T.empty.fsm)
			#expect(T.epsilon.fsm == T.epsilon.fsm)
			#expect(T.epsilon.fsm != alpha.fsm)
			#expect(T.epsilon.fsm != beta.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_data(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			let alpha = helper.alpha as! T
			let beta = helper.beta as! T
			#expect(alpha != T.empty)
			#expect(alpha != T.epsilon)
			#expect(alpha == alpha)
			#expect(alpha != beta)
			#expect(alpha.fsm != T.empty.fsm)
			#expect(alpha.fsm != T.epsilon.fsm)
			#expect(alpha.fsm == alpha.fsm)
			#expect(alpha.fsm != beta.fsm)
			#expect(beta != T.empty)
			#expect(beta != T.epsilon)
			#expect(beta != alpha)
			#expect(beta == beta)
			#expect(beta.fsm != T.empty.fsm)
			#expect(beta.fsm != T.epsilon.fsm)
			#expect(beta.fsm != alpha.fsm)
			#expect(beta.fsm == beta.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_union(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			let alpha = helper.alpha as! T
			let beta = helper.beta as! T
			#expect(T.empty.union(T.empty).fsm == T.empty.fsm)
			#expect(T.empty.union(T.epsilon).fsm == T.epsilon.fsm)
			#expect(T.epsilon.union(T.empty).fsm == T.epsilon.fsm)
			#expect(T.epsilon.union(T.epsilon).fsm == T.epsilon.fsm)
			#expect(alpha.union(T.empty).fsm == alpha.fsm)
			#expect(alpha.union(T.epsilon).fsm == alpha.fsm.union(T.epsilon.fsm))
			#expect(alpha.union(alpha).fsm == alpha.fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_concatenate(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			let alpha = helper.alpha as! T
			let beta = helper.beta as! T
			#expect(T.empty.concatenate(T.empty).fsm == T.empty.fsm)
			#expect(T.empty.concatenate(T.epsilon).fsm == T.empty.fsm)
			#expect(T.epsilon.concatenate(T.empty).fsm == T.empty.fsm)
			#expect(T.epsilon.concatenate(T.epsilon).fsm == T.epsilon.fsm)
			#expect(alpha.concatenate(T.empty).fsm == T.empty.fsm)
			#expect(alpha.concatenate(T.epsilon).fsm == alpha.fsm)
			#expect(alpha.concatenate(T.epsilon).concatenate(beta).fsm == alpha.fsm.concatenate(beta.fsm))
			#expect(alpha.concatenate(alpha).fsm == T.concatenate([ alpha, alpha ]).fsm)
		}
		test(helper.type)
	}

	@Test(arguments: RegularPatternBuilderTests.allTests)
	func test_star(_ helper: PT) {
		func test<T: RegularPatternBuilderData>(_ type: T.Type) {
			let alpha = helper.alpha as! T
			let beta = helper.beta as! T
			#expect(T.empty.star().fsm == T.empty.fsm.star())
			#expect(T.epsilon.star().fsm == T.epsilon.fsm.star())
			#expect(alpha.star().fsm == alpha.fsm.star())
		}
		test(helper.type)
	}
}
