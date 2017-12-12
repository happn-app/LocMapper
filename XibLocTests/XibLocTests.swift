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
		XCTAssertEqual(
			try "the |replaced|".applying(xibLocInfo: info),
			"the replacement"
		)
	}
	
	func testOneOrderedReplacement1() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [:], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: AnyAttributesModifierEngine<String, String>.identity()
		)
		XCTAssertEqual(
			try "the <first:second>".applying(xibLocInfo: info),
			"the first"
		)
	}
	
	func testOneOrderedReplacement2() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1],
			pluralGroups: [:], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: AnyAttributesModifierEngine.identity()
		)
		XCTAssertEqual(
			try "the <first:second>".applying(xibLocInfo: info),
			"the second"
		)
	}
	
	func testOneOrderedReplacementAndSimpleReplacement1() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [OneWordTokens(token: "|"): "first"],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [:], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: AnyAttributesModifierEngine.identity()
		)
		XCTAssertEqual(
			try "the <|fiftieth|:second>".applying(xibLocInfo: info),
			"the first"
		)
		XCTAssertEqual(
			try "the <|1st|:second>".applying(xibLocInfo: info),
			"the first"
		)
		XCTAssertEqual(
			try "the <||:second>".applying(xibLocInfo: info),
			"the first"
		)
	}
	
	func testOneOrderedReplacementAndSimpleReplacement2() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [OneWordTokens(token: "|"): "first"],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1],
			pluralGroups: [:], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: AnyAttributesModifierEngine.identity()
		)
		XCTAssertEqual(
			try "the <|fiftieth|:second>".applying(xibLocInfo: info),
			"the second"
		)
	}
	
	func testOneOrderedReplacementAndIdentityAttributeModification1() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [:],
			attributesModifications: [OneWordTokens(token: "$"): AnyAttributesModifierEngine(handlerEngine: { String($0.reversed()) })],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: AnyAttributesModifierEngine.identity()
		)
		XCTAssertEqual(
			try "the <$tsrif$:second>".applying(xibLocInfo: info),
			"the first"
		)
	}
	
	func testOneOrderedReplacementAndIdentityAttributeModification2() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1],
			pluralGroups: [:],
			attributesModifications: [OneWordTokens(token: "$"): AnyAttributesModifierEngine(handlerEngine: { String($0.reversed()) })],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: AnyAttributesModifierEngine.identity()
		)
		XCTAssertEqual(
			try "the <$tsrif$:second>".applying(xibLocInfo: info),
			"the second"
		)
	}
	
	func testOneAttributesChange() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:], orderedReplacements: [:], pluralGroups: [:],
			attributesModifications: [OneWordTokens(token: "*"): AnyAttributesModifierEngine(handlerEngine: helperAddTestAttributeLevel)],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: AnyAttributesModifierEngine(handlerEngine: { NSMutableAttributedString(string: $0) })
		)
		let result = NSMutableAttributedString(string: "the ")
		result.append(NSAttributedString(string: "test", attributes: [.accessibilityListItemLevel: NSNumber(value: 0)]))
		XCTAssertEqual(
			try "the *test*".applying(xibLocInfo: info),
			result
		)
	}
	
	func testTwoOverlappingAttributesChange() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:], orderedReplacements: [:], pluralGroups: [:],
			attributesModifications: [
				OneWordTokens(token: "*"): AnyAttributesModifierEngine(handlerEngine: helperAddTestAttributeLevel),
				OneWordTokens(token: "_"): AnyAttributesModifierEngine(handlerEngine: helperAddTestAttributeIndex)
			], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: AnyAttributesModifierEngine(handlerEngine: { NSMutableAttributedString(string: $0) })
		)
		let result = NSMutableAttributedString(string: "the test ")
		result.append(NSAttributedString(string: "one ", attributes: [.accessibilityListItemLevel: NSNumber(value: 0)]))
		result.append(NSAttributedString(string: "and", attributes: [.accessibilityListItemLevel: NSNumber(value: 0), .accessibilityListItemIndex: NSNumber(value: 0)]))
		result.append(NSAttributedString(string: " two", attributes: [.accessibilityListItemIndex: NSNumber(value: 0)]))
		XCTAssertEqual(
			try "the test *one _and* two_".applying(xibLocInfo: info),
			result
		)
	}
	
	func helperAddTestAttributeLevel(to attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
		attributedString.addAttributes([.accessibilityListItemLevel: NSNumber(value: 0)], range: NSRange(location: 0, length: attributedString.length))
		return attributedString
	}
	
	func helperAddTestAttributeIndex(to attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
		attributedString.addAttributes([.accessibilityListItemIndex: NSNumber(value: 0)], range: NSRange(location: 0, length: attributedString.length))
		return attributedString
	}
	
}
