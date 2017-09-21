/*
 * XibLocResolvingInfo.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



public struct XibLocResolvingInfo<SourceType, ReturnType> {
	
	let escapeToken: String?
	
	let simpleReplacements: [OneWordTokens: AnySimpleReplacementEngine<SourceType, ReturnType>]
	let orderedReplacements: [MultipleWordsTokens: Int]
	let pluralGroups: [MultipleWordsTokens: Int]
	
	/* Format: "@[id|key1:val1|key2:val2¦default replacement]".
	 * Examples of use:
	 *    - loc_string_en = "Hello @[plural|one:dude¦dudes]"
	 *    - loc_string_ru = "Hello in russian @[plural|one:russian word for dude|few:russian word for a few dudes¦russian word for dudes]"
	 *      When you have one guy to greet, the dictionary will contain
	 *      ["plural": "one"].
	 *      When you have a few guys to greet: ["plural": "few"]
	 *      Etc.
	 * The id can be used more than once in the same string, the replacements
	 * will be done for each dictionary with the same id.
	 *
	 * If a dictionary tag is found in the input but the id does not match any of
	 * the keys in this property, the tag won't be replaced at all. */
	let dictionaryReplacements: [String: String]
	
	let identityReplacement: AnySimpleReplacementEngine<SourceType, ReturnType>
	
}

public extension XibLocResolvingInfo where SourceType == String, ReturnType == String {
	
	public init(simpleReplacementWithToken token: String, value: String) {
		escapeToken = nil
		simpleReplacements = [OneWordTokens(token: token): AnySimpleReplacementEngine(constant: value)]
		orderedReplacements = [:]
		pluralGroups = [:]
		dictionaryReplacements = [:]
		identityReplacement = AnySimpleReplacementEngine.identity()
	}
	
}



public struct OneWordTokens : Hashable {
	
	let leftToken: String
	let rightToken: String
	
	init(token: String) {
		self.init(leftToken: token, rightToken: token)
	}
	
	init(leftToken lt: String, rightToken rt: String) {
		leftToken = lt
		rightToken = rt
		hashValue = (leftToken + rightToken).hashValue
	}
	
	public var hashValue: Int
	public static func ==(lhs: OneWordTokens, rhs: OneWordTokens) -> Bool {
		return lhs.leftToken == rhs.leftToken && lhs.rightToken == rhs.rightToken
	}
	
}

public struct MultipleWordsTokens : Hashable {
	
	let leftToken: String
	let interiorToken: String
	let rightToken: String
	
	init(exteriorToken: String, interiorToken: String) {
		self.init(leftToken: exteriorToken, interiorToken: interiorToken, rightToken: exteriorToken)
	}
	
	init(leftToken lt: String, interiorToken it: String, rightToken rt: String) {
		leftToken = lt
		interiorToken = it
		rightToken = rt
		hashValue = (leftToken + interiorToken + rightToken).hashValue
	}
	
	public var hashValue: Int
	public static func ==(lhs: MultipleWordsTokens, rhs: MultipleWordsTokens) -> Bool {
		return lhs.leftToken == rhs.leftToken && lhs.interiorToken == rhs.interiorToken && lhs.rightToken == rhs.rightToken
	}
	
}
