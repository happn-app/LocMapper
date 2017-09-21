/*
 * XibLocTests.swift
 * XibLocTests
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import XCTest
@testable import XibLoc



class XibLocTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
	}
	
	override func tearDown() {
		super.tearDown()
	}
	
	func testOneSimpleReplacement() {
		XCTAssertEqual(
			try "|replaced|".applying(xibLocInfo: XibLocResolvingInfo(simpleReplacementWithToken: "|", value: "replacement")),
			"replacement"
		)
	}
	
}
