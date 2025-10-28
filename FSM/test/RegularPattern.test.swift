import Testing;
@testable import FSM;

// This file runs the same tests on a whole bunch of different conforming types.
// Swift doesn't have an obvious way to do this, so there's lots of boilerplate in this file.

protocol RegularPatternBuilderData: RegularPatternBuilder {
	associatedtype FSM: DFAProtocol;
	static var alpha: Self { get };
	static var beta: Self { get };
	var fsm: FSM { get };
}

extension ABNFAlternation<UInt8>: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<UInt8>;
	static var alpha: ABNFAlternation<UInt8> { .symbol(1) }
	static var beta: ABNFAlternation<UInt8> { .symbol(2) }
	var fsm: SymbolDFA<UInt8> { try! self.toPattern() }
}

extension SymbolDFA<UInt8>: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<UInt8>;
	static var alpha: SymbolDFA<UInt8> { .symbol(1) }
	static var beta: SymbolDFA<UInt8> { .symbol(2) }
	var fsm: SymbolDFA<UInt8> { self.toPattern() }
}

extension SymbolClassNFA<SymbolAlphabet<UInt8>>: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<UInt8>;
	static var alpha: SymbolClassNFA<SymbolAlphabet<UInt8>> { .symbol(1) }
	static var beta: SymbolClassNFA<SymbolAlphabet<UInt8>> { .symbol(2) }
	var fsm: SymbolDFA<UInt8> { self.toDFA().fsm }
}

extension REPattern<UInt8>: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<UInt8>;
	static var alpha: REPattern<UInt8> { .symbol(1) }
	static var beta: REPattern<UInt8> { .symbol(2) }
	var fsm: SymbolDFA<UInt8> { self.toPattern() }
}

extension SimpleRegex<UInt8>: RegularPatternBuilderData {
	typealias FSM = SymbolDFA<UInt8>;
	static var alpha: SimpleRegex<UInt8> { .symbol(1) }
	static var beta: SimpleRegex<UInt8> { .symbol(2) }
	var fsm: SymbolDFA<UInt8> { self.toPattern() }
}

struct RegularPatternBuilderTests {
	struct PT: CustomDebugStringConvertible {
		var type: any RegularPatternBuilderData.Type
		var debugDescription: String { "\(type)" }
		init<T: RegularPatternBuilderData>(_ type: T.Type) {
			self.type = type
		}
	}

	static var allTests = [
		PT(ABNFAlternation<UInt8>.self),
		PT(SymbolDFA<UInt8>.self),
		PT(SymbolClassNFA<SymbolAlphabet<UInt8>>.self),
		PT(REPattern<UInt8>.self),
		PT(SimpleRegex<UInt8>.self),
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
