// A SwiftUI View accepting a FSM and outputting a plot of the finite state machine
import FSM
import SwiftUI

struct DFAGraphView: View {
	typealias DFA = SymbolClassDFA<ClosedRangeAlphabet<UInt32>>
	// This comes in from ContentView normalized. If it's not normalized, paths will cross without reason and it'll look much worse.
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
		if n == 0 { return .zero }
		var levels: [Int: Int] = [:]
		var queue: [Int] = [dfa.initial]
		levels[dfa.initial] = 0
		var visited: Set<Int> = [dfa.initial]
		while !queue.isEmpty {
			let current = queue.removeFirst()
			let currentLevel = levels[current]!
			let list = Array(dfa.states[current].alphabet)
			for symbol in list {
				let next = dfa.states[current][symbol]!
				if !visited.contains(next) {
					visited.insert(next)
					levels[next] = currentLevel + 1
					queue.append(next)
				}
			}
		}
		var maxLevel = levels.values.max() ?? 0
		let unvisitedLevel = maxLevel + 1
		for j in 0..<n {
			if levels[j] == nil {
				levels[j] = unvisitedLevel
			}
		}
		var statesInLevel: [Int: [Int]] = [:]
		for (state, lev) in levels {
			statesInLevel[lev, default: []].append(state)
		}
		for key in statesInLevel.keys {
			statesInLevel[key] = statesInLevel[key]!.sorted()
		}
		let lev = levels[i]!
		let statesAtLev = statesInLevel[lev]!
		guard let idx = statesAtLev.firstIndex(of: i) else { return .zero }
		let num = statesAtLev.count
		maxLevel = levels.values.max() ?? 0
		let totalLevels = maxLevel + 1
		let layerHeight = geometry.size.height / CGFloat(totalLevels)
		let y = layerHeight * (CGFloat(lev) + 0.5)
		let layerWidth = geometry.size.width
		let x = layerWidth * (CGFloat(idx) + 0.5) / CGFloat(num)
		return CGPoint(x: x, y: y)
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
		ZStack {
			if source == target {
				let loopRadius: CGFloat = 15
				let center = source + CGPoint(x: 0, y: -nodeRadius - loopRadius)
				Path { path in
					path.addArc(center: center, radius: loopRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
				}.stroke(Color.black)
				let arrowAngle = Angle(degrees: 45)
				let arrowPos = center + CGPoint(x: loopRadius * cos(CGFloat(arrowAngle.radians)), y: loopRadius * sin(CGFloat(arrowAngle.radians)))
				let tangent = CGPoint(x: -sin(arrowAngle.radians), y: cos(arrowAngle.radians))
				Path { path in
					path.move(to: arrowPos)
					path.addLine(to: arrowPos - arrowSize * tangent.rotated(by: .pi / 6))
					path.move(to: arrowPos)
					path.addLine(to: arrowPos - arrowSize * tangent.rotated(by: -.pi / 6))
				}.stroke(Color.black)
				Text(String(describing: label))
					.font(.caption)
					.position(center + CGPoint(x: 0, y: -20))
			} else {
				let direction = (target - source).normalized()
				let start = source + nodeRadius * direction
				let end = target - nodeRadius * direction
				let isBackward = target.y < source.y
				if isBackward {
					let midX = (start.x + end.x) / 2
					let midY = min(start.y, end.y) - 50
					let control = CGPoint(x: midX, y: midY)
					Path { path in
						path.move(to: start)
						path.addQuadCurve(to: end, control: control)
					}
					.stroke(Color.black)
					let arrowDirection = (end - control).normalized()
					let arrowDirection1 = arrowDirection.rotated(by: .pi / 6)
					let arrowDirection2 = arrowDirection.rotated(by: -.pi / 6)
					Path { path in
						path.move(to: end)
						path.addLine(to: end - arrowSize * arrowDirection1)
						path.move(to: end)
						path.addLine(to: end - arrowSize * arrowDirection2)
					}
					.stroke(Color.black)
				} else {
					Path { path in
						path.move(to: start)
						path.addLine(to: end)
					}
					.stroke(Color.black)
					let arrowDirection1 = direction.rotated(by: .pi / 6)
					let arrowDirection2 = direction.rotated(by: -.pi / 6)
					Path { path in
						path.move(to: end)
						path.addLine(to: end - arrowSize * arrowDirection1)
						path.move(to: end)
						path.addLine(to: end - arrowSize * arrowDirection2)
					}
					.stroke(Color.black)
				}
				let midpoint = CGPoint(x: (2*start.x + end.x) / 3, y: (2*start.y + end.y) / 3)
				Text(String(describing: label))
					.font(.caption)
					.position(midpoint + CGPoint(x: 0, y: -10))
			}
		}
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
