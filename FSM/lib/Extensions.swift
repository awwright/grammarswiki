extension Array: SymbolSequenceProtocol where Array.Element: Hashable {
	public static var empty: Self {
		return [];
	}
	public func appending(_ newElement: Element) -> Self {
		return self + [newElement];
	}
}

extension String: SymbolSequenceProtocol {
	public static var empty: Self {
		return "";
	}
	public func appending(_ newElement: Element) -> Self {
		return self + String(newElement);
	}
}

// For some reason an Array isn't comparable when its elements are
// Add suitable lexiocographic sorting support so that we can use Arrays of symbols as input e.g. Array<UInt32>
extension Array: @retroactive Comparable where Element: Comparable {
	public static func < (lhs: Array<Element>, rhs: Array<Element>) -> Bool {
		for (l, r) in zip(lhs, rhs) {
			if l != r {
				return l < r
			}
		}
		return lhs.count < rhs.count
	}
}

extension Bool: @retroactive Comparable {
	public static func < (lhs: Bool, rhs: Bool) -> Bool {
		return lhs && !rhs;
	}
}

// Add lexicographic comparison to ClosedRange
// This extension is a hack so that ClosedRangeAlphabet can produce a DFA.Iterator.
extension ClosedRange: @retroactive Comparable {
	public static func < (lhs: ClosedRange, rhs: ClosedRange) -> Bool {
		return (lhs.lowerBound < rhs.lowerBound) || (lhs.lowerBound == rhs.lowerBound && lhs.upperBound < rhs.upperBound)
	}
}

// This is going to explode one day I just know it
extension Character: @retroactive Strideable {
	public func distance(to: Character) -> Int {
		return Int(to.unicodeScalars.first!.value - self.unicodeScalars.first!.value);
	}
	public func advanced(by n: Int) -> Character {
		return Character(UnicodeScalar(Int(self.asciiValue!) + n)!)
	}
}
