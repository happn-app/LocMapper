/*
 * SimpleReplacementEngine.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



protocol SimpleReplacementEngine {
	
	associatedtype SourceType
	associatedtype ReturnType

	func apply(on: SourceType) -> ReturnType
	
}

struct AnySimpleReplacementEngine<SourceType, ReturnType> : SimpleReplacementEngine {
	
	func apply(on: SourceType) -> ReturnType {
		return "" as! ReturnType
	}
	
}
