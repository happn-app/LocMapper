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
			"the |replaced|".applying(xibLocInfo: info),
			"the replacement"
		)
	}
	
	func testOneOrderedReplacement1() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"the <first:second>".applying(xibLocInfo: info),
			"the first"
		)
	}
	
	func testOneOrderedReplacement2() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1],
			pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"the <first:second>".applying(xibLocInfo: info),
			"the second"
		)
	}
	
	func testOneOrderedReplacementTwice() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"the <first:second> and also <first here:second here>".applying(xibLocInfo: info),
			"the first and also first here"
		)
	}
	
	func testOneOrderedReplacementAboveMax() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 2],
			pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"the <first:second>".applying(xibLocInfo: info),
			"the second"
		)
	}
	
	func testOnePluralReplacement() {
		let n = 1
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(string: "(1)(*)"), escapeToken: nil,
			simpleSourceTypeReplacements: [OneWordTokens(token: "#"): "\(n)"],
			orderedReplacements: [:],
			pluralGroups: [(MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"), .int(n))], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"#n# <house:houses>".applying(xibLocInfo: info),
			"1 house"
		)
	}
	
	func testOnePluralReplacementMissingOneZone() {
		let n = 2
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(string: "(1)(2→4:^*[^1][2→4]$)?(*)"), escapeToken: nil,
			simpleSourceTypeReplacements: [OneWordTokens(token: "#"): "\(n)"],
			orderedReplacements: [:],
			pluralGroups: [(MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"), .int(n))], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"#n# <house:houses>".applying(xibLocInfo: info),
			"2 houses"
		)
	}
	
	func testOneOrderedReplacementAndSimpleReplacement1() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [OneWordTokens(token: "|"): "first"],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"the <|fiftieth|:second>".applying(xibLocInfo: info),
			"the first"
		)
		XCTAssertEqual(
			"the <|1st|:second>".applying(xibLocInfo: info),
			"the first"
		)
		XCTAssertEqual(
			"the <||:second>".applying(xibLocInfo: info),
			"the first"
		)
	}
	
	func testOneOrderedReplacementAndSimpleReplacement2() {
		let info = XibLocResolvingInfo<String, String>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [OneWordTokens(token: "|"): "first"],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1],
			pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
		XCTAssertEqual(
			"the <|fiftieth|:second>".applying(xibLocInfo: info),
			"the second"
		)
	}
	
	func testOneOrderedReplacementAndIdentityAttributeModification1() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [],
			attributesModifications: [OneWordTokens(token: "$"): helperAddTestAttributeLevel],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: { NSMutableAttributedString(string: $0) }
		)
		let result = NSMutableAttributedString(string: "the ")
		result.append(NSAttributedString(string: "first", attributes: [.accessibilityListItemLevel: NSNumber(value: 0)]))
		XCTAssertEqual(
			"the <$first$:second>".applying(xibLocInfo: info),
			result
		)
	}
	
	func testOneOrderedReplacementAndIdentityAttributeModification2() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1],
			pluralGroups: [],
			attributesModifications: [OneWordTokens(token: "$"): helperAddTestAttributeLevel],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: { NSMutableAttributedString(string: $0) }
		)
		XCTAssertEqual(
			"the <$first$:second>".applying(xibLocInfo: info),
			NSMutableAttributedString(string: "the second")
		)
	}
	
	func testOneOrderedReplacementAndIdentityAttributeModification3() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 0],
			pluralGroups: [],
			attributesModifications: [OneWordTokens(token: "$"): helperAddTestAttributeLevel],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: { NSMutableAttributedString(string: $0) }
		)
		let result = NSMutableAttributedString(string: "the ")
		result.append(NSAttributedString(string: "first", attributes: [.accessibilityListItemLevel: NSNumber(value: 0)]))
		XCTAssertEqual(
			"the $<first:second>$".applying(xibLocInfo: info),
			result
		)
	}
	
	func testOneOrderedReplacementAndIdentityAttributeModification4() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"): 1],
			pluralGroups: [],
			attributesModifications: [OneWordTokens(token: "$"): helperAddTestAttributeLevel],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil, identityReplacement: { NSMutableAttributedString(string: $0) }
		)
		let result = NSMutableAttributedString(string: "the ")
		result.append(NSAttributedString(string: "second", attributes: [.accessibilityListItemLevel: NSNumber(value: 0)]))
		XCTAssertEqual(
			"the $<first:second>$".applying(xibLocInfo: info),
			result
		)
	}
	
	func testOneAttributesChange() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:], orderedReplacements: [:], pluralGroups: [],
			attributesModifications: [OneWordTokens(token: "*"): helperAddTestAttributeLevel],
			simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { NSMutableAttributedString(string: $0) }
		)
		let result = NSMutableAttributedString(string: "the ")
		result.append(NSAttributedString(string: "test", attributes: [.accessibilityListItemLevel: NSNumber(value: 0)]))
		XCTAssertEqual(
			"the *test*".applying(xibLocInfo: info),
			result
		)
	}
	
	func testTwoOverlappingAttributesChange() {
		let info = XibLocResolvingInfo<String, NSMutableAttributedString>(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: nil,
			simpleSourceTypeReplacements: [:], orderedReplacements: [:], pluralGroups: [],
			attributesModifications: [
				OneWordTokens(token: "*"): helperAddTestAttributeLevel,
				OneWordTokens(token: "_"): helperAddTestAttributeIndex
			], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { NSMutableAttributedString(string: $0) }
		)
		let result = NSMutableAttributedString(string: "the test ")
		result.append(NSAttributedString(string: "one ", attributes: [.accessibilityListItemLevel: NSNumber(value: 0)]))
		result.append(NSAttributedString(string: "and", attributes: [.accessibilityListItemLevel: NSNumber(value: 0), .accessibilityListItemIndex: NSNumber(value: 0)]))
		result.append(NSAttributedString(string: " two", attributes: [.accessibilityListItemIndex: NSNumber(value: 0)]))
		XCTAssertEqual(
			"the test *one _and* two_".applying(xibLocInfo: info),
			result
		)
	}
	
	func helperAddTestAttributeLevel(to attributedString: inout NSMutableAttributedString, strRange: Range<String.Index>, refStr: String) {
		attributedString.addAttributes([.accessibilityListItemLevel: NSNumber(value: 0)], range: NSRange(strRange, in: refStr))
	}
	
	func helperAddTestAttributeIndex(to attributedString: inout NSMutableAttributedString, strRange: Range<String.Index>, refStr: String) {
		attributedString.addAttributes([.accessibilityListItemIndex: NSNumber(value: 0)], range: NSRange(strRange, in: refStr))
	}
	
}