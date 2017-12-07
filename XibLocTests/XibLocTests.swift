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
		let info = XibLocResolvingInfo(simpleReplacementWithToken: "|", value: "replacement")
//		let info = XibLocResolvingInfo(defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil, simpleSourceTypeReplacements: [:], orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1], pluralGroups: [:], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: AnyAttributesModifierEngine<String, String>.identity())
//		let info = XibLocResolvingInfo(defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil, simpleSourceTypeReplacements: [OneWordTokens(token: "|"): "replacement"], orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1], pluralGroups: [:], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: AnyAttributesModifierEngine<String, String>.identity())
		XCTAssertEqual(
			try "the <|replaced|\\:yop:dodo>".applying(xibLocInfo: info),
			"the replacement"
		)
	}
	
}
