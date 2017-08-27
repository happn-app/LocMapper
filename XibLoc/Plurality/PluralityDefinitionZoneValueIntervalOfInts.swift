/*
 * PluralityDefinitionZoneValueIntervalOfInts.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct PluralityDefinitionZoneValueIntervalOfInts : PluralityDefinitionZoneValue {
	
	init?(string: String) {
		let scanner = Scanner(string: string)
		scanner.charactersToBeSkipped = CharacterSet()
		scanner.locale = nil
		
		var i = 0
		startValue = scanner.scanInt(&i) ? i : nil
		
		guard scanner.scanString("→", into: nil) else {return nil}
		
		endValue = scanner.scanInt(&i) ? i : nil
		guard scanner.isAtEnd else {return nil}
		guard startValue != nil || endValue != nil else {return nil}
		if let start = startValue, let end = endValue, start > end {return nil}
	}
	
	func matches(int n: Int) -> Bool {
		assert(startValue != nil || endValue != nil)
		if let endValue   = endValue   {guard n <= endValue   else {return false}}
		if let startValue = startValue {guard n >= startValue else {return false}}
		return true
	}
	
	func matches(float: Float, precision: Float) -> Bool {
		return false
	}
	
	var debugDescription: String {
		var ret = "PluralityDefinitionZoneValueIntervalOfInts: "
		if let startValue = startValue          {ret.append("start = \(startValue)")}
		if startValue != nil && endValue != nil {ret.append(", ")}
		if let endValue = endValue              {ret.append("end = \(endValue)")}
		return ret
	}
	
	private let startValue, endValue: Int?
	
}
