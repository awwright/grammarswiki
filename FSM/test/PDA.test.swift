import Testing
@testable import FSM

struct PDATest {
    @Test("Empty PDA accepts empty string")
    func testEmptyPDA() async throws {
        let pda = PDA<Character>(
            transitionsSet: [:],
            transitionsEpsilon: [:],
            initialStack: [PDA.State(state: 0, stack: [0])],
            finals: [0]
        )
        #expect(pda.contains(""))
        #expect(!pda.contains("a"))
        #expect(!pda.contains("ab"))
    }

    @Test("PDA accepts single 'a'")
    func testSingleA() async throws {
        let pda = PDA<Character>(
            transitionsSet: [
                PDA.Key(state: 0, stack: 0): Set([
                    ["a": PDA.TransitionTarget(toState: 1, pushStack: [0])]
                ])
            ],
            transitionsEpsilon: [:],
            initialStack: [PDA.State(state: 0, stack: [0])],
            finals: [1]
        )
        #expect(pda.contains("a"))
        #expect(!pda.contains(""))
        #expect(!pda.contains("aa"))
        #expect(!pda.contains("b"))
    }

    @Test("PDA for balanced parentheses (simple case)")
    func testBalancedParenthesesSimple() async throws {
        // PDA for ( and ) , accept () 
        // States: 0 initial, 1 after (, 2 final
        // Stack: [] or [(]
        let pda = PDA<Character>(
            transitionsSet: [
                PDA.Key(state: 0, stack: 0): Set([
                    ["(": PDA.TransitionTarget(toState: 0, pushStack: [0, 1])],
                ]),
                PDA.Key(state: 0, stack: 1): Set([
                    ["(": PDA.TransitionTarget(toState: 0, pushStack: [1, 1])],
                    [")": PDA.TransitionTarget(toState: 0, pushStack: [])],
                ])
            ],
            transitionsEpsilon: [
                PDA.Key(state: 0, stack: 0): Set([
                    PDA.TransitionTarget(toState: 1, pushStack: [0])
                ])
            ],
            initialStack: [PDA.State(state: 0, stack: [0])],
            finals: [1],
        )
        #expect(pda.contains("()"))
        #expect(!pda.contains(""))
        #expect(!pda.contains("("))
        #expect(!pda.contains(")"))
        #expect(!pda.contains(")("))
        #expect(!pda.contains("(("))
        #expect(!pda.contains("))"))
    }

    @Test("PDA with epsilon transitions")
    func testEpsilonTransitions() async throws {
        // PDA that accepts "" or "a" via epsilon
        let pda = PDA<Character>(
            transitionsSet: [
                PDA.Key(state: 0, stack: 0): Set([
                    ["a": PDA.TransitionTarget(toState: 1, pushStack: [0])]
                ])
            ],
            transitionsEpsilon: [
                PDA.Key(state: 0, stack: 0): Set([
                    PDA.TransitionTarget(toState: 1, pushStack: [0])
                ])
            ],
            initialStack: [PDA.State(state: 0, stack: [0]), PDA.State(state: 1, stack: [0])],
            finals: [1]
        )
        #expect(pda.contains(""))
        #expect(pda.contains("a"))
        #expect(!pda.contains("aa"))
    }
}
