import Testing
@testable import FSM

@Test func testFSM() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
	#expect(DFA(verbatim: "foo").contains("") == false)
	#expect(DFA(verbatim: "foo").contains("bar") == false)
	#expect(DFA(verbatim: "foo").contains("foo") == true)
}
