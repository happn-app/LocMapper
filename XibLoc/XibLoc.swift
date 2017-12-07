/*
 * XibLoc.swift
 * Localizer
 *
 * Created by François Lamboley on 12/7/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



public extension String {
	
	public func applying(xibLocInfo: XibLocResolvingInfo<String, String>) throws -> String {
		/* TODO: Cache */
		return ParsedXibLoc(source: self, parserHelper: StringParserHelper(), forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo)
	}
	
	public func applying(xibLocInfo: XibLocResolvingInfo<String, NSAttributedString>) throws -> NSAttributedString {
		/* TODO: Cache */
		return ParsedXibLoc(source: self, parserHelper: StringParserHelper(), forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo)
	}
	
	public func applying(xibLocInfo: XibLocResolvingInfo<NSAttributedString, NSAttributedString>, defaultAttributes: [NSAttributedStringKey: Any]?) throws -> NSAttributedString {
		return try NSAttributedString(string: self, attributes: defaultAttributes).applying(xibLocInfo: xibLocInfo)
	}
	
//	internal func parseAsXibLocString(escapeToken: String?, simpleReplacementsToken: [XibLocResolvingInfo.OneWordTokens], orderedReplacementsTokens: [XibLocResolvingInfo.MultipleWordsTokens], pluralGroupsTokens: [XibLocResolvingInfo.MultipleWordsTokens]) throws -> ParsedXibLocString {
//		return ParsedXibLocString()
//	}
	
}

public extension NSAttributedString {
	
	public func applying(xibLocInfo: XibLocResolvingInfo<NSAttributedString, NSAttributedString>) throws -> NSAttributedString {
		return self
	}
	
}
