/*
 * XcodeStringsParserTests.swift
 * LocMapperTests
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import XCTest
@testable import LocMapper



class XcodeStringsParserTests: XCTestCase {
	
	func testFail1() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "\""))
	}
	
	func testFail2() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "abc=def"))
	}
	
	func testFail3() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "abc"))
	}
	
	func testFail4() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "=a;"))
	}
	
	func testFail5() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/=//;"))
	}
	
	func testFail6() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/*"))
	}
	
	func testFail7() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* yoyo *"))
	}
	
	func testFail8() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "abc=/*yo* def;"))
	}
	
	func testFail9() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "a=  ;"))
	}
	
	func testEmpty() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertTrue(parsed.components.isEmpty)
	}
	
	func testNoValues1() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "  \n")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.WhiteSpace("  \n")].map{ $0.stringValue }
		)
	}
	
	func testNoValues2() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "  \n/*comment1*///comment2\n")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.WhiteSpace("  \n"),
			  XcodeStringsFile.Comment("comment1", doubleSlashed: false),
			  XcodeStringsFile.Comment("comment2", doubleSlashed: true)] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testNoValues3() {
		/* Note: If the file is a non-trailing whiteline file ending with a //-styled comment,
		 *       the output file on re-export _will_ contain a trailing whiteline.
		 *       I don't feel too bad about it though :) */
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "  \n/*comment1*///comment2")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.WhiteSpace("  \n"),
			  XcodeStringsFile.Comment("comment1", doubleSlashed: false),
			  XcodeStringsFile.Comment("comment2", doubleSlashed: true)] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testStarInComment() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* * */")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.Comment(" * ", doubleSlashed: false)].map{ $0.stringValue }
		)
	}
	
	func testStarAtEndOfComment() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* **/")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.Comment(" *", doubleSlashed: false)].map{ $0.stringValue }
		)
	}
	
	func testDoubleStarAtEndOfComment() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* ***/")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.Comment(" **", doubleSlashed: false)].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile1() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"hello" = "Hello!";
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: true, equalSign: " = ", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile2() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			hello = "Hello!";
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: false, equalSign: " = ", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile3() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"hello"=/*comment*/"Hello!";
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: true, equalSign: "=/*comment*/", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile4() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"hello"/*yeay*//*super happy*/=//oneline comment
			"Hello!";
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: true, equalSign: "/*yeay*//*super happy*/=//oneline comment\n", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile5() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"\\\"hello" = "Hello!";
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "\"hello", keyHasQuotes: true, equalSign: " = ", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseTwoValuesXcodeStringsFile() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"key1" = "Value 1";
			"key2" = "Value 2";
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.LocalizedString(key: "key1", keyHasQuotes: true, equalSign: " = ", value: "Value 1", valueHasQuotes: true, semicolon: ";"),
			  XcodeStringsFile.WhiteSpace("\n"),
			  XcodeStringsFile.LocalizedString(key: "key2", keyHasQuotes: true, equalSign: " = ", value: "Value 2", valueHasQuotes: true, semicolon: ";")] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testWhiteAfterValues() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "key=value;  \n")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.LocalizedString(key: "key", keyHasQuotes: false, equalSign: "=", value: "value", valueHasQuotes: false, semicolon: ";"),
			  XcodeStringsFile.WhiteSpace("  \n")] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile1() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			1//_$:.-2_NA2 //
			=/*hehe*/
			N/A;
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "1//_$:.-2_NA2", keyHasQuotes: false, equalSign: " //\n=/*hehe*/\n", value: "N/A", valueHasQuotes: false, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile2() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			/=/;
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile3() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			/=/ /**/;
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: " /**/;")].map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile4() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			1//_$:.-2_NA2 //
			=/*hehe*/
			N/A;/=/;
			/=/ /**/;
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.LocalizedString(key: "1//_$:.-2_NA2", keyHasQuotes: false, equalSign: " //\n=/*hehe*/\n", value: "N/A", valueHasQuotes: false, semicolon: ";"),
			  XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: ";"),
			  XcodeStringsFile.WhiteSpace("\n"),
			  XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: " /**/;")] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testKeyButNotValues() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "this_is_weird_but_valid;")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "this_is_weird_but_valid", keyHasQuotes: false, equalSign: "", value: "", valueHasQuotes: false, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testKeyButNotValues2() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "this_is_weird_but_valid  ;")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "this_is_weird_but_valid", keyHasQuotes: false, equalSign: "", value: "", valueHasQuotes: false, semicolon: "  ;")].map{ $0.stringValue }
		)
	}
	
	func testKeyButNotValues3() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: "\"this_is_weird_but_valid\"  ;")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "this_is_weird_but_valid", keyHasQuotes: true, equalSign: "", value: "", valueHasQuotes: false, semicolon: "  ;")].map{ $0.stringValue }
		)
	}
	
}
