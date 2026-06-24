import SwiftUI
import AppKit
import FSM

struct LabelInfo: Identifiable, Hashable {
	let id: UUID
	let origin: CGPoint
	let text: String
	let size: CGSize
}

struct ChoiceInsertionRegion: Identifiable {
	let id: UUID
	let spineX: CGFloat
	let insertionPoints: [(index: Int, y: CGFloat)]
}

protocol Node: Identifiable, Hashable {
	var id: UUID { get }

	func dimension(style: NodeStyle) -> NodeDimension
	func place(dimension: NodeDimension, offset: CGPoint) -> NodePlacement
	func draw(placement: NodePlacement, canvas: inout GraphicsContext, placeTextField: (UUID, CGRect) -> Void)

	func updatingLabel(id: UUID, to newLabel: String) -> any Node
	func splittingLabel(id: UUID, at offset: Int) -> any Node
	func insertingAlternative(into choiceID: UUID, at index: Int) -> any Node

	func contains(id: UUID) -> Bool
	func withFocusOn(id: UUID) -> any Node
}

struct NodeStyle: Hashable {
	var levelSpacing: CGFloat = 30
	var verticalSpacing: CGFloat = 28
	var fontSize: CGFloat = 12
	var nodePadding: CGFloat = 4
	var lineWidth: CGFloat = 1.5
	var nodeCornerRadius: CGFloat = 4
	var sequencePlacement: SequenceNode.PlacementStrategy = .topToBottom
	var arcRadius: CGFloat = 8
}

struct NodeDimension: Hashable {
	let node: any Node
	private let nodeID: UUID
	let size: CGSize
	let inPoint: CGPoint
	let outPoint: CGPoint
	let childDimensions: [NodeDimension]
	let childRelativeOffsets: [CGPoint]
	let cornerRadius: CGFloat
	let lineWidth: CGFloat
	let arcRadius: CGFloat

	init(
		node: any Node,
		size: CGSize,
		inPoint: CGPoint,
		outPoint: CGPoint,
		childDimensions: [NodeDimension],
		childRelativeOffsets: [CGPoint],
		cornerRadius: CGFloat,
		lineWidth: CGFloat,
		arcRadius: CGFloat
	) {
		self.node = node
		self.nodeID = node.id
		self.size = size
		self.inPoint = inPoint
		self.outPoint = outPoint
		self.childDimensions = childDimensions
		self.childRelativeOffsets = childRelativeOffsets
		self.cornerRadius = cornerRadius
		self.lineWidth = lineWidth
		self.arcRadius = arcRadius
	}

	static func == (lhs: NodeDimension, rhs: NodeDimension) -> Bool {
		lhs.nodeID == rhs.nodeID &&
		lhs.size == rhs.size &&
		lhs.inPoint == rhs.inPoint &&
		lhs.outPoint == rhs.outPoint &&
		lhs.arcRadius == rhs.arcRadius
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(nodeID)
		hasher.combine(size)
		hasher.combine(inPoint)
		hasher.combine(outPoint)
		hasher.combine(arcRadius)
	}
}

struct NodePlacement: Hashable {
	let node: any Node
	private let nodeID: UUID
	let size: CGSize
	let offset: CGPoint
	let inPoint: CGPoint
	let outPoint: CGPoint
	let childPlacements: [NodePlacement]
	let cornerRadius: CGFloat
	let lineWidth: CGFloat
	let arcRadius: CGFloat

	init(
		node: any Node,
		size: CGSize,
		offset: CGPoint,
		inPoint: CGPoint,
		outPoint: CGPoint,
		childPlacements: [NodePlacement],
		cornerRadius: CGFloat,
		lineWidth: CGFloat,
		arcRadius: CGFloat
	) {
		self.node = node
		self.nodeID = node.id
		self.size = size
		self.offset = offset
		self.inPoint = inPoint
		self.outPoint = outPoint
		self.childPlacements = childPlacements
		self.cornerRadius = cornerRadius
		self.lineWidth = lineWidth
		self.arcRadius = arcRadius
	}

	static func == (lhs: NodePlacement, rhs: NodePlacement) -> Bool {
		lhs.nodeID == rhs.nodeID &&
		lhs.size == rhs.size &&
		lhs.offset == rhs.offset &&
		lhs.inPoint == rhs.inPoint &&
		lhs.outPoint == rhs.outPoint &&
		lhs.arcRadius == rhs.arcRadius
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(nodeID)
		hasher.combine(size)
		hasher.combine(offset)
		hasher.combine(inPoint)
		hasher.combine(outPoint)
		hasher.combine(arcRadius)
	}
}

struct LabelNode: Node {
	let id = UUID()
	var label: String

	static private func textSize(for string: String, font: NSFont) -> CGSize {
		let attributes: [NSAttributedString.Key: Any] = [.font: font]
		return (string as NSString).size(withAttributes: attributes)
	}

	func dimension(style: NodeStyle) -> NodeDimension {
		let font = NSFont.systemFont(ofSize: style.fontSize, weight: .medium)
		let rawSize = Self.textSize(for: self.label, font: font)
		let w = max(6, rawSize.width + style.nodePadding * 2)
		let h = rawSize.height + style.nodePadding * 2
		let size = CGSize(width: w, height: h)
		let inP = CGPoint(x: 0, y: h / 2)
		let outP = CGPoint(x: w, y: h / 2)
		return NodeDimension(
			node: self,
			size: size,
			inPoint: inP,
			outPoint: outP,
			childDimensions: [],
			childRelativeOffsets: [],
			cornerRadius: style.nodeCornerRadius,
			lineWidth: style.lineWidth,
			arcRadius: style.arcRadius
		)
	}

	func place(dimension: NodeDimension, offset: CGPoint) -> NodePlacement {
		let absIn = CGPoint(x: offset.x + dimension.inPoint.x, y: offset.y + dimension.inPoint.y)
		let absOut = CGPoint(x: offset.x + dimension.outPoint.x, y: offset.y + dimension.outPoint.y)
		return NodePlacement(
			node: self,
			size: dimension.size,
			offset: offset,
			inPoint: absIn,
			outPoint: absOut,
			childPlacements: [],
			cornerRadius: dimension.cornerRadius,
			lineWidth: dimension.lineWidth,
			arcRadius: dimension.arcRadius
		)
	}

	func draw(placement: NodePlacement, canvas: inout GraphicsContext, placeTextField: (UUID, CGRect) -> Void) {
		let rect = CGRect(origin: placement.offset, size: placement.size)
		placeTextField(self.id, rect)
	}

	func updatingLabel(id: UUID, to newLabel: String) -> any Node {
		if self.id == id {
			var copy = self
			copy.label = newLabel
			return copy
		}
		return self
	}

	func splittingLabel(id: UUID, at offset: Int) -> any Node {
		guard self.id == id else { return self }

		let clamped = max(0, min(offset, label.count))
		let left = String(label.prefix(clamped))
		let right = String(label.dropFirst(clamped))

		return SequenceNode(children: [
			LabelNode(label: left),
			LabelNode(label: right)
		])
	}

	func contains(id: UUID) -> Bool {
		self.id == id
	}

	func withFocusOn(id: UUID) -> any Node {
		self
	}

	func insertingAlternative(into choiceID: UUID, at index: Int) -> any Node {
		self
	}
}

struct StartNode: Node {
	let id = UUID()

	func dimension(style: NodeStyle) -> NodeDimension {
		let barThickness: CGFloat = max(1.5, style.lineWidth);
		let barGap: CGFloat = 2.5;
		let h = max(16.0, style.fontSize * 1.25);
		let barHeight = h;

		let markerWidth = barThickness * 2 + barGap;
		let trackExtension: CGFloat = 5;
		let w = markerWidth + trackExtension;

		let inP = CGPoint(x: 0, y: barHeight / 2)
		let outP = CGPoint(x: w, y: barHeight / 2)

		return NodeDimension(
			node: self,
			size: CGSize(width: w, height: h),
			inPoint: inP,
			outPoint: outP,
			childDimensions: [],
			childRelativeOffsets: [],
			cornerRadius: style.nodeCornerRadius,
			lineWidth: style.lineWidth,
			arcRadius: style.arcRadius
		);
	}

	func place(dimension: NodeDimension, offset: CGPoint) -> NodePlacement {
		let absIn = CGPoint(x: offset.x + dimension.inPoint.x, y: offset.y + dimension.inPoint.y)
		let absOut = CGPoint(x: offset.x + dimension.outPoint.x, y: offset.y + dimension.outPoint.y)
		return NodePlacement(
			node: self,
			size: dimension.size,
			offset: offset,
			inPoint: absIn,
			outPoint: absOut,
			childPlacements: [],
			cornerRadius: dimension.cornerRadius,
			lineWidth: dimension.lineWidth,
			arcRadius: dimension.arcRadius
		)
	}

	func draw(placement: NodePlacement, canvas: inout GraphicsContext, placeTextField: (UUID, CGRect) -> Void) {
		let lineWidth = placement.lineWidth;
		let h = placement.size.height;
		let midY = h / 2;
		let offset = placement.offset;

		let barThickness: CGFloat = max(1.5, lineWidth);
		let barGap: CGFloat = 2.5;
		let barHeight = h;

		// Two vertical bars near the left, track stub extending right (trailing side)
		let firstBarX = offset.x + 2;
		let secondBarX = firstBarX + barThickness + barGap;
		// Horizontal track extending out the right side
		let trackStartX = firstBarX + barThickness * 0.5;
		let trackEndX = offset.x + placement.size.width;

		var bar = Path();
		bar.move(to: CGPoint(x: firstBarX, y: offset.y + (h - barHeight) / 2));
		bar.addLine(to: CGPoint(x: firstBarX, y: offset.y + (h + barHeight) / 2));
		bar.move(to: CGPoint(x: secondBarX, y: offset.y + (h - barHeight) / 2));
		bar.addLine(to: CGPoint(x: secondBarX, y: offset.y + (h + barHeight) / 2));
		bar.move(to: CGPoint(x: trackStartX, y: offset.y + midY));
		bar.addLine(to: CGPoint(x: trackEndX, y: offset.y + midY));
		canvas.stroke(bar, with: .color(.secondary), lineWidth: lineWidth);
	}

	func updatingLabel(id: UUID, to newLabel: String) -> any Node { self }
	func splittingLabel(id: UUID, at offset: Int) -> any Node { self }
	func insertingAlternative(into choiceID: UUID, at index: Int) -> any Node { self }
	func contains(id: UUID) -> Bool { false }
	func withFocusOn(id: UUID) -> any Node { self }
}

struct StopNode: Node {
	let id = UUID()

	func dimension(style: NodeStyle) -> NodeDimension {
		let barThickness: CGFloat = max(1.5, style.lineWidth);
		let barGap: CGFloat = 2.5;
		let h = max(16.0, style.fontSize * 1.25);
		let barHeight = h;

		let markerWidth = barThickness * 2 + barGap;
		let trackExtension: CGFloat = 5;
		let w = markerWidth + trackExtension;

		let inP = CGPoint(x: 0, y: barHeight / 2);
		let outP = CGPoint(x: w, y: barHeight / 2);

		return NodeDimension(
			node: self,
			size: CGSize(width: w, height: h),
			inPoint: inP,
			outPoint: outP,
			childDimensions: [],
			childRelativeOffsets: [],
			cornerRadius: style.nodeCornerRadius,
			lineWidth: style.lineWidth,
			arcRadius: style.arcRadius,
		);
	}

	func place(dimension: NodeDimension, offset: CGPoint) -> NodePlacement {
		let absIn = CGPoint(x: offset.x + dimension.inPoint.x, y: offset.y + dimension.inPoint.y)
		let absOut = CGPoint(x: offset.x + dimension.outPoint.x, y: offset.y + dimension.outPoint.y)
		return NodePlacement(
			node: self,
			size: dimension.size,
			offset: offset,
			inPoint: absIn,
			outPoint: absOut,
			childPlacements: [],
			cornerRadius: dimension.cornerRadius,
			lineWidth: dimension.lineWidth,
			arcRadius: dimension.arcRadius
		)
	}

	func draw(placement: NodePlacement, canvas: inout GraphicsContext, placeTextField: (UUID, CGRect) -> Void) {
		let lineWidth = placement.lineWidth;
		let h = placement.size.height;
		let midY = h / 2;
		let offset = placement.offset;

		let barThickness: CGFloat = max(1.5, lineWidth);
		let barGap: CGFloat = 2.5;
		let barHeight = h;

		// Two vertical bars near the right, track stub extending in from the left (leading side)
		let secondBarX = offset.x + placement.size.width - 2;
		let firstBarX = secondBarX - barThickness - barGap;
		// Horizontal track coming in from the left to the first bar
		let trackStartX = offset.x;
		let trackEndX = secondBarX - barThickness * 0.5;

		var bar = Path()
		bar.move(to: CGPoint(x: firstBarX, y: offset.y + (h - barHeight) / 2));
		bar.addLine(to: CGPoint(x: firstBarX, y: offset.y + (h + barHeight) / 2));
		bar.move(to: CGPoint(x: secondBarX, y: offset.y + (h - barHeight) / 2));
		bar.addLine(to: CGPoint(x: secondBarX, y: offset.y + (h + barHeight) / 2));
		bar.move(to: CGPoint(x: trackStartX, y: offset.y + midY));
		bar.addLine(to: CGPoint(x: trackEndX, y: offset.y + midY));
		canvas.stroke(bar, with: .color(.secondary), lineWidth: lineWidth)
	}

	func updatingLabel(id: UUID, to newLabel: String) -> any Node { self }
	func splittingLabel(id: UUID, at offset: Int) -> any Node { self }
	func insertingAlternative(into choiceID: UUID, at index: Int) -> any Node { self }
	func contains(id: UUID) -> Bool { false }
	func withFocusOn(id: UUID) -> any Node { self }
}

struct SequenceNode: Node {
	let id = UUID()
	var children: [any Node]
	var placementStrategy: PlacementStrategy

	enum PlacementStrategy {
		case top
		case inToOut
		case topToBottom
	}

	init(children: [any Node], placementStrategy: PlacementStrategy = .topToBottom) {
		self.children = children
		self.placementStrategy = placementStrategy
	}

	static func == (lhs: SequenceNode, rhs: SequenceNode) -> Bool {
		lhs.id == rhs.id
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	func dimension(style: NodeStyle) -> NodeDimension {
		let childDims = children.map { $0.dimension(style: style) }
		guard !childDims.isEmpty else {
			return NodeDimension(
				node: self,
				size: .zero,
				inPoint: .zero,
				outPoint: .zero,
				childDimensions: [],
				childRelativeOffsets: [],
				cornerRadius: style.nodeCornerRadius,
				lineWidth: style.lineWidth,
				arcRadius: style.arcRadius
			)
		}

		var relOffsets: [CGPoint] = []
		var currentX: CGFloat = 0
		var currentPortY: CGFloat = 0
		var minY: CGFloat = .greatestFiniteMagnitude
		var maxY: CGFloat = -.greatestFiniteMagnitude
		var maxRight: CGFloat = 0

		let strategy = style.sequencePlacement
		let hSpacing = style.levelSpacing
		let count = childDims.count
		let maxH = childDims.map(\.size.height).max() ?? 0

		for (index, cdim) in childDims.enumerated() {
			let csize = cdim.size
			let ci = cdim.inPoint
			let co = cdim.outPoint

			let placeY: CGFloat
			if index == 0 {
				placeY = 0
			} else {
				switch strategy {
				case .top:
					placeY = 0
				case .inToOut:
					placeY = currentPortY - ci.y
				case .topToBottom:
					placeY = (count > 1) ? CGFloat(index) * (maxH - csize.height) / CGFloat(count - 1) : 0
				}
			}

			let thisX = currentX
			let thisOffset = CGPoint(x: thisX, y: placeY)
			relOffsets.append(thisOffset)

			let top = placeY
			let bottom = placeY + csize.height
			minY = min(minY, top)
			maxY = max(maxY, bottom)
			maxRight = max(maxRight, thisX + csize.width)

			currentPortY = placeY + co.y
			currentX = thisX + csize.width + hSpacing
		}

		let minTop = relOffsets.map { $0.y }.min() ?? 0
		let normalizedRel = relOffsets.map { CGPoint(x: $0.x, y: $0.y - minTop) }

		let totalWidth = maxRight
		let totalHeight = maxY - minY

		let firstDim = childDims[0]
		let lastDim = childDims.last!
		let firstRel = normalizedRel[0]
		let lastRel = normalizedRel.last!

		let localIn = CGPoint(
			x: firstRel.x + firstDim.inPoint.x,
			y: firstRel.y + firstDim.inPoint.y
		);
		let localOut = CGPoint(
			x: lastRel.x + lastDim.outPoint.x,
			y: lastRel.y + lastDim.outPoint.y
		);

		return NodeDimension(
			node: self,
			size: CGSize(width: totalWidth, height: totalHeight),
			inPoint: localIn,
			outPoint: localOut,
			childDimensions: childDims,
			childRelativeOffsets: normalizedRel,
			cornerRadius: style.nodeCornerRadius,
			lineWidth: style.lineWidth,
			arcRadius: style.arcRadius,
		);
	}

	func place(dimension: NodeDimension, offset: CGPoint) -> NodePlacement {
		let childDims = dimension.childDimensions;
		let rels = dimension.childRelativeOffsets;

		let childPlacements: [NodePlacement] = zip(childDims, rels).map { (cdim, rel) in
			let childOffset = CGPoint(x: offset.x + rel.x, y: offset.y + rel.y);
			return cdim.node.place(dimension: cdim, offset: childOffset);
		}

		let absIn = CGPoint(x: offset.x + dimension.inPoint.x, y: offset.y + dimension.inPoint.y);
		let absOut = CGPoint(x: offset.x + dimension.outPoint.x, y: offset.y + dimension.outPoint.y);

		return NodePlacement(
			node: self,
			size: dimension.size,
			offset: offset,
			inPoint: absIn,
			outPoint: absOut,
			childPlacements: childPlacements,
			cornerRadius: dimension.cornerRadius,
			lineWidth: dimension.lineWidth,
			arcRadius: dimension.arcRadius,
		);
	}

	func draw(placement: NodePlacement, canvas: inout GraphicsContext, placeTextField: (UUID, CGRect) -> Void) {
		for childPlacement in placement.childPlacements {
			childPlacement.node.draw(placement: childPlacement, canvas: &canvas, placeTextField: placeTextField)
		}

		let lineWidth = placement.lineWidth
		for (current, next) in zip(placement.childPlacements, placement.childPlacements.dropFirst()) {
			let start = current.outPoint
			let end = next.inPoint

			var path = Path()
			path.move(to: start)
			path.addQuadCurve(to: .init(x: (start.x + end.x)/2, y: (start.y + end.y)/2), control: .init(x: (start.x + end.x)/2, y: start.y))
			path.addQuadCurve(to: end, control: .init(x: (start.x + end.x)/2, y: end.y))

			canvas.stroke(path, with: .color(.secondary), lineWidth: lineWidth);
		}
	}

	func updatingLabel(id: UUID, to newLabel: String) -> any Node {
		let updatedChildren = children.map { $0.updatingLabel(id: id, to: newLabel) }
		return SequenceNode(children: updatedChildren, placementStrategy: self.placementStrategy)
	}

	func splittingLabel(id: UUID, at offset: Int) -> any Node {
		var changed = false
		var newChildren: [any Node] = []

		for child in children {
			let result = child.splittingLabel(id: id, at: offset)

			if result.id != child.id {
				changed = true
				if let sequence = result as? SequenceNode {
					newChildren.append(contentsOf: sequence.children)
				} else {
					newChildren.append(result)
				}
			} else {
				newChildren.append(child)
			}
		}

		if changed {
			return SequenceNode(children: newChildren, placementStrategy: self.placementStrategy)
		} else {
			return self
		}
	}

	func insertingAlternative(into choiceID: UUID, at index: Int) -> any Node {
		let updatedChildren = children.map { $0.insertingAlternative(into: choiceID, at: index) }
		return SequenceNode(children: updatedChildren, placementStrategy: self.placementStrategy)
	}

	func contains(id: UUID) -> Bool {
		children.contains { $0.contains(id: id) }
	}

	func withFocusOn(id: UUID) -> any Node {
		let updatedChildren = children.map { $0.withFocusOn(id: id) };
		return SequenceNode(children: updatedChildren, placementStrategy: placementStrategy);
	}
}

struct ChoiceNode: Node {
	let id = UUID()
	var children: [any Node]
	let inNode: Int
	let outNode: Int

	init(children: [any Node], inNode: Int = 0, outNode: Int = 0) {
		self.children = children
		let count = children.count
		self.inNode = max(0, min(inNode, count == 0 ? 0 : count - 1))
		self.outNode = max(0, min(outNode, count == 0 ? 0 : count - 1))
	}

	static func == (lhs: ChoiceNode, rhs: ChoiceNode) -> Bool {
		lhs.id == rhs.id
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	func dimension(style: NodeStyle) -> NodeDimension {
		let childDims = children.map { $0.dimension(style: style) }
		guard !childDims.isEmpty else {
			return NodeDimension(
				node: self,
				size: .zero,
				inPoint: .zero,
				outPoint: .zero,
				childDimensions: [],
				childRelativeOffsets: [],
				cornerRadius: style.nodeCornerRadius,
				lineWidth: style.lineWidth,
				arcRadius: style.arcRadius
			)
		}

		let arcR = style.arcRadius
		let horizontalPad = max(arcR * 2, 8)
		let vSpacing = style.verticalSpacing

		var currentY: CGFloat = 0
		var maxChildW: CGFloat = 0
		var relOffsets: [CGPoint] = []

		for cdim in childDims {
			maxChildW = max(maxChildW, cdim.size.width)
			relOffsets.append(CGPoint(x: horizontalPad, y: currentY))
			currentY += cdim.size.height + vSpacing
		}

		let totalHeight = max(0, currentY - vSpacing)
		let overallWidth = horizontalPad + maxChildW + horizontalPad

		let inIndex = min(max(inNode, 0), childDims.count - 1)
		let outIndex = min(max(outNode, 0), childDims.count - 1)

		let inChild = childDims[inIndex]
		let outChild = childDims[outIndex]
		let inRel = relOffsets[inIndex]
		let outRel = relOffsets[outIndex]

		let inY = inRel.y + inChild.inPoint.y
		let outY = outRel.y + outChild.outPoint.y

		let localIn = CGPoint(x: 0, y: inY)
		let localOut = CGPoint(x: overallWidth, y: outY)

		return NodeDimension(
			node: self,
			size: CGSize(width: overallWidth, height: totalHeight),
			inPoint: localIn,
			outPoint: localOut,
			childDimensions: childDims,
			childRelativeOffsets: relOffsets,
			cornerRadius: style.nodeCornerRadius,
			lineWidth: style.lineWidth,
			arcRadius: arcR
		)
	}

	func place(dimension: NodeDimension, offset: CGPoint) -> NodePlacement {
		let childDims = dimension.childDimensions
		let rels = dimension.childRelativeOffsets

		let childPlacements: [NodePlacement] = zip(childDims, rels).map { (cdim, rel) in
			let childOffset = CGPoint(x: offset.x + rel.x, y: offset.y + rel.y)
			return cdim.node.place(dimension: cdim, offset: childOffset)
		}

		let absIn = CGPoint(x: offset.x + dimension.inPoint.x, y: offset.y + dimension.inPoint.y)
		let absOut = CGPoint(x: offset.x + dimension.outPoint.x, y: offset.y + dimension.outPoint.y)

		return NodePlacement(
			node: self,
			size: dimension.size,
			offset: offset,
			inPoint: absIn,
			outPoint: absOut,
			childPlacements: childPlacements,
			cornerRadius: dimension.cornerRadius,
			lineWidth: dimension.lineWidth,
			arcRadius: dimension.arcRadius
		)
	}

	func draw(placement: NodePlacement, canvas: inout GraphicsContext, placeTextField: (UUID, CGRect) -> Void) {
		let lineWidth = placement.lineWidth
		let inX = placement.inPoint.x
		let inY = placement.inPoint.y
		let outX = placement.outPoint.x
		let outY = placement.outPoint.y
		let r = placement.arcRadius

		// Fan-in wires
		for current in placement.childPlacements {
			let childInX = current.inPoint.x
			let childInY = current.inPoint.y

			var path = Path()
			path.move(to: CGPoint(x: inX, y: inY))

			if abs(childInY - inY) > 0.001 {
				if childInY > inY {
					let arcY = childInY - r
					path.addLine(to: CGPoint(x: inX, y: arcY));

					let center = CGPoint(x: inX + r, y: childInY - r)
					path.addArc(
						center: center,
						radius: r,
						startAngle: .degrees(180),
						endAngle: .degrees(90),
						clockwise: true
					)
				} else {
					let arcY = childInY + r
					path.addLine(to: CGPoint(x: inX, y: arcY))

					let center = CGPoint(x: inX + r, y: childInY + r)
					path.addArc(
						center: center,
						radius: r,
						startAngle: .degrees(180),
						endAngle: .degrees(270),
						clockwise: false
					)
				}

				path.addLine(to: CGPoint(x: childInX, y: childInY))
			} else {
				path.addLine(to: CGPoint(x: childInX, y: childInY))
			}

			canvas.stroke(path, with: .color(.secondary), lineWidth: lineWidth);
		}

		// Fan-out wires
		for current in placement.childPlacements {
			let childOutX = current.outPoint.x
			let childOutY = current.outPoint.y

			var path = Path()
			path.move(to: CGPoint(x: childOutX, y: childOutY))

			if abs(childOutY - outY) > 0.001 {
				let arcX = outX - r

				if childOutX < arcX {
					path.addLine(to: CGPoint(x: arcX, y: childOutY))
				}

				if childOutY < outY {
					let center = CGPoint(x: outX - r, y: childOutY + r)
					path.addArc(
						center: center,
						radius: r,
						startAngle: .degrees(270),
						endAngle: .degrees(0),
						clockwise: false
					)
					path.addLine(to: CGPoint(x: outX, y: outY))
				} else {
					let center = CGPoint(x: outX - r, y: childOutY - r)
					path.addArc(
						center: center,
						radius: r,
						startAngle: .degrees(90),
						endAngle: .degrees(0),
						clockwise: true
					)
					path.addLine(to: CGPoint(x: outX, y: outY))
				}
			} else {
				path.addLine(to: CGPoint(x: outX, y: childOutY))
			}
			canvas.stroke(path, with: .color(.secondary), lineWidth: lineWidth);
		}

		// Draw children
		for p in placement.childPlacements {
			p.node.draw(placement: p, canvas: &canvas, placeTextField: placeTextField)
		}
	}

	func updatingLabel(id: UUID, to newLabel: String) -> any Node {
		let updatedChildren = children.map { $0.updatingLabel(id: id, to: newLabel) }
		return ChoiceNode(children: updatedChildren, inNode: self.inNode, outNode: self.outNode)
	}

	func splittingLabel(id: UUID, at offset: Int) -> any Node {
		var changed = false
		var newChildren: [any Node] = []

		for child in children {
			let result = child.splittingLabel(id: id, at: offset)

			if result.id != child.id {
				changed = true
				newChildren.append(result)
			} else {
				newChildren.append(child)
			}
		}

		if changed {
			return ChoiceNode(children: newChildren, inNode: self.inNode, outNode: self.outNode)
		} else {
			return self
		}
	}

	func insertingAlternative(into choiceID: UUID, at index: Int) -> any Node {
		if self.id == choiceID {
			var newChildren = self.children
			let insertIndex = max(0, min(index, newChildren.count))
			newChildren.insert(LabelNode(label: ""), at: insertIndex)

			var newIn = self.inNode
			var newOut = self.outNode
			if insertIndex <= self.inNode { newIn += 1 }
			if insertIndex <= self.outNode { newOut += 1 }

			return ChoiceNode(children: newChildren, inNode: newIn, outNode: newOut)
		}

		let updatedChildren = children.map { $0.insertingAlternative(into: choiceID, at: index) }
		return ChoiceNode(children: updatedChildren, inNode: self.inNode, outNode: self.outNode)
	}

	func contains(id: UUID) -> Bool {
		children.contains { $0.contains(id: id) }
	}

	func withFocusOn(id: UUID) -> any Node {
		let updatedChildren = children.map { $0.withFocusOn(id: id) }
		if let index = updatedChildren.firstIndex(where: { $0.contains(id: id) }) {
			return ChoiceNode(children: updatedChildren, inNode: index, outNode: index);
		} else {
			return ChoiceNode(children: updatedChildren, inNode: inNode, outNode: outNode);
		}
	}
}

struct LoopNode: Node {
	let id = UUID()
	var child: any Node

	static func == (lhs: LoopNode, rhs: LoopNode) -> Bool {
		lhs.id == rhs.id
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	func dimension(style: NodeStyle) -> NodeDimension {
		let childDim = child.dimension(style: style);
		let hpad: CGFloat = style.arcRadius;
		let vpad: CGFloat = style.arcRadius;
		let w = hpad + childDim.size.width + hpad;
		let h = vpad + childDim.size.height;

		let inP = CGPoint(x: 0, y: childDim.inPoint.y + vpad);
		let outP = CGPoint(x: w, y: childDim.outPoint.y + vpad);

		return NodeDimension(
			node: self,
			size: CGSize(width: w, height: h),
			inPoint: inP,
			outPoint: outP,
			childDimensions: [childDim],
			childRelativeOffsets: [CGPoint(x: hpad, y: vpad)],
			cornerRadius: style.nodeCornerRadius,
			lineWidth: style.lineWidth,
			arcRadius: style.arcRadius,
		);
	}

	func place(dimension: NodeDimension, offset: CGPoint) -> NodePlacement {
		let childDim = dimension.childDimensions[0]
		let rel = dimension.childRelativeOffsets[0]
		let childOffset = CGPoint(x: offset.x + rel.x, y: offset.y + rel.y)
		let childPlacement = childDim.node.place(dimension: childDim, offset: childOffset)

		let absIn = CGPoint(x: offset.x + dimension.inPoint.x, y: offset.y + dimension.inPoint.y)
		let absOut = CGPoint(x: offset.x + dimension.outPoint.x, y: offset.y + dimension.outPoint.y)

		return NodePlacement(
			node: self,
			size: dimension.size,
			offset: offset,
			inPoint: absIn,
			outPoint: absOut,
			childPlacements: [childPlacement],
			cornerRadius: dimension.cornerRadius,
			lineWidth: dimension.lineWidth,
			arcRadius: dimension.arcRadius,
		)
	}

	func draw(placement: NodePlacement, canvas: inout GraphicsContext, placeTextField: (UUID, CGRect) -> Void) {
		// Draw the looping track first, above the node
		let lineWidth = placement.lineWidth;
		let r = placement.arcRadius;
		let childP = placement.childPlacements[0];
		let childOut = childP.outPoint;
		let childIn = childP.inPoint;
		let nodeTop: CGFloat = childP.offset.y;
		var loop = Path();
		loop.addArc(
			center: CGPoint(x: childOut.x, y: childOut.y - r),
			radius: r,
			startAngle: .degrees(90),
			endAngle: .degrees(360),
			clockwise: true,
		);
		// FIXME: If the arc radius size is set very high, this arc will overlap with the previous one
		loop.addArc(
			center: CGPoint(x: childOut.x, y: nodeTop),
			radius: r,
			startAngle: .degrees(360),
			endAngle: .degrees(270),
			clockwise: true,
		);
		loop.addArc(
			center: CGPoint(x: childIn.x, y: nodeTop),
			radius: r,
			startAngle: .degrees(270),
			endAngle: .degrees(180),
			clockwise: true,
		);
		loop.addArc(
			center: CGPoint(x: childIn.x, y: childIn.y - r),
			radius: r,
			startAngle: .degrees(180),
			endAngle: .degrees(90),
			clockwise: true,
		);
		loop.move(to: placement.inPoint);
		loop.addLine(to: childIn);
		loop.move(to: childOut);
		loop.addLine(to: placement.outPoint);

		canvas.stroke(loop, with: .color(.secondary), lineWidth: lineWidth);

		// Draw child on top
		childP.node.draw(placement: childP, canvas: &canvas, placeTextField: placeTextField)
	}

	func updatingLabel(id: UUID, to newLabel: String) -> any Node {
		var copy = self
		copy.child = child.updatingLabel(id: id, to: newLabel)
		return copy
	}

	func splittingLabel(id: UUID, at offset: Int) -> any Node {
		var copy = self
		copy.child = child.splittingLabel(id: id, at: offset)
		return copy
	}

	func insertingAlternative(into choiceID: UUID, at index: Int) -> any Node {
		var copy = self
		copy.child = child.insertingAlternative(into: choiceID, at: index)
		return copy
	}

	func contains(id: UUID) -> Bool {
		child.contains(id: id)
	}

	func withFocusOn(id: UUID) -> any Node {
		var copy = self
		copy.child = child.withFocusOn(id: id)
		return copy
	}
}


// MARK: - Custom editable label for Command-. support
class CommandDotTextField: NSTextField {
	var onCommandDot: ((Int) -> Void)?
	var onFocus: (() -> Void)?

	override func performKeyEquivalent(with event: NSEvent) -> Bool {
		if event.modifierFlags.contains(.command),
			event.charactersIgnoringModifiers == "." {
			if let editor = self.currentEditor() as? NSTextView {
				let offset = editor.selectedRange().location
				onCommandDot?(offset)
				return true
			}
		}
		return super.performKeyEquivalent(with: event)
	}

	override func becomeFirstResponder() -> Bool {
		let success = super.becomeFirstResponder()
		if success { onFocus?() }
		return success;
	}
}

struct LabelTextField: NSViewRepresentable {
	@Binding var text: String
	let onSplitRequested: (Int) -> Void
	let fontSize: CGFloat
	let onFocus: () -> Void

	func makeNSView(context: Context) -> CommandDotTextField {
		let textField = CommandDotTextField()
		textField.isBordered = false
		textField.drawsBackground = false
		textField.focusRingType = .none
		textField.textColor = NSColor.labelColor
		textField.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
		textField.delegate = context.coordinator

		// Prevent wrapping and allow slight overflow / truncation instead of line breaks
		textField.cell?.wraps = false
		textField.lineBreakMode = .byClipping
		textField.maximumNumberOfLines = 1
		textField.cell?.truncatesLastVisibleLine = false

		textField.onCommandDot = { offset in
			DispatchQueue.main.async {
				context.coordinator.onSplitRequested(offset)
			}
		}
		textField.onFocus = onFocus;

		return textField;
	}

	func updateNSView(_ nsView: CommandDotTextField, context: Context) {
		nsView.onCommandDot = { offset in
			DispatchQueue.main.async {
				context.coordinator.onSplitRequested(offset)
			}
		}
		nsView.onFocus = onFocus

		if nsView.font?.pointSize != fontSize {
			nsView.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
		}

		// Re-enforce single-line behavior on updates
		nsView.cell?.wraps = false
		nsView.lineBreakMode = .byClipping
		nsView.maximumNumberOfLines = 1

		if nsView.stringValue != text {
			nsView.stringValue = text
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(text: $text, onSplitRequested: onSplitRequested)
	}

	class Coordinator: NSObject, NSTextFieldDelegate {
		@Binding var text: String
		var onSplitRequested: (Int) -> Void

		init(text: Binding<String>, onSplitRequested: @escaping (Int) -> Void) {
			self._text = text
			self.onSplitRequested = onSplitRequested
		}

		func controlTextDidChange(_ obj: Notification) {
			guard let tf = obj.object as? NSTextField else { return }
			if text != tf.stringValue {
				text = tf.stringValue
			}
		}
	}
}

// MARK: Diagram View
struct DiagramView: View {
	@Binding var root: any Node
	@State private var labelMap: [UUID: LabelInfo] = [:]
	@State private var hoveredChoiceID: UUID?

	// MARK: Tunable parameters
	var levelSpacing: CGFloat = 10
	var verticalSpacing: CGFloat = 10
	var fontSize: CGFloat = 12
	var nodePadding: CGFloat = 4
	var lineWidth: CGFloat = 1
	var nodeCornerRadius: CGFloat = 4
	var arcRadius: CGFloat = 4
	var sequencePlacement: SequenceNode.PlacementStrategy = .inToOut

	var body: some View {
		let style = NodeStyle(
			levelSpacing: levelSpacing,
			verticalSpacing: verticalSpacing,
			fontSize: fontSize,
			nodePadding: nodePadding,
			lineWidth: lineWidth,
			nodeCornerRadius: nodeCornerRadius,
			sequencePlacement: sequencePlacement,
			arcRadius: arcRadius,
		);
		let dim = root.dimension(style: style);
		let placement = root.place(dimension: dim, offset: .zero);
		let contentWidth = max(300, dim.size.width + 200);
		let contentHeight = max(200, dim.size.height + 100);

		ZStack(alignment: .topLeading) {
			Canvas { context, _ in
				context.translateBy(x: 50, y: 50);
				context.blendMode = .copy;
				var freshLabels: [UUID: LabelInfo] = [:];
				var labelRectMap: [UUID: CGRect] = [:];

				root.draw(
					placement: placement,
					canvas: &context,
					placeTextField: { id, rect in labelRectMap[id] = rect },
				);

				// Labels still use the text collector (for snapshot strings) but rects come from the callback
				let baseLabels = Self.collectLabelInfos(from: placement)
				for (id, info) in baseLabels {
					if let rect = labelRectMap[id] {
						freshLabels[id] = LabelInfo(
							id: id,
							origin: rect.origin,
							text: info.text,
							size: rect.size
						)
					} else {
						freshLabels[id] = info
					}
				}
				DispatchQueue.main.async {
					labelMap = freshLabels
				}
			}
			.frame(width: contentWidth, height: contentHeight)

			ForEach(Array(labelMap.values), id: \.id) { info in
				LabelTextField(
					text: labelBinding(id: info.id, snapshot: info.text),
					onSplitRequested: { cursorOffset in
						splitLabel(id: info.id, at: cursorOffset)
					},
					fontSize: fontSize,
					onFocus: { root = root.withFocusOn(id: info.id) },
				)
				.offset(x: 54 + info.origin.x, y: 50 + info.origin.y)
				.frame(width: info.size.width, height: info.size.height)
				.background(
					RoundedRectangle(cornerRadius: 4)
						.stroke(Color.accentColor, lineWidth: lineWidth)
						.background(Color.accentColor.opacity(0.1))
						.offset(x: 50 + info.origin.x, y: 50 + info.origin.y)
				)
			}
		}
	}

	private static func collectLabelInfos(from placement: NodePlacement) -> [UUID: LabelInfo] {
		var result: [UUID: LabelInfo] = [:]
		func visit(_ p: NodePlacement) {
			if let labelNode = p.node as? LabelNode {
				result[labelNode.id] = LabelInfo(
					id: labelNode.id,
					origin: p.offset,
					text: labelNode.label,
					size: p.size,
				);
			}
			for child in p.childPlacements {
				visit(child);
			}
		}
		visit(placement);
		return result;
	}

	// MARK: Editing Helpers

	private func labelBinding(id: UUID, snapshot: String) -> Binding<String> {
		Binding(
			get: { snapshot },
			set: { root = root.updatingLabel(id: id, to: $0) }
		)
	}

	private func splitLabel(id: UUID, at offset: Int) {
		root = root.splittingLabel(id: id, at: offset)
	}

	private func insertAlternative(into choiceID: UUID, at index: Int) {
		root = root.insertingAlternative(into: choiceID, at: index)
	}
}

// MARK: RailroadNode → diagram conversion

private func makeNode(from railroad: RailroadNode) -> any Node {
	switch railroad {
	case .Diagram(let start, let sequence, let end, _):
		let kids = ([start] + sequence + [end]).map(makeNode)
		return SequenceNode(children: kids)

	case .Sequence(let items, _):
		return SequenceNode(children: items.map(makeNode))

	case .Choice(let items, _),
			.HorizontalChoice(let items, _),
			.MultipleChoice(_, let items, _):
		let kids = items.map(makeNode)
		return ChoiceNode(children: kids)

	case .Loop(let item, _, _, _):
		return LoopNode(child: makeNode(from: item))

	case .Optional(let item, _):
		// Optional = choice between skip and the item
		return ChoiceNode(children: [LabelNode(label: ""), makeNode(from: item)])

	case .ZeroOrMore(let item, _, _):
		let loop = LoopNode(child: makeNode(from: item))
		return ChoiceNode(children: [LabelNode(label: ""), loop])

	case .Start(_, _):
		return StartNode()

	case .End(_, _):
		return StopNode()

	case .Terminal(let text, _):
		return LabelNode(label: text)

	case .NonTerminal(let text, _):
		return LabelNode(label: text)

	case .Group(let item, _, _):
		return makeNode(from: item)

	case .Comment(let text, _):
		return LabelNode(label: text)

	case .Skip(_):
		return LabelNode(label: "")

	case .OptionalSequence(let items, _):
		let seq = SequenceNode(children: items.map(makeNode))
		return ChoiceNode(children: [LabelNode(label: ""), seq])

	case .AlternatingSequence(let items, _), .Stack(let items, _):
		if items.isEmpty { return LabelNode(label: "") }
		if items.count == 1 { return makeNode(from: items[0]) }
		return ChoiceNode(children: items.map(makeNode))
	}
}

extension RailroadNode {
	/// Returns a SwiftUI view that renders this railroad diagram using the local DiagramView/Canvas renderer.
	public var view: some View {
		let local = makeNode(from: self);
		return DiagramViewFrom(root: local);
	}
}

// TODO: Make this a two-way conversion between the RR node and the diagram node (just strip out diagram state or add a default as needed)
struct DiagramViewFrom: View {
	@State var root: any Node;
	init(root: any Node) {
		self.root = root
	}
	var body: some View {
		DiagramView(root: $root);
	}
}

// MARK: Preview
#Preview {
	@Previewable @State var root: any Node = SequenceNode(children: [
		StartNode(),
		LabelNode(label: "A"),
		StopNode(),
		StartNode(),
		ChoiceNode(children: [
			LoopNode(child: LabelNode(label: "B")),
			SequenceNode(children: [
				LabelNode(label: "A"),
				ChoiceNode(children: [
					LabelNode(label: "B"),
					LabelNode(label: "C"),
				], inNode: 1, outNode: 1),
				LabelNode(label: "D"),
			]),
		], inNode: 1, outNode: 1),
		LabelNode(label: "D"),
		StopNode(),
	]);
	DiagramView(root: $root).fixedSize();
}
