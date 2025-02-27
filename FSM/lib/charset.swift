public struct ComputedCollection<T>: Collection {
	// Type of elements (can be anything)
	public typealias Element = T // Example: Change to your desired type

	// Index type (Int for array-like behavior)
	public typealias Index = Int

	// Fixed number of elements
	private let size: Int

	// Closure to compute elements dynamically
	private let computeElement: (Int) -> Element

	init(size: Int, computeElement: @escaping (Int) -> Element) {
		assert(size >= 0, "Size must be non-negative")
		self.size = size
		self.computeElement = computeElement
	}

	// Collection requirements
	public var startIndex: Index {
		return 0
	}

	public var endIndex: Index {
		return size
	}

	public func index(after i: Index) -> Index {
		return i + 1 // Linear progression
	}

	public subscript(index: Index) -> Element {
		assert(index >= 0 && index < size, "Index out of bounds")
		return computeElement(index) // Compute on demand
	}
}

// This specifies equivalences between the different Unicode encodings
public struct UnicodeCharsets {
	/// Providing the code point as a UInt
	public static let LiteralUInt = ComputedCollection<UInt?>(size: 0x10FFFF, computeElement: { UInt($0)	})

	/// Providing the code point as an Int
	public static let LiteralInt = ComputedCollection<Int?>(size: 0x10FFFF, computeElement: { Int($0)	})

	/// Provide the requested code point as a UInt32
	// TODO: This should probably exclude UTF_16 surrogate codepoints
	public static let UTF32 = ComputedCollection<[UInt32]?>(size: 0x10FFFF, computeElement: { [UInt32($0)]	})

	/// Provide the code point as UTF-16 sequence, using surrogate pairs as necessary
	public static let UTF16 = ComputedCollection<[UInt16]?>(size: 0x10FFFF, computeElement: {
		i in
		if i < 0xD800 {
			return [UInt16(i)];
		} else if (i >= 0x010000){
			let shifted = i - 0x010000
			return [UInt16(0xD800 | (shifted >> 10)), UInt16(0xDC00 | (shifted & 0x3FF))]
		}
		return nil;
	})

	/// Provide the code point as UTF-8 sequence
	// TODO: Maybe also provide a variation that includes "long" UTF-8 sequences (sequences encoded with more bytes than necessary)
	public static let ASCII = ComputedCollection<[UInt8]?>(size: 0x7F, computeElement: {
		i in
		return [UInt8(i)];
	})

	/// Provide the code point as UTF-8 sequence
	// TODO: Maybe also provide a variation that includes "long" UTF-8 sequences (sequences encoded with more bytes than necessary)
	public static let UTF8 = ComputedCollection<[UInt8]?>(size: 0x10FFFF, computeElement: {
		i in
		if i < 0x80 {
			return [UInt8(i)];
		} else if (i < 0x0800){
			return [UInt8(0xb11000000 | (i >> 10)), UInt8(0xDC00 | (i & 0x3FF))]
		} else if (i < 0x010000){
			return [UInt8(0xC0 | (i >> 6)), UInt8(0x80 | (i & 0x3F))];
		} else if (i <= 0x10FFFF) {
			return [UInt8(0xE0 | (i >> 12)), UInt8(0x80 | ((i >> 6) & 0x3F)), UInt8(0x80 | (i & 0x3F))];
		}
		return nil;
	})

	/// Returns a DFA matching all the equivalent JSON encodings of the Unicode code point
	public static let JSONStrings = ComputedCollection<DFA<Array<UInt32>>>(size: 0x10FFFF, computeElement: {
		i in
		let hexMapping: Array<Array<Array<UInt32>>> = [
			[[0x30]], [[0x31]], [[0x32]], [[0x33]], [[0x34]], [[0x35]], [[0x36]], [[0x37]], [[0x38]], [[0x39]],
			[[0x41], [0x61]], [[0x42], [0x62]], [[0x43], [0x63]], [[0x44], [0x64]], [[0x45], [0x65]], [[0x46], [0x66]]
		];
		var strings = DFA<Array<UInt32>>.concatenate([
			DFA([[UInt32(0x5C), UInt32(0x75)]]),
			DFA(hexMapping[(i >> 12) & 0xf]),
			DFA(hexMapping[(i >> 8) & 0xf]),
			DFA(hexMapping[(i >> 4) & 0xf]),
			DFA(hexMapping[(i >> 0) & 0xf]),
		]);

		// unescaped = %x20-21 / %x23-5B / %x5D-FF
		if(i == 0x20 || i == 0x20 || i >= 0x23 && i <= 0x5B || i >= 0x5D && i <= 0x10FFFF){
			strings.formUnion(DFA([[UInt32(i)]]));
		}

		// %x5C CHAR
		switch(i){
			case 0x22: strings.formUnion(DFA([[0x5C, 0x22]])); // "    quotation mark
			case 0x5C: strings.formUnion(DFA([[0x5C, 0x5C]])); // \    reverse solidus
			case 0x2F: strings.formUnion(DFA([[0x5C, 0x2F]])); // /    solidus
			case 0x08: strings.formUnion(DFA([[0x5C, 0x62]])); // b    backspace
			case 0x0C: strings.formUnion(DFA([[0x5C, 0x66]])); // f    form feed
			case 0x0A: strings.formUnion(DFA([[0x5C, 0x6E]])); // n    line feed
			case 0x0D: strings.formUnion(DFA([[0x5C, 0x72]])); // r    carriage return
			case 0x09: strings.formUnion(DFA([[0x5C, 0x74]])); // t    tab
			default: break;
		}

		return strings;
	})

	/// Returns the shortest possible representation of the given codepoint considering the different ways to escape
	public static let JSONStringCanonical = ComputedCollection<Array<UInt32>?>(size: 0x10FFFF, computeElement: {
		i in

		assert(i <= 0x10FFFF);

		// Literal representation is the best
		if(i == 0x20 || i == 0x20 || i >= 0x23 && i <= 0x5B || i >= 0x5D && i <= 0x10FFFF){
			return ([UInt32(i)]);
		}

		// Single-character backslash escape is the second-best
		// %x5C CHAR
		switch(i){
			case 0x22: return [0x5C, 0x22]; // "    quotation mark
			case 0x5C: return [0x5C, 0x5C]; // \    reverse solidus
			case 0x2F: return [0x5C, 0x2F]; // /    solidus
			case 0x08: return [0x5C, 0x62]; // b    backspace
			case 0x0C: return [0x5C, 0x66]; // f    form feed
			case 0x0A: return [0x5C, 0x6E]; // n    line feed
			case 0x0D: return [0x5C, 0x72]; // r    carriage return
			case 0x09: return [0x5C, 0x74]; // t    tab
			default: break;
		}

		// Otherwise, unicode-escaped
		let hexMapping: Array<UInt32> = [
			0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
			0x61, 0x62, 0x63, 0x64, 0x65, 0x66
		];
		return [(0x5C), (0x75), hexMapping[(i >> 12) & 0xf], hexMapping[(i >> 8) & 0xf], hexMapping[(i >> 4) & 0xf], hexMapping[(i >> 0) & 0xf]];
	})

	// TODO: URL encoding
}
