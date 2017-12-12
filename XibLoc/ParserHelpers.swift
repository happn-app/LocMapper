/*
 * ParserHelper.swift
 * XibLoc
 *
 * Created by François Lamboley on 9/3/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation


/* Note: We might want to merge the source and return type helpers! They already
 *       have the replace method in common. */


protocol SourceTypeHelper {
	
	/** The source type can be anything. Usually it will be a String or an
	NSMutableString. */
	associatedtype SourceType
	
	/* When asked to (remove, replace, whatever) something from the source type,
	 * the given range will always contain a String range, and the corresponding
	 * String from which the range comes from. In theory, the given string should
	 * **always** be the stringRepresentation of the given source. */
	typealias StrRange<R> = (r: R, s: String) where R : RangeExpression, R.Bound == String.Index
	
	/** Convert the source to its string representation. The conversion should be
	a surjection. Also, you must be able to manipulate your SourceType with the
	indexes of the given string. */
	static func stringRepresentation(of source: SourceType) -> String
	
	static func remove<R>(strRange: StrRange<R>, from source: inout SourceType) where R : RangeExpression, R.Bound == String.Index
	static func replace<R>(strRange: StrRange<R>, with replacement: SourceType, in source: inout SourceType) -> String where R : RangeExpression, R.Bound == String.Index
	
}



protocol ReturnTypeHelper {
	
	/** The return type can be anything. Usually it will be a String or an
	NSMutableString. */
	associatedtype ReturnType
	
	/* See description in SourceTypeHelper */
	typealias StrRange<R> = (r: R, s: String) where R : RangeExpression, R.Bound == String.Index
	
	static func slice<R>(strRange: StrRange<R>, from source: ReturnType) -> ReturnType where R : RangeExpression, R.Bound == String.Index
	static func replace<R>(strRange: StrRange<R>, with replacement: ReturnType, in source: inout ReturnType) -> String where R : RangeExpression, R.Bound == String.Index
	
}
