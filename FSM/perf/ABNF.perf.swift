import XCTest
import FSM

class ABNFtoPatternTests: XCTestCase {
	func testToPattern4() {
		let test_source = "Number = *%x00-F\r\n";
		let referenceRulelist: ABNFRulelist<UInt8> = try! ABNFRulelist<UInt8>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt8>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}

	func testToPattern8() {
		let test_source = "Number = *%x00-FF\r\n";
		let referenceRulelist: ABNFRulelist<UInt8> = try! ABNFRulelist<UInt8>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt8>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}

	func testToPattern16() {
		let test_source = "Number = *%x00-FFFF\r\n";
		let referenceRulelist: ABNFRulelist<UInt16> = try! ABNFRulelist<UInt16>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt16>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}

	func testToPattern32() {
		let test_source = "Number = *%x00-10FFFF\r\n";
		let referenceRulelist: ABNFRulelist<UInt32> = try! ABNFRulelist<UInt32>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt32>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}
}

class ABNFAlternationToPattern: XCTestCase {
	func testToPattern4() {
		let test_source = "char = %x0-F\r\n";
		let referenceRulelist: ABNFRulelist<UInt8> = try! ABNFRulelist<UInt8>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt8>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}

	func testToPattern8() {
		let test_source = "ucschar = %xA0-D7\r\n";
		let referenceRulelist: ABNFRulelist<UInt8> = try! ABNFRulelist<UInt8>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt8>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}

	func testToPattern16() {
		let test_source = "ucschar = %xA0-D7FF / %xF900-FDCF / %xFDF0-FFEF\r\n";
		let referenceRulelist: ABNFRulelist<UInt16> = try! ABNFRulelist<UInt16>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt16>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}

	func testToPattern32() {
		let test_source = "ucschar = %xA0-D7FF / %xF900-FDCF / %xFDF0-FFEF / %x10000-1FFFD / %x20000-2FFFD / %x30000-3FFFD / %x40000-4FFFD / %x50000-5FFFD / %x60000-6FFFD / %x70000-7FFFD / %x80000-8FFFD / %x90000-9FFFD / %xA0000-AFFFD / %xB0000-BFFFD / %xC0000-CFFFD / %xD0000-DFFFD / %xE1000-EFFFD\r\n";
		let referenceRulelist: ABNFRulelist<UInt32> = try! ABNFRulelist<UInt32>.parse(test_source.replacing("\n", with: "\r\n").utf8);

		measure {
			let referenceDictionary = try! referenceRulelist.toClosedRangePattern(as: RangeDFA<UInt32>.self);
			assert(referenceDictionary.keys.count == 1);
		}
	}
}
