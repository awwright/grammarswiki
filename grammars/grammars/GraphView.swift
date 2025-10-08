// A SwiftUI View accepting a FSM and outputting a plot of the finite state machine
import FSM
import SwiftUI

struct DFAGraphView: View {
	typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	@Binding var rule_fsm: DFA?
	let charset: Charset

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				let dfa: DFA = rule_fsm ?? DFA()
				// Draw initial
				EdgeView(
					source: nodePosition(dfa.initial, in: geometry) - CGPoint(x: 0, y: +40),
					target: nodePosition(dfa.initial, in: geometry),
					label: ""
				);

				// Draw edges
				ForEach(0..<dfa.states.count, id: \.self) { i in
					let list = Array(dfa.states[i].alphabet);
					ForEach(list, id: \.self) { symbol in
						let target = dfa.states[i][symbol]!
						EdgeView(
							source: nodePosition(i, in: geometry),
							target: nodePosition(target, in: geometry),
							label: describeCharacterSet(symbol, charset: charset)
						)
					}
				}
				// Draw nodes on top
				ForEach(0..<dfa.states.count, id: \.self) { i in
					NodeView(position: nodePosition(i, in: geometry), index: i, isFinal: dfa.isFinal(i))
				}
			}
		}
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

private struct NodeView: View {
	let position: CGPoint
	let index: Int
	let radius: CGFloat = 10
	let isFinal: Bool

	var body: some View {
		ZStack {
			if isFinal {
				Circle()
					.stroke(Color.black)
					.frame(width: 2 * (radius + 3), height: 2 * (radius + 3))
			}
			Circle()
				.fill(Color.white)
				.stroke(Color.black)
				.frame(width: 2 * radius, height: 2 * radius)
			Text("\(index)")
				.font(.caption)
		}
		.position(position)
	}
}

private struct EdgeView<Symbol: Hashable>: View {
	let source: CGPoint
	let target: CGPoint
	let label: Symbol
	let nodeRadius: CGFloat = 10
	let arrowSize: CGFloat = 10

	var body: some View {
		let direction = (target - source).normalized()
		let start = source + nodeRadius * direction
		let end = target - nodeRadius * direction

		// Draw the edge line
		Path { path in
			path.move(to: start)
			path.addLine(to: end)
		}
		.stroke(Color.black)

		// Draw the arrowhead
		let arrowDirection1 = direction.rotated(by: .pi / 6) // 30 degrees
		let arrowDirection2 = direction.rotated(by: -.pi / 6)
		Path { path in
			path.move(to: end)
			path.addLine(to: end - arrowSize * arrowDirection1)
			path.move(to: end)
			path.addLine(to: end - arrowSize * arrowDirection2)
		}
		.stroke(Color.black)

		// Place a label at the midpoint
		let midpoint = CGPoint(x: (2*start.x + end.x) / 3, y: (2*start.y + end.y) / 3)
		Text(String(describing: label))
			.font(.caption)
			.position(midpoint)
	}
}

extension CGPoint {
	static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
		return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}

	static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
		return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
	}

	static func * (scalar: CGFloat, point: CGPoint) -> CGPoint {
		return CGPoint(x: scalar * point.x, y: scalar * point.y)
	}

	func normalized() -> CGPoint {
		let length = sqrt(x * x + y * y)
		return length > 0 ? CGPoint(x: x / length, y: y / length) : CGPoint.zero
	}

	func rotated(by angle: CGFloat) -> CGPoint {
		let cosTheta = cos(angle)
		let sinTheta = sin(angle)
		return CGPoint(x: x * cosTheta - y * sinTheta, y: x * sinTheta + y * cosTheta)
	}
}
