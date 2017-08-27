/*
 * XibLocResolvingInfo.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



public struct XibLocResolvingInfo<SourceType, ReturnType> {
	
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
	
	let escapeToken: String?
	
	let simpleReplacements: [OneWordTokens: AnySimpleReplacementEngine<SourceType, ReturnType>]
	let orderedReplacements: [MultipleWordsTokens: Int]
	let pluralGroups: [MultipleWordsTokens: Int]
	 
}
/*
extension XibLocResolvingInfo where SourceType == String, ReturnType == String {
	
	public init(simpleReplacementWithToken token: String, value: String) {
		escapeToken = nil
		simpleReplacements = [OneWordTokens(token: token): value]
		orderedReplacements = [:]
		pluralGroups = [:]
	}
	
}*/
