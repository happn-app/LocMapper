/*
 * XibLoc.swift
 * Localizer
 *
 * Created by François Lamboley on 12/7/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



public extension String {
	
	public func applying<ReturnType>(xibLocInfo: XibLocResolvingInfo<String, ReturnType>) throws -> ReturnType {
		return "" as! ReturnType
	}
	
//	internal func parseAsXibLocString(escapeToken: String?, simpleReplacementsToken: [XibLocResolvingInfo.OneWordTokens], orderedReplacementsTokens: [XibLocResolvingInfo.MultipleWordsTokens], pluralGroupsTokens: [XibLocResolvingInfo.MultipleWordsTokens]) throws -> ParsedXibLocString {
//		return ParsedXibLocString()
//	}
	
}

public extension NSAttributedString {
	
	public func applying<ReturnType>(xibLocInfo: XibLocResolvingInfo<NSAttributedString, ReturnType>) throws -> ReturnType {
		return "" as! ReturnType
	}
	
}
