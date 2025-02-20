
// Swift doesn't appear to have any way to get an empty sequence of type T where T: Sequence
// This implements that.
protocol EmptyInitial {
	associatedtype Element;
	// An instance of this type that has no elements
	static var empty: Self { get }
	func appendElement(_ newElement: Element) -> Self;
}

extension Array: EmptyInitial {
	static var empty: Self {
		return [];
	}
	func appendElement(_ newElement: Element) -> Self {
		return self + [newElement];
	}
}

extension Set: EmptyInitial {
	static var empty: Self {
		return [];
	}
	func appendElement(_ newElement: Element) -> Self {
		return self.union([newElement]);
	}
}

extension String: EmptyInitial {
	static var empty: Self {
		return "";
	}
	func appendElement(_ newElement: Element) -> Self {
		return self + String(newElement);
	}
}

// For some reason an Array isn't comparable when its elements are
// Add suitable lexiocographic sorting support so that we can use Arrays of symbols as input e.g. Array<UInt32>
extension Array: Comparable where Element: Comparable {
	public static func < (lhs: Array<Element>, rhs: Array<Element>) -> Bool {
		for (l, r) in zip(lhs, rhs) {
			if l != r {
				return l < r
			}
		}
		return lhs.count < rhs.count
	}
}

extension Character: Strideable {
	public func distance(to: Character) -> Int {
		return Int(to.unicodeScalars.first!.value - self.unicodeScalars.first!.value);
	}
	public func advanced(by n: Int) -> Character {
		return Character(UnicodeScalar(Int(self.asciiValue!) + n)!)
	}
}
