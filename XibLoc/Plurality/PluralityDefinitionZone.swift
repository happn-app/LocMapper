/*
 * PluralityDefinitionZone.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct PluralityDefinitionZone : CustomDebugStringConvertible {
	
	let zoneValues: [PluralityDefinitionZoneValue]
	
	let index: Int
	let optionalityLevel: Int /* 0 is non-optional */
	let priorityDecreaseLevel: Int /* 0 is standard priority; higher is lower priority */
	
	/** Returns a zone that matches anything and have the given index. */
	init(index i: Int = 0, optionalityLevel o: Int = 0, priorityDecreaseLevel p: Int = 0) {
		index = i
		optionalityLevel = o
		priorityDecreaseLevel = p
		zoneValues = [PluralityDefinitionZoneValueGlob(forAnyNumber: ())]
	}
	
	init?(string: String, index i: Int) {
		let scanner = Scanner(string: string)
		scanner.charactersToBeSkipped = CharacterSet()
		
		guard scanner.scanString("(", into: nil) else {return nil}
		
		var zoneContent: NSString?
		guard scanner.scanUpTo(")", into: &zoneContent) else {return nil}
		guard scanner.scanString(")", into: nil) else {return nil}
		
		var optionalities: NSString?
		var priorityDecreases: NSString?
		scanner.scanCharacters(from: CharacterSet(charactersIn: "↓"), into: &priorityDecreases)
		scanner.scanCharacters(from: CharacterSet(charactersIn: "?"), into: &optionalities)
		
		if !scanner.isAtEnd {
			/* We used to use HCLogES */
			NSLog("%@", "Got garbage after end of plurality definition zone string: \((scanner.string as NSString).substring(from: scanner.scanLocation))")
		}
		
		index = i
		optionalityLevel = optionalities?.length ?? 0
		priorityDecreaseLevel = priorityDecreases?.length ?? 0
		
		zoneValues = zoneContent!.components(separatedBy: ":").flatMap{
			let ret: PluralityDefinitionZoneValue?
			if      let v = PluralityDefinitionZoneValueNumber(string: $0)           {ret = v}
			else if let v = PluralityDefinitionZoneValueIntervalOfInts(string: $0)   {ret = v}
			else if let v = PluralityDefinitionZoneValueIntervalOfFloats(string: $0) {ret = v}
			else if let v = PluralityDefinitionZoneValueGlob(string: $0)             {ret = v}
			else                                                                     {ret = nil}
			/* We used to use HCLogES */
			if ret == nil {NSLog("%@", "Cannot parse zone value string \"\($0)\". Skipping...")}
			return ret
		}
	}
	
	func matches(int: Int) -> Bool {
		return zoneValues.first{ $0.matches(int: int) } != nil
	}
	
	func matches(float: Float, precision: Float) -> Bool {
		return zoneValues.first{ $0.matches(float: float, precision: precision) } != nil
	}
	
	var debugDescription: String {
		var ret = "PluralityDefinitionZone (optionality \(optionalityLevel), priority decrease \(priorityDecreaseLevel), zone idx \(index): (\n"
		zoneValues.forEach{ ret.append("      \($0)\n") }
		ret.append("   )")
		return ret
	}
	
}
