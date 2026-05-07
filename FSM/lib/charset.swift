/// Declare an equivalency between two sets of strings
///
/// There are two rules that the `tr` and `inv` functions must implement:
/// - tr(x) == tr(inv(tr(x))) (tr.inv is idempotent)
/// - tr(x) + tr(y) = tr(x + y) (tr is distributive; strings can be concatenated together)
public struct ComputedHomomorphism<Symbol: Hashable> {
	public let source: String
	public let target: String
	public let tr: (Array<Symbol>) -> Array<Symbol>?
	public let inv: (Array<Symbol>) -> Array<Symbol>?

	public var inverse: ComputedHomomorphism<Symbol> {
		.init(source: target, target: source, forward: inv, backward: tr)
	}

	// Private init so only the factory can create properly linked pairs
	public init(
		source: String,
		target: String,
		forward: @escaping (Array<Symbol>) -> Array<Symbol>?,
		backward: @escaping (Array<Symbol>) -> Array<Symbol>?,
	) {
		self.source = source
		self.target = target
		self.tr = forward
		self.inv = backward
	}

	/// Normalize an input (translate a string then invert it again)
	public func norm(_ string: Array<Symbol>) -> Array<Symbol>? {
		guard let there = tr(string) else { return nil }
		// Briefly check that the normalization of the inverse is idempotent
		guard let colder = tr(there) else { return nil }
		guard let warmer = inv(colder) else { return nil }
		assert(there == warmer);
		return inv(there);
	}

	/// Compose two homomorphisms together
	public static func compose(_ list: Array<Self>) -> ComputedHomomorphism {
		let start = list.first!.source;
		let end = list.last!.target;
		let tr: (Array<Symbol>) -> Array<Symbol>? = {
			var value: Array<Symbol>? = $0;
			for f in list {
				guard let v = value else { return nil; }
				value = f.tr(v);
			}
			return value;
		};
		let reverse = list.reversed();
		let inv: (Array<Symbol>) -> Array<Symbol>? = {
			var value: Array<Symbol>? = $0;
			for f in reverse {
				guard let v = value else { return nil; }
				value = f.inv(v);
			}
			return value;
		};
		return ComputedHomomorphism(source: start, target: end, forward: tr, backward: inv);
	}
}

/// Stores any number of homomorphisms and finds a path between any two
public struct HomomorphismGraph<Symbol: Hashable> {
	var edges: [String: [String: ComputedHomomorphism<Symbol>]] = [:]

	public var nodes: Set<String> { Set(edges.keys) }

	public init(_ edgesSet: some Collection<ComputedHomomorphism<Symbol>>) {
		for edge in edgesSet { insert(edge); }
	}

	mutating public func insert(_ edge: ComputedHomomorphism<Symbol>) {
		self.edges[edge.source, default: [:]][edge.target] = edge;
		self.edges[edge.target, default: [:]][edge.source] = edge.inverse;
	}

	/// Compute a homomorphism that goes from ``source`` to ``target``, taking up to one intermediate step if necessary
	/// (which is generally always going to be UTF-32)
	public func find(source: String, target: String) -> ComputedHomomorphism<Symbol>? {
		if let edge = edges[source]?[target] {
			return edge;
		}
		let sourceIntermediate = Set(edges[source, default: [:]].keys);
		let targetIntermediate = Set(edges[target, default: [:]].keys);
		let shared = sourceIntermediate.intersection(targetIntermediate).sorted().first;
		guard let shared else { return nil; }
		return ComputedHomomorphism<Symbol>.compose([
			edges[source]![shared]!,
			edges[shared]![target]!,
		]);
	}
}

extension HomomorphismGraph where Symbol: BinaryInteger {
	public static var builtin: Self { .init([
		.init(source: "UTF-32", target: "UTF-8", forward: { string in
			return string.flatMap { i in
				if i < 0x80 { return [i]; }
				else if i < 0x800 { return [0xC0 | (i >> 6), 0x80 | (i & 0x3F)]; }
				else if i < 0x10000 { return [0xE0 | (i >> 12), 0x80 | ((i >> 6) & 0x3F), 0x80 | (i & 0x3F)]; }
				else if i <= 0x10FFFF { return [0xF0 | (i >> 18), 0x80 | ((i >> 12) & 0x3F), 0x80 | ((i >> 6) & 0x3F), 0x80 | (i & 0x3F)]; }
				fatalError("Didn't catch \(i)");
			}
		}, backward: { string in
			var res: Array<Symbol> = [];
			var i = 0;
			while i < string.count {
				let b0: Symbol = string[i];
				if b0 < 0x80 { res.append(b0); i += 1; }
				else if b0 >= 0xF0 {
					guard i + 3 < string.count else { return nil; }
					let code: Symbol = (b0 & 0x07) << 18 | (string[i + 1] & 0x3F) << 12 | (string[i + 2] & 0x3F) << 6 | (string[i + 3] & 0x3F);
					res.append(code);
					i += 4;
				}
				else if b0 >= 0xE0 {
					guard i + 2 < string.count else { return nil; }
					let code: Symbol = (b0 & 0x0F) << 12 | (string[i + 1] & 0x3F) << 6 | (string[i + 2] & 0x3F);
					res.append(code);
					i += 3;
				}
				else if b0 >= 0xC0 {
					guard i + 1 < string.count else { return nil; }
					let code: Symbol = (b0 & 0x1F) << 6 | (string[i + 1] & 0x3F);
					res.append(code);
					i += 2;
				}
				else { return nil; } // Invalid UTF-8 sequence
			}
			return res;
		}),
		.init(source: "UTF-8", target: "UTF-8-hex", forward: { string in
			return string.flatMap { i in
				let i0 = i >> 4;
				let i1 = i & 0xF;
				return [i0, i1].map{ $0 + ($0 >= 10 ? 0x37 : 0x30) };
			}
		}, backward: { string in
			var res: Array<Symbol> = [];
			func hexDigitValue(_ codePoint: Symbol) -> Symbol? {
				switch codePoint {
					case 0x30...0x39: (codePoint - 0x30); // '0' - '9'
					case 0x41...0x46: (codePoint - 0x41 + 10);  // 'A' - 'F'
					case 0x61...0x66: (codePoint - 0x61 + 10);  // 'a' - 'f'
					default: nil;
				}
			}
			guard string.count % 2 == 0 else { return nil; }
			res.reserveCapacity(string.count / 2);
			for i in stride(from: 0, to: string.count, by: 2) {
				guard let high = hexDigitValue(string[i]), let low = hexDigitValue(string[i + 1]) else { return nil; };
				let byteValue = (high << 4) | low;
				res.append(byteValue);
			}
			return res;
		}),
		.init(source: "UTF-32", target: "UTF-16", forward: { string in
			return string.flatMap { i in
				if i < 0x010000 { return [i]; }
				else { let shifted = i - 0x010000; return [(0xD800 | (shifted >> 10)), (0xDC00 | (shifted & 0x3FF))]; }
			}
		}, backward: { string in
			var res: Array<Symbol> = [];
			var i = 0;
			while i < string.count {
				let b0 = string[i];
				if b0 >= 0xD800 && b0 <= 0xDFFF {
					// High surrogate: must be followed by a low surrogate
					if b0 >= 0xDC00 { return nil; }  // Lone low surrogate is invalid
					guard i + 1 < string.count else { return nil; }  // Bounds check
					let b1 = string[i + 1];
					if b1 < 0xDC00 || b1 > 0xDFFF { return nil; }  // Invalid low surrogate
					let code = 0x10000 + ((b0 & 0x03FF) << 10) | (b1 & 0x3FF);
					res.append(code);
					i += 2;  // Skip both surrogates
				} else {
					res.append(b0);
					i += 1;
				}
			}
			return res;
		}),
	]); }
}

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
	public static let JSONStrings = ComputedCollection<SymbolDFA<UInt32>>(size: 0x10FFFF, computeElement: {
		i in
		let hexMapping: Array<Array<Array<UInt32>>> = [
			[[0x30]], [[0x31]], [[0x32]], [[0x33]], [[0x34]], [[0x35]], [[0x36]], [[0x37]], [[0x38]], [[0x39]],
			[[0x41], [0x61]], [[0x42], [0x62]], [[0x43], [0x63]], [[0x44], [0x64]], [[0x45], [0x65]], [[0x46], [0x66]]
		];
		var strings = SymbolDFA<UInt32>.concatenate([
			SymbolDFA([[UInt32(0x5C), UInt32(0x75)]]),
			SymbolDFA(hexMapping[(i >> 12) & 0xf]),
			SymbolDFA(hexMapping[(i >> 8) & 0xf]),
			SymbolDFA(hexMapping[(i >> 4) & 0xf]),
			SymbolDFA(hexMapping[(i >> 0) & 0xf]),
		]);

		// unescaped = %x20-21 / %x23-5B / %x5D-FF
		if(i == 0x20 || i == 0x20 || i >= 0x23 && i <= 0x5B || i >= 0x5D && i <= 0x10FFFF){
			strings.formUnion(SymbolDFA([[UInt32(i)]]));
		}

		// %x5C CHAR
		switch(i){
			case 0x22: strings.formUnion(SymbolDFA([[0x5C, 0x22]])); // "    quotation mark
			case 0x5C: strings.formUnion(SymbolDFA([[0x5C, 0x5C]])); // \    reverse solidus
			case 0x2F: strings.formUnion(SymbolDFA([[0x5C, 0x2F]])); // /    solidus
			case 0x08: strings.formUnion(SymbolDFA([[0x5C, 0x62]])); // b    backspace
			case 0x0C: strings.formUnion(SymbolDFA([[0x5C, 0x66]])); // f    form feed
			case 0x0A: strings.formUnion(SymbolDFA([[0x5C, 0x6E]])); // n    line feed
			case 0x0D: strings.formUnion(SymbolDFA([[0x5C, 0x72]])); // r    carriage return
			case 0x09: strings.formUnion(SymbolDFA([[0x5C, 0x74]])); // t    tab
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
