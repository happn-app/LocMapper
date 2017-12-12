/*
 * ParserHelpers+String.swift
 * XibLoc
 *
 * Created by François Lamboley on 12/11/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct StringSourceTypeHelper : SourceTypeHelper {
	
	typealias SourceType = String
	
	static func stringRepresentation(of source: String) -> String {
		return source
	}
	
	static func remove<R>(strRange: (r: R, s: String), from source: inout String) where R : RangeExpression, R.Bound == String.Index {
		assert(strRange.s == source)
		source.removeSubrange(strRange.r)
	}
	
	static func replace<R>(strRange: (r: R, s: String), with replacement: String, in source: inout String) -> String where R : RangeExpression, R.Bound == String.Index {
		assert(strRange.s == source)
		source.replaceSubrange(strRange.r, with: replacement)
		return replacement
	}
	
}



struct StringReturnTypeHelper : ReturnTypeHelper {
	
	typealias ReturnType = String
	
	static func slice<R>(strRange: (r: R, s: String), from source: ReturnType) -> ReturnType where R : RangeExpression, R.Bound == String.Index {
		print(strRange.s)
		print(source)
		assert(strRange.s == source)
		return String(source[strRange.r])
	}
	
	static func replace<R>(strRange: (r: R, s: String), with replacement: ReturnType, in source: inout ReturnType) -> String where R : RangeExpression, R.Bound == String.Index {
		return StringSourceTypeHelper.replace(strRange: strRange, with: replacement, in: &source)
	}
	
}
