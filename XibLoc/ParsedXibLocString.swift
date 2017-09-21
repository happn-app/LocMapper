/*
 * ParsedXibLocString.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct ParsedXibLoc<SourceType, ParserHelper : XibLoc.ParserHelper> where ParserHelper.SourceType == SourceType {
	
	enum ParsedXibLocPart {
		
		case constant(SourceType)
		case simpleReplacement(OneWordTokens, value: SourceType)
		case orderedReplacement(MultipleWordsTokens, values: [SourceType])
		case pluralGroup(MultipleWordsTokens, values: [SourceType])
		case dictionaryReplacement(id: String, defaultValue: SourceType?, otherValues: [String: SourceType])
		
	}
	
	let parts: [ParsedXibLocPart]
	
	init(source: SourceType, parserHelper: ParserHelper, simpleReplacements: [OneWordTokens], orderedReplacements: [MultipleWordsTokens], pluralGroups: [MultipleWordsTokens], defaultPluralityDefinition: PluralityDefinition) {
		var source = source
		var stringSource = parserHelper.stringRepresentation(of: source)
		let pluralityDefinitions = ParsedXibLoc<SourceType, ParserHelper>.preprocessForPluralityDefinitionOverrides(source: &source, stringSource: &stringSource, parserHelper: parserHelper, defaultPluralityDefinition: defaultPluralityDefinition)
		
		parts = []
	}
	
//	func resolve(simpleReplacementsValues: [String], orderedReplacementsValues: [Int], pluralGroupsValues: [Int]) -> String {
//		return ""
//	}
	
	private static func preprocessForPluralityDefinitionOverrides(source: inout SourceType, stringSource: inout String, parserHelper: ParserHelper, defaultPluralityDefinition: PluralityDefinition) -> [PluralityDefinition] {
		guard stringSource.hasPrefix("||") else {return []}
		
		let startIdx = stringSource.startIndex
		
		/* We might have plurality overrides. Let's check. */
		guard !stringSource.hasPrefix("|||") else {
			/* We don't. But we must remove one leading "|". */
			stringSource.removeFirst()
			parserHelper.remove(upTo: stringSource.index(after: startIdx), from: &source)
			return []
		}
		
		let pluralityStringStartIdx = stringSource.index(startIdx, offsetBy: 2)
		
		/* We do have plurality override(s)! Is it valid? */
		guard let pluralityEndIdx = stringSource[pluralityStringStartIdx...].range(of: "||", options: [.literal])?.lowerBound else {
			/* Nope. It is not. */
			NSLog("%@", "Got invalid plurality override in string \(source)") /* We used to use HCLogES */
			return []
		}
		
		/* A valid plurality overrides part was found. Let's parse them! */
		let pluralityOverrideStr = stringSource[pluralityStringStartIdx..<pluralityEndIdx]
		let pluralityDefinitions = pluralityOverrideStr.components(separatedBy: "|").map{ $0 == "_" ? defaultPluralityDefinition : PluralityDefinition(string: $0) }
		
		/* Let's remove the plurality definition from the string. */
		let nonPluralityStringStartIdx = stringSource.index(pluralityEndIdx, offsetBy: 2)
		stringSource.removeSubrange(startIdx..<nonPluralityStringStartIdx)
		parserHelper.remove(upTo: nonPluralityStringStartIdx, from: &source)
		
		return pluralityDefinitions
	}
	
}
