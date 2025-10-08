// A SwiftUI View for rendering railroad diagrams
import FSM
import SwiftUI

struct DFARailroadView: View {
	typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	@Binding var rule_fsm: DFA?

	var body: some View {
		// TODO: Accept a given grammar or DFA and render it as a railroad diagram
		// Perhaps create a new protocol RailroadGeneratorProtocol that specifies how to transform
		// a given document into a RailroadDiagram. Then display it here.
		Text("Railroad Diagram").font(.headline)
	}

	func nodePosition(_ i: Int, in geometry: GeometryProxy) -> CGPoint {
		let dfa: DFA = rule_fsm ?? DFA()
		let n = dfa.states.count
		let angle = 2 * Double.pi * Double(i) / Double(n)
		let x = cos(angle)
		let y = sin(angle)
		let scale = min(geometry.size.width, geometry.size.height) / 2 - 20 // Margin
		return CGPoint(
			x: geometry.size.width / 2 + scale * x,
			y: geometry.size.height / 2 + scale * y
		)
	}
}
