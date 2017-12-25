/*
 * ParserHelpers+AttributedString.swift
 * XibLoc
 *
 * Created by François Lamboley on 12/11/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct NSMutableAttributedStringSourceTypeHelper : SourceTypeHelper {
	
	/* While the NSAttributedString is not “Swifted” to support let/var, we
	 * prefer dealing with mutable attributed string directly for performance
	 * reasons. */
	typealias SourceType = NSMutableAttributedString
	
	static func stringRepresentation(of source: NSMutableAttributedString) -> String {
		return source.string
	}
	
	static func remove<R>(strRange: (r: R, s: String), from source: inout NSMutableAttributedString) where R : RangeExpression, R.Bound == String.Index {
		assert(strRange.s == source.string)
		
		let nsrange = NSRange(strRange.r, in: strRange.s)
		source.replaceCharacters(in: nsrange, with: "")
	}
	
	static func replace<R>(strRange: (r: R, s: String), with replacement: NSMutableAttributedString, in source: inout NSMutableAttributedString) -> String where R : RangeExpression, R.Bound == String.Index {
		assert(strRange.s == source.string)
		
		let nsrange = NSRange(strRange.r, in: strRange.s)
		source.replaceCharacters(in: nsrange, with: replacement)
		
		return replacement.string
	}
	
}



struct NSMutableAttributedStringReturnTypeHelper : ReturnTypeHelper {
	
	typealias ReturnType = NSMutableAttributedString
	
	static func slice<R>(strRange: (r: R, s: String), from source: NSMutableAttributedString) -> NSMutableAttributedString where R : RangeExpression, R.Bound == String.Index {
		assert(strRange.s == source.string)
		let nsrange = NSRange(strRange.r, in: strRange.s)
		return NSMutableAttributedString(attributedString: source.attributedSubstring(from: nsrange))
	}
	
	static func remove<R>(strRange: (r: R, s: String), from source: inout NSMutableAttributedString) where R : RangeExpression, R.Bound == String.Index {
		assert(strRange.s == source.string)
		
		let nsrange = NSRange(strRange.r, in: strRange.s)
		source.replaceCharacters(in: nsrange, with: "")
	}
	
	static func replace<R>(strRange: (r: R, s: String), with replacement: NSMutableAttributedString, in source: inout NSMutableAttributedString) -> String where R : RangeExpression, R.Bound == String.Index {
		return NSMutableAttributedStringSourceTypeHelper.replace(strRange: strRange, with: replacement, in: &source)
	}
	
}
