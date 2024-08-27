"use strict";

const assert = require('assert/strict');
module.exports.testTarget = testTarget;

function testTarget(target, tl){
	function rule(syntax, callback){
		it(syntax, function(){
			const parser = tl.compile(syntax + '\r\n');
			function accepts(input){
				assert(parser.test(input));
			}
			function rejects(input){
				it(syntax, function(){
					assert.equal(parser.test(input), false);
				});
			}
			callback.call(this, accepts, rejects)
		});
	}
	
	describe(target, function(){
		rule('epsilon = ""', function(accepts, rejects){
			accepts('');
			rejects('-');
		});
		rule('builtin = ALPHA', function(accepts, rejects){
			accepts('A');
			accepts('Z');
			accepts('a');
			accepts('z');
			rejects('0');
			rejects('9');
		});
		rule('builtin = BIT', function(accepts, rejects){
			accepts('0');
			accepts('1');
			rejects('2');
			rejects('A');
		});

		rule('builtin = CHAR', function(accepts, rejects){
			accepts('0');
			accepts('A');
			accepts(' ');
			rejects('\x00');
		});
		rule('builtin = CR', function(accepts, rejects){
			accepts('\r');
			rejects('\n');
			rejects('A');
		});
		rule('builtin = CRLF', function(accepts, rejects){
			accepts('\r\n');
			rejects('\r');
			rejects('\n');
		});
		rule('builtin = CTL', function(accepts, rejects){
			accepts('\x00');
			accepts('\x1F');
			rejects(' ');
		});
		rule('builtin = DIGIT', function(accepts, rejects){
			accepts('0');
			accepts('1');
			accepts('2');
			rejects('A');
		});
		rule('builtin = DQUOTE', function(accepts, rejects){
			accepts('"');
			rejects('A');
		});
		rule('builtin = HEXDIG', function(accepts, rejects){
			accepts('0');
			accepts('1');
			accepts('9');
			accepts('A');
			accepts('a');
			accepts('F');
			accepts('f');
			rejects(' ');
		});
		rule('builtin = HTAB', function(accepts, rejects){
			accepts('\t');
			rejects(' ');
		});
		rule('builtin = LF', function(accepts, rejects){
			accepts('\n');
			rejects('\r');
			rejects('A');
		});
		rule('builtin = LWSP', function(accepts, rejects){
			accepts('');
			accepts(' ');
			accepts('\t');
			accepts('\r\n ');
			accepts('\r\n\t');
			accepts(' \r\n ');
			accepts('\t\r\n\t');
			rejects('\r');
			rejects('\n');
			rejects('\r\n');
			rejects(' \r\n');
		});
		rule('builtin = OCTET', function(accepts, rejects){
			accepts('0');
			accepts('1');
			accepts('7');
			rejects('8');
			rejects('9');
			rejects('A');
			rejects('a');
		});
		rule('builtin = SP', function(accepts, rejects){
			accepts(' ');
			rejects('\t');
		});
		rule('builtin = VCHAR', function(accepts, rejects){
			rejects('');
			rejects(' ');
			accepts('!');
			accepts('~');
		});
		rule('builtin = WSP', function(accepts, rejects){
			accepts(' ');
			accepts('\t');
			rejects('a');
		});
		rule('alternation = "1" / "2"', function(accepts, rejects){
			accepts('1');
			accepts('2');
			rejects('0');
			rejects('3');
		});
		rule('concatenation = "1" "2"', function(accepts, rejects){
			accepts('12');
			rejects('1');
			rejects('2');
		});
		rule('repetition = 0*1"-"', function(accepts, rejects){
			accepts('');
			accepts('-');
			rejects('--');
			rejects('---');
		});
		rule('repetition = 2*2"-"', function (accepts, rejects) {
			rejects('-');
			accepts('--');
			rejects('---');
		});
		rule('repetition = 2*5"-"', function (accepts, rejects) {
			rejects('-');
			accepts('--');
			accepts('---');
			accepts('----');
			accepts('-----');
			rejects('------');
		});
		rule('repetition = 2*"-"', function (accepts, rejects) {
			rejects('-');
			accepts('--');
			accepts('---');
		});
		rule('optional = ["-"]', function(accepts, rejects){
			accepts('');
			accepts('-');
			rejects('---');
		});
	});
}
