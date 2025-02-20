import Testing;
@testable import FSM;

@Test("hex_val")
func test_hex_val() async throws {
//	let res = try! hex_val.match("a4-a5g");
//	#expect(res.0 == hex_val(lower: 0xa4, upper: 0xa5));
//	#expect(res.1 == "g");
}

@Test("prose_val")
func test_prose_val() async throws {
	let res = try! prose_val.match("<Some message> 123");
	#expect(res.0 == prose_val(remark: "Some message"));
	#expect(res.1 == " 123");
}

