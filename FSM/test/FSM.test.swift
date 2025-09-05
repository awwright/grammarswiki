import Testing
@testable import FSM

@Test func testFSM() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
	#expect(SymbolDFA(verbatim: "foo").contains("") == false)
	#expect(SymbolDFA(verbatim: "foo").contains("bar") == false)
	#expect(SymbolDFA(verbatim: "foo").contains("foo") == true)
}
