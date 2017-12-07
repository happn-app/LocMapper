/*
 * ParserHelper.swift
 * XibLoc
 *
 * Created by François Lamboley on 9/3/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



protocol ParserHelper {
	
	/** The source type can be anything. Usually it will be a String or an
	NSMutableString. */
	associatedtype SourceType
	
	/** Convert the source to its string representation. The conversion should be
	a surjection. Also, you must be able to manipulate your SourceType with the
	indexes of the given string. */
	func stringRepresentation(of source: SourceType) -> String
	
	func slice<R>(range: R, from source: SourceType) -> SourceType where R : RangeExpression, R.Bound == String.Index
	func remove<R>(range: R, from source: inout SourceType) where R : RangeExpression, R.Bound == String.Index
	
}

struct StringParserHelper : ParserHelper {
	
	typealias SourceType = String
	
	func stringRepresentation(of source: String) -> String {
		return source
	}
	
	func slice<R>(range: R, from source: String) -> String where R : RangeExpression, R.Bound == String.Index {
		return String(source[range])
	}
	
	func remove<R>(range: R, from source: inout SourceType) where R : RangeExpression, R.Bound == String.Index {
		source.removeSubrange(range)
	}
	
}
