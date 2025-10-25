import FSM
import XCTest

class RegexBuilderPerf: XCTestCase {
	// In theory, this should only be slightly more expensive than testSymbolDFA below
	func testRangeDFA() throws {
		let abnf = """
			URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
			hier-part = "//" authority path-abempty / path-absolute / path-rootless / path-empty
			URI-reference = URI / relative-ref
			absolute-URI  = scheme ":" hier-part [ "?" query ]
			relative-ref  = relative-part [ "?" query ] [ "#" fragment ]
			relative-part = "//" authority path-abempty / path-absolute / path-noscheme / path-empty
			scheme        = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
			authority     = [ userinfo "@" ] host [ ":" port ]
			userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
			host          = reg-name ;/ IP-literal / IPv4address
			port          = *DIGIT
			IP-literal    = "[" ( IPv6address / IPvFuture  ) "]"
			IPvFuture     = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
			IPv6address   =                            6( h16 ":" ) ls32
			              /                       "::" 5( h16 ":" ) ls32
			              / [               h16 ] "::" 4( h16 ":" ) ls32
			              / [ *1( h16 ":" ) h16 ] "::" 3( h16 ":" ) ls32
			              / [ *2( h16 ":" ) h16 ] "::" 2( h16 ":" ) ls32
			              / [ *3( h16 ":" ) h16 ] "::"    h16 ":"   ls32
			              / [ *4( h16 ":" ) h16 ] "::"              ls32
			              / [ *5( h16 ":" ) h16 ] "::"              h16
			              / [ *6( h16 ":" ) h16 ] "::"
			h16           = 1*4HEXDIG
			ls32          = ( h16 ":" h16 ) / IPv4address
			IPv4address   = dec-octet "." dec-octet "." dec-octet "." dec-octet
			dec-octet     = DIGIT / %x31-39 DIGIT / "1" 2DIGIT / "2" %x30-34 DIGIT / "25" %x30-35
			reg-name      = *( unreserved / pct-encoded / sub-delims )
			path          = path-abempty / path-absolute / path-noscheme / path-rootless / path-empty
			path-abempty  = *( "/" segment )
			path-absolute = "/" [ segment-nz *( "/" segment ) ]
			path-noscheme = segment-nz-nc *( "/" segment )
			path-rootless = segment-nz *( "/" segment )
			path-empty    = ""
			segment       = *pchar
			segment-nz    = 1*pchar
			segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
			pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
			query         = *( pchar / "/" / "?" )
			fragment      = *( pchar / "/" / "?" )
			pct-encoded   = "%" HEXDIG HEXDIG
			unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
			reserved      = gen-delims / sub-delims
			gen-delims    = ":" / "/" / "?" / "#" / "[" / "]" / "@"
			sub-delims    = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
			ALPHA          =  %x41-5A / %x61-7A   ; A-Z / a-z
			DIGIT          =  %x30-39
			HEXDIG         =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F"

			""".replacingOccurrences(of: "\n", with: "\r\n").utf8;
		let grammar = try ABNFRulelist<UInt8>.parse(abnf);
		let dict = grammar.dictionary;
		measure {
			print("compute fsm...");
			let fsm0: RangeDFA<UInt8> = try! dict["URI"]!.toPattern(rules: grammar)
			print("compute minimized...");
			let fsm = fsm0.minimized()
//			print("compute regex...");
//			let regex: REPattern = fsm.toPattern()
//			print("compute regex literal...");
//			let description = regex.description;
//			print("count = \(description.count)");
//			assert(description.count > 10)
		}
	}

	func testSymbolDFA() throws {
		let abnf = """
			URI           = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
			hier-part     = "//" authority path-abempty / path-absolute / path-rootless / path-empty
			URI-reference = URI / relative-ref
			absolute-URI  = scheme ":" hier-part [ "?" query ]
			relative-ref  = relative-part [ "?" query ] [ "#" fragment ]
			relative-part = "//" authority path-abempty / path-absolute / path-noscheme / path-empty
			scheme        = ("A" / "G" / "V") *( "A" / "G" / "V" / %x30-36 / "+" / "." )
			authority     = [ userinfo "@" ] host [ ":" port ]
			userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
			host          = IP-literal / IPv4address / reg-name
			port          = *%x30-36
			IP-literal    = "[" ( IPv6address / IPvFuture  ) "]"
			IPvFuture     = "v" 1*"A" "." 1*( unreserved / sub-delims / ":" )
			IPv6address   =                            6( h16 ":" ) ls32
			              /                       "::" 5( h16 ":" ) ls32
			              / [               h16 ] "::" 4( h16 ":" ) ls32
			              / [ *1( h16 ":" ) h16 ] "::" 3( h16 ":" ) ls32
			              / [ *2( h16 ":" ) h16 ] "::" 2( h16 ":" ) ls32
			              / [ *3( h16 ":" ) h16 ] "::"    h16 ":"   ls32
			              / [ *4( h16 ":" ) h16 ] "::"              ls32
			              / [ *5( h16 ":" ) h16 ] "::"              h16
			              / [ *6( h16 ":" ) h16 ] "::"
			h16           = 1*4"A"
			ls32          = ( h16 ":" h16 ) / IPv4address
			IPv4address   = dec-octet "." dec-octet "." dec-octet "." dec-octet
			dec-octet     = %x30-36 / %x31-36 %x30-36 / "1" 2%x30-36 / "2" %x30-34 %x30-36 / "25" %x30-35			
			reg-name      = *( unreserved / pct-encoded / sub-delims )
			path          = path-abempty / path-absolute / path-noscheme / path-rootless / path-empty
			path-abempty  = *( "/" segment )
			path-absolute = "/" [ segment-nz *( "/" segment ) ]
			path-noscheme = segment-nz-nc *( "/" segment )
			path-rootless = segment-nz *( "/" segment )
			path-empty    = ""
			segment       = *pchar
			segment-nz    = 1*pchar
			segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
			pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
			query         = *( pchar / "/" / "?" )
			fragment      = *( pchar / "/" / "?" )
			pct-encoded   = "%" "A" "A"
			unreserved    = "A" / "G" / "V"  / "."
			gen-delims    = ":" / "/" / "?" / "#" / "[" / "]" / "@"
			sub-delims    = "!" / "+"
			
			""".replacingOccurrences(of: "\n", with: "\r\n").utf8;
		let grammar = try ABNFRulelist<UInt8>.parse(abnf);
		let dict = grammar.dictionary;
		measure {
			print("compute fsm...");
			let fsm0: SymbolDFA<UInt8> = try! dict["URI"]!.toPattern(rules: grammar)
			print("compute minimized...");
			let fsm = fsm0.minimized()
//			print("compute regex...");
//			let regex: REPattern = fsm.toPattern()
//			print("compute regex literal...");
//			let description = regex.description;
//			print("count = \(description.count)");
//			assert(description.count > 10)
		}
	}
}

