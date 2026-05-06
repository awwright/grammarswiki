import Testing
@testable import FSM
@Suite("ComputedHomomorphism Tests")
struct ComputedHomomorphismTests {

	@Test("Normalization is idempotent")
	func testNormalizationIdempotency() async throws {
		// Create a simple homomorphism that appends a fixed value
		let homo = ComputedHomomorphism<String>(source: "A", target: "B", forward: { $0 + ["extra"] }, backward: { $0.dropLast() })
		let input: [String] = ["hello", "world"]
		let normalized = try #require(homo.norm(input))
		let doubleNormalized = try #require(homo.norm(normalized))
		#expect(normalized == doubleNormalized, "Normalization should be idempotent")
	}

	@Test("Composition of homomorphisms")
	func testComposition() async throws {
		let homo1 = ComputedHomomorphism<String>(source: "A", target: "B", forward: { $0 + ["1"] }, backward: { $0.dropLast() })
		let homo2 = ComputedHomomorphism<String>(source: "B", target: "C", forward: { $0 + ["2"] }, backward: { $0.dropLast() })
		let composed = ComputedHomomorphism.compose([homo1, homo2])
		let input: [String] = ["test"]
		let forwardResult = try #require(composed.tr(input))
		#expect(forwardResult == ["test", "1", "2"])
		let backwardResult = try #require(composed.inv(forwardResult))
		#expect(backwardResult == input)
	}
}

@Suite("HomomorphismGraph Tests")
struct HomomorphismGraphTests {

	@Test("Finding direct edge")
	func testFindDirectEdge() async throws {
		var graph = HomomorphismGraph<UInt8>([])
		let homo = ComputedHomomorphism<UInt8>(source: "A", target: "B", forward: { $0 }, backward: { $0 })
		graph.insert(homo)
		let found = graph.find(source: "A", target: "B")
		#expect(found != nil)
		#expect(found!.source == "A" && found!.target == "B")
	}

	@Test("Finding path through intermediate")
	func testFindPathThroughIntermediate() async throws {
		var graph = HomomorphismGraph<UInt8>([])
		let homo1 = ComputedHomomorphism<UInt8>(source: "A", target: "C", forward: { $0 }, backward: { $0 })
		let homo2 = ComputedHomomorphism<UInt8>(source: "C", target: "B", forward: { $0 }, backward: { $0 })
		graph.insert(homo1)
		graph.insert(homo2)
		let found = graph.find(source: "A", target: "B")
		#expect(found != nil)
		#expect(found!.source == "A" && found!.target == "B")
	}
}

@Suite("HomomorphismGraph.builtin")
struct HomomorphismGraphBuiltinTests {
	@Test("All")
	func test_all() async throws {
		let builtin = HomomorphismGraph<UInt32>.builtin;

		// Test UTF-32 to UTF-8 for a simple case (ASCII)
		let utf32Input: [UInt32] = [65] // 'A'
		let utf8Converter = try #require(builtin.find(source: "UTF-32", target: "UTF-8"))
		let utf8Output = try #require(utf8Converter.tr(utf32Input))
		#expect(utf8Output == [65], "ASCII 'A' should convert correctly")

		// Test UTF-32 to UTF-16 for a non-BMP character (should use surrogates, but current impl is wrong)
		let nonBmpInput: [UInt32] = [0x1F600] // 😀
		let utf16Converter = try #require(builtin.find(source: "UTF-32", target: "UTF-16"))
		let utf16Output = utf16Converter.tr(nonBmpInput)
		// This will likely fail because the forward function is UTF-8 logic, not UTF-16
		// Expected UTF-16 surrogates: [0xD83D, 0xDE00], but it will produce UTF-8 bytes
		let expectedUtf16: [UInt32] = [0xD83D, 0xDE00] // Correct surrogates
		#expect(utf16Output == expectedUtf16, "Non-BMP character should convert to UTF-16 surrogates correctly")

		// Test round-trip for UTF-8 (should work)
		let roundTrip8 = utf8Converter.inv(utf8Output)
		#expect(roundTrip8 == utf32Input, "UTF-8 round-trip should preserve value")

		// Test round-trip for UTF-16 (will fail due to incorrect implementation)
		let roundTrip16 = utf16Converter.inv(utf16Output ?? [])
		#expect(roundTrip16 == nonBmpInput, "UTF-16 round-trip should preserve value")
	}

	@Test("UTF-8")
	func test_UTF_8() async throws {
		let builtin = try #require(HomomorphismGraph<UInt32>.builtin.find(source: "UTF-32", target: "UTF-8"));
		//for i in [0x0000...0xD7FF, 0xE000...0x10FFFF].lazy.joined() {
		for i in [0x00, 0x01, 0x7F, 0x80, 0x81, 0x100, 0x400, 0x7FF, 0x800, 0x1111, 0x4444, 0x8888, 0xAAAA, 0xCCCC, 0xD7FF, 0xE000, 0xFFFF, 0x10000, 0x10, 0x104444, 0x107777, 0x10AAAA, 0x10FFFF].lazy {
			// create a string from codepoint i
			let string = String(UnicodeScalar(i)!);
			let reference = Array<UInt8>(string.utf8);

			let ours32 = builtin.tr([UInt32(i)])!;
			let ours8 = ours32.map { UInt8($0); };
			// Build a string from the array
			#expect(ours8 == reference)
			#expect(String(decoding: ours8, as: Unicode.UTF8.self) == String(decoding: reference, as: Unicode.UTF8.self) )
			//#expect(builtin.inv(ours32)! == string.unicodeScalars.map(\.value));
			#expect(builtin.tr(builtin.inv(ours32)!)! == ours32);
		}
	}

	@Test("UTF-16")
	func test_UTF_16() async throws {
		let builtin = try #require(HomomorphismGraph<UInt32>.builtin.find(source: "UTF-32", target: "UTF-16"));
		//for i in [0x0000...0xD7FF, 0xE000...0x10FFFF].lazy.joined() {
		for i in [0x00, 0x01, 0x7F, 0x80, 0x81, 0x100, 0x400, 0x7FF, 0x800, 0x1111, 0x4444, 0x8888, 0xAAAA, 0xCCCC, 0xD7FF, 0xE000, 0xFFFF, 0x10000, 0x10, 0x104444, 0x107777, 0x10AAAA, 0x10FFFF].lazy {
			print(i);
			// create a string from codepoint i
			let string = String(UnicodeScalar(i)!);
			let reference = Array<UInt16>(string.utf16);

			let ours32 = builtin.tr([UInt32(i)])!;
			let ours16 = ours32.map { UInt16($0); };
			// Build a string from the array
			#expect(ours16 == reference)
			#expect(String(decoding: ours16, as: Unicode.UTF16.self) == String(decoding: reference, as: Unicode.UTF16.self) )
			#expect(builtin.inv(ours32)! == string.unicodeScalars.map(\.value));
			#expect(builtin.tr(builtin.inv(ours32)!)! == ours32);
		}
	}
}

