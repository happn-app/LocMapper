/*
 * PluralityDefinitionZoneValue.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



protocol PluralityDefinitionZoneValue : CustomDebugStringConvertible {
	
	init?(string: String)
	
	func matches(int: Int) -> Bool
	func matches(float: Float, precision: Float) -> Bool
	
}
