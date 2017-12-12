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
		return ParsedXibLoc(source: self, parserHelper: StringSourceTypeHelper.self, forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo, returnTypeHelperType: StringReturnTypeHelper.self)
	}
	
	public func applying(xibLocInfo: XibLocResolvingInfo<String, NSMutableAttributedString>) throws -> NSMutableAttributedString {
		/* TODO: Cache */
		return ParsedXibLoc(source: self, parserHelper: StringSourceTypeHelper.self, forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo, returnTypeHelperType: NSMutableAttributedStringReturnTypeHelper.self)
	}
	
	public func applying(xibLocInfo: XibLocResolvingInfo<NSMutableAttributedString, NSMutableAttributedString>, defaultAttributes: [NSAttributedStringKey: Any]?) throws -> NSMutableAttributedString {
		return try NSMutableAttributedString(string: self, attributes: defaultAttributes).applyingMutable(xibLocInfo: xibLocInfo)
	}
	
//	internal func parseAsXibLocString(escapeToken: String?, simpleReplacementsToken: [XibLocResolvingInfo.OneWordTokens], orderedReplacementsTokens: [XibLocResolvingInfo.MultipleWordsTokens], pluralGroupsTokens: [XibLocResolvingInfo.MultipleWordsTokens]) throws -> ParsedXibLocString {
//		return ParsedXibLocString()
//	}
	
}

public extension NSAttributedString {
	
	public func applying(xibLocInfo: XibLocResolvingInfo<NSMutableAttributedString, NSMutableAttributedString>) throws -> NSMutableAttributedString {
		if let mutableSelf = self as? NSMutableAttributedString {return try mutableSelf.applying(xibLocInfo: xibLocInfo)}
		else                                                    {return try NSMutableAttributedString(attributedString: self).applying(xibLocInfo: xibLocInfo)}
	}
	
}

public extension NSMutableAttributedString {
	
	public func applyingMutable(xibLocInfo: XibLocResolvingInfo<NSMutableAttributedString, NSMutableAttributedString>) throws -> NSMutableAttributedString {
		return try NSMutableAttributedString(attributedString: self).applying(xibLocInfo: xibLocInfo)
	}
	
}
