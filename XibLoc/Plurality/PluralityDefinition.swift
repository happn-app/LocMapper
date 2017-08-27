/*
 * PluralityDefinition.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct PluralityDefinition : CustomDebugStringConvertible {
	
	let zones: [PluralityDefinitionZone]
	
	/* Parse the plurality string to create a plurality definition. The parsing
	 * is forgiving: messages are printed in the logs if there are syntax errors. */
	init(string: String) {
		let scanner = Scanner(string: string)
		scanner.charactersToBeSkipped = CharacterSet()
		
		var idx = 0
		var zonesBuilding = [PluralityDefinitionZone]()
		repeat {
			var garbage: NSString?
			if scanner.scanUpTo("(", into: &garbage) {
				/* We used to use HCLogES */
				NSLog("%@", "Got garbage (\(garbage!)) while parsing plurality definition string \(string). Ignoring...")
			}
			
			guard scanner.scanString("(", into: nil) else {break}
			
			var curZoneStrMinusOpeningParenthesis: NSString?
			guard scanner.scanUpTo("(", into: &curZoneStrMinusOpeningParenthesis) else {
				/* We used to use HCLogES */
				NSLog("%@", "Got malformed plurality definition string \(string). Attempting to continue anyway...")
				continue
			}
			
			if let curZone = PluralityDefinitionZone(string: "(" + (curZoneStrMinusOpeningParenthesis! as String), index: idx) {
				zonesBuilding.append(curZone)
				idx += 1
			} else {
				/* We used to use HCLogES */
				NSLog("%@", "Got zone str (\(curZoneStrMinusOpeningParenthesis!), which I cannot parse into a zone")
			}
		} while !scanner.isAtEnd
		
		/* We sort the zones in order to optimize the removal of zones if needed
		 * when computing the version index to use for a given value. */
		zones = zonesBuilding.reversed().stableSorted { (obj1, obj2) -> Bool? in
			if obj1.optionalityLevel > obj2.optionalityLevel {return true}
			if obj1.optionalityLevel < obj2.optionalityLevel {return false}
			return nil
		}
	}
	
	func indexOfVersionToUse(forValue int: Int, numberOfVersions: Int) -> Int {
		return indexOfVersionToUse(matchingZonePredicate: { $0.matches(int: int) }, numberOfVersions: numberOfVersions)
	}
	
	func indexOfVersionToUse(forValue float: Float, precision: Float, numberOfVersions: Int) -> Int {
		return indexOfVersionToUse(matchingZonePredicate: { $0.matches(float: float, precision: precision) }, numberOfVersions: numberOfVersions)
	}
	
	var debugDescription: String {
		var ret = "PluralityDefinition: (\n"
		zones.forEach{ ret.append("   \($0)\n") }
		ret.append(")")
		return ret
	}
	
	private func indexOfVersionToUse(matchingZonePredicate: (PluralityDefinitionZone) -> Bool, numberOfVersions: Int) -> Int {
		assert(numberOfVersions > 0)
		
		let matchingZones = zonesToTest(for: numberOfVersions).filter(matchingZonePredicate)
		
		if matchingZones.isEmpty {
//			HCLogIS("No zones matched for given predicate in plurality definition \(self). Returning latest version.")
			return numberOfVersions-1
		}
		
		return adjust(zoneIndex: bestMatchingZone(from: matchingZones).index, fromRemovalsDueToNumberOfVersions: numberOfVersions)
	}
	
	private func zonesToTest(for numberOfVersions: Int) -> [PluralityDefinitionZone] {
		guard zones.count > numberOfVersions else {return zones}
		
		/* The zones are already sorted in a way that we can do the trick below. */
		let sepIdx = zones.count - numberOfVersions
		if zones[sepIdx-1].optionalityLevel == 0 {
			/* We used to use HCLogWS */
			NSLog("%@", "Had to remove at least one non-optional zone in plurality definition \(self) in order to get version idx for \(numberOfVersions) version(s).")
		}
		return Array(zones[sepIdx..<zones.endIndex])
	}
	
	private func adjust(zoneIndex: Int, fromRemovalsDueToNumberOfVersions nVersions: Int) -> Int {
		guard zones.count > nVersions else {return zoneIndex}
		
		let sepIdx = zones.count - nVersions
		return zones[0..<sepIdx].reduce(zoneIndex) { (curIdx, zone) -> Int in
			if zone.index < zoneIndex {return curIdx - 1}
			return curIdx
		}
	}
	
	private func bestMatchingZone(from matchingZones: [PluralityDefinitionZone]) -> PluralityDefinitionZone {
		return matchingZones.sorted { (obj1, obj2) -> Bool in
			if obj1.priorityDecreaseLevel < obj2.priorityDecreaseLevel {return true}
			if obj1.priorityDecreaseLevel > obj2.priorityDecreaseLevel {return false}
			if obj1.index < obj2.index {return true}
			if obj1.index > obj2.index {return false}
			fatalError("***** INTERNAL ERROR: Got two matching zones with the same index (\(obj1) and \(obj2) in plurality description \(self). This should not be possible!")
		}.first!
	}
	
}
