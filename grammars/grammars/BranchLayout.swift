import SwiftUI

/// A custom `Layout` that arranges its children as follows:
/// - The **first child** is placed on the top line.
/// - It is given a width equal to the *ideal* (natural) width of all remaining children laid out horizontally.
/// - All remaining children are placed side-by-side on the second line (left-aligned).
///
/// The layout respects the parent's `ProposedViewSize` when a finite width is given,
/// but falls back to the natural width of the second line when the proposal is unspecified
/// or `.infinity`.
///
/// Spacing between children on the second line and between the two lines is configurable, potentially.
struct Branch: Layout {
	var horizontalSpacing: CGFloat = 12;
	var verticalSpacing: CGFloat = 6;

	func sizeThatFits(
		proposal: ProposedViewSize,
		subviews: Subviews,
		cache: inout ()
	) -> CGSize {
		guard !subviews.isEmpty else { return .zero }
		let trunk = subviews.first!;
		let branches = subviews.dropFirst();
		guard !branches.isEmpty else { return trunk.sizeThatFits(.unspecified) }
		let trunkSize = trunk.sizeThatFits(.unspecified);

		var width: CGFloat = 0;
		var height: CGFloat = 0;
		for branch in branches {
			let size = branch.sizeThatFits(.unspecified);
			width += size.width + horizontalSpacing;
			if size.height > height { height = size.height }
		}

		return CGSize(
			// Use greater of the two widths
			// Remove the horizontal spacing associated with the last branch
			// (There is guaranteed at least one at this point)
			width: max(trunkSize.width, width - horizontalSpacing),
			height: trunkSize.height + verticalSpacing + height,
		);
	}

	func placeSubviews(
		in bounds: CGRect,
		proposal: ProposedViewSize,
		subviews: Subviews,
		cache: inout ()
	) {
		guard !subviews.isEmpty else { return }
		let trunk = subviews.first!;
		let branches = subviews.dropFirst();
		let trunkSize = trunk.sizeThatFits(.unspecified);

		guard !branches.isEmpty else { return }
		var x = bounds.minX;
		let y = bounds.minY + trunkSize.height + verticalSpacing;

		for branch in branches {
			let size = branch.sizeThatFits(.unspecified);
			branch.place(
				at: CGPoint(x: x, y: y),
				proposal: ProposedViewSize(size),
			);
			x += size.width + horizontalSpacing;
		}

		trunk.place(
			at: CGPoint(x: bounds.minX, y: bounds.minY),
			proposal: ProposedViewSize(
				// Use greater of the two widths
				width: max(trunkSize.width, x - bounds.minX - horizontalSpacing),
				height: trunkSize.height,
			),
		);
	}
}

struct BranchLabel: View {
	let text: String;
	public init(_ text: String) {
		self.text = text
	}
	var body: some View {
		Text(text).frame(maxWidth: .infinity)
			.background(Color.orange.opacity(0.3))
			.border(Color.orange)
	}
}

struct BranchTerminal: View {
	let text: String;
	public init(_ text: String) {
		self.text = text
	}
	var body: some View {
		Text(text)
	}
}

#Preview {	VStack {
	// Note how when there's no branches from the trunk, the layout may expand to fill the space.
	// This is a side effect of how sizeThatFits exits early, and may be fixed later.
	Text("Empty").font(.headline)
	Branch {
		BranchLabel("empty")
	}
	Divider()

	// Note how the leaves may be smaller than the trunk
	Text("Single").font(.headline)
	Branch {
		BranchLabel("a-long-local-part")
		Branch {
			BranchLabel("dot-atom")
			BranchTerminal("abc")
		}
	}
	Divider()

	// But never a trunk smaller than the leaves
	Text("Single long leaf").font(.headline)
	Branch {
		BranchLabel("single")
		BranchTerminal("a single very long leaf")
	}
	Divider()

	Text("Double leaf").font(.headline)
	Branch {
		BranchLabel("double")
		BranchTerminal("leaf")
		BranchTerminal("long-leaf")
	}
	Divider()

	Text("Parse Tree").font(.headline)
	Branch {
		BranchLabel("addr-spec")
		Branch {
			BranchLabel("local-part")
			Branch {
				BranchLabel("dot-atom")
				BranchTerminal("abc")
			}
		}
		Text("@")
		Branch {
			BranchLabel("domain")
			Branch {
				BranchLabel("dot-atom")
				BranchTerminal("example.com").monospaced()
			}
		}
	}
	Divider()

	Text("Alphabet").font(.headline)
	Branch {
		BranchLabel("addr-spec")
		Branch {
			BranchLabel("domain")
			Branch {
				BranchLabel("dot-atom")
				BranchTerminal("a⋯z")
				BranchTerminal("A⋯Z")
				BranchTerminal("0⋯9")
				BranchTerminal("!")
				BranchTerminal("#")
				BranchTerminal("$")
				BranchTerminal("%")
				BranchTerminal("&")
				BranchTerminal("'")
				BranchTerminal("*")
				BranchTerminal("+")
				BranchTerminal("-")
				BranchTerminal("/")
				BranchTerminal("=")
				BranchTerminal("?")
				BranchTerminal("^")
				BranchTerminal("_")
				BranchTerminal("`")
				BranchTerminal("{")
				BranchTerminal("|")
				BranchTerminal("}")
				BranchTerminal("~")
			}
		}
	}
	Divider()
}.fixedSize().padding() }

