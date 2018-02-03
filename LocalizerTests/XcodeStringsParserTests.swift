/*
 * XcodeStringsParserTests.swift
 * LocalizerTests
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import XCTest
@testable import Localizer



class XcodeStringsParserTests: XCTestCase {
	
	func testParseSimpleXcodeStringsFile2() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"hello" = "Hello!";
			""")
		else {XCTFail("Cannot parse input"); return}
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: true, equalSign: " = ", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile() {
		guard let parsed = try? XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			1//_$:.-2_NA2 //
			=/*hehe*/
			N/A;/=/;
			/=/ /**/;
			""")
		else {XCTFail("Cannot parse input"); return}
	}
	
}
