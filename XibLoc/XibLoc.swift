/*
 * XibLoc.swift
 * Localizer
 *
 * Created by François Lamboley on 12/7/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



public class XibLocHelper {
	
	public struct XibLocResolvingInfo {
		
		struct OneWordTokens : Hashable {
			
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

			var hashValue: Int
			static func ==(lhs: OneWordTokens, rhs: OneWordTokens) -> Bool {
				return lhs.leftToken == rhs.leftToken && lhs.rightToken == rhs.rightToken
			}
		}
		
		struct MultipleWordsTokens : Hashable {
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
			
			var hashValue: Int
			static func ==(lhs: MultipleWordsTokens, rhs: MultipleWordsTokens) -> Bool {
				return lhs.leftToken == rhs.leftToken && lhs.interiorToken == rhs.interiorToken && lhs.rightToken == rhs.rightToken
			}
		}

		let escapeToken: String
		
		let simpleReplacements: [OneWordTokens: String]
		let orderedReplacements: [MultipleWordsTokens: Int]
		let pluralGroups: [MultipleWordsTokens: Int]
		
	}
	
	struct ParsedXibLocString {
		
		
		
	}
	
	private class func parse(xibLocString: String, escapeToken: String, simpleReplacementsToken: [XibLocResolvingInfo.OneWordTokens], orderedReplacementsTokens: [XibLocResolvingInfo.MultipleWordsTokens], pluralGroupsTokens: [XibLocResolvingInfo.MultipleWordsTokens]) throws -> ParsedXibLocString {
		return ParsedXibLocString()
	}
	
	private class func resolve(parsedXibLocString: ParsedXibLocString, simpleReplacementsValues: [String], orderedReplacementsValues: [Int], pluralGroupsValues: [Int]) -> String {
		return ""
	}
	
	public class func resolve(xibLocString: String, resolvingInfo: XibLocResolvingInfo) throws -> String {
		return ""
	}
	
//	class func
//	+ (id)stringByParsingXibComplexLocString:(id)baseString escapeToken:(NSString *)escape
//	simpleReplacementSeparators:(NSOrderedSet *)srs values:(NSArray<NSString *> *)srsValues /* Values are NSStrings */
//	orderedReplacementSeparators:(NSOrderedSet *)ores interiorSeparators:(NSOrderedSet *)oris values:(NSArray<NSNumber *> *)orsValues /* Values are NSNumbers (index of the value to take; first is 0) */
//	pluralGroupExteriorSeparators:(NSOrderedSet *)pges interiorSeparators:(NSOrderedSet *)pgis defaultPluralityDefinition:(NSString *)dpd values:(NSArray<NSNumber *> *)pgsValues /* Values are NSNumbers (the value against which to check for singular, dual or plural form) */;
	
}
