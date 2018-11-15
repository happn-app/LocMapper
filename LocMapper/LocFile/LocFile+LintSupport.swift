/*
 * LocFile+LintSupport.swift
 * LocMapper
 *
 * Created by François Lamboley on 14/11/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation




extension LocFile {
	
	public enum LintReport {
		
		case unlocalizedFilename(String)
		case invalidMapping(LineKey)
		case unusedRefLoc(LineKey)
		
		case unmappedVariant(base: LineKey, key: LineKey)
		
		case notLatestKeyVersion(currentKey: LineKey, expectedKey: LineKey)
		case multipleKeyVersionsMapped([LineKey])
		
	}
	
	public func lint(detectUnusedRefLoc: Bool) -> [LintReport] {
		var ret = [LintReport]()
		
		let allStrEnvs = Set(entryKeys.map{ $0.env })
		let allEnvironments = allStrEnvs.map{ Filter.env($0) }
		let allNonRefLocEnvironments = allStrEnvs.filter{ !$0.contains("RefLoc") }.map{ Filter.env($0) }
		let allRefLocKeys = Set(entryKeys(matchingFilters: [.env("RefLoc"), .uiPresentable, .uiHidden, .stateTodoloc, .stateHardCodedValues, .stateMappedValid, .stateMappedInvalid]))
		let allNonRefLocKeys = Set(entryKeys(matchingFilters: allNonRefLocEnvironments + [.uiPresentable, .uiHidden, .stateTodoloc, .stateHardCodedValues, .stateMappedValid, .stateMappedInvalid]))
		let usedKeys = Set(entryKeys(matchingFilters: allEnvironments + [.uiPresentable, .stateMappedValid]).flatMap{
			lineValueForKey($0)!.mapping!.linkedKeys
		})
		let untaggedUsedKeys = Set<LineKey>(usedKeys.map{
			if $0.env == "StdRefLoc" {return LineKey(copying: $0, newLocKey: TaggedString(string: $0.locKey).value)}
			else                     {return $0}
		})
		
		/* Group RefLoc keys that have the same root, but different variants. For
		 * instance:
		 *    ‘hello"gf' and 'hello"gm' have the same 'hello' root, and the 'gf'
		 *    and 'gm' variants. They’ll be grouped as
		 *       ['hello': [‘hello"gf', 'hello"gm']] */
		var groupedTaggedRefLocKeys = [LineKey: Set<LineKey>]()
		allRefLocKeys.forEach{
			if $0.env == "StdRefLoc" {
				let parsed = TaggedString(string: $0.locKey)
				groupedTaggedRefLocKeys[LineKey(copying: $0, newLocKey: parsed.value), default: []].insert($0)
			} else {
				assert(groupedTaggedRefLocKeys[$0] == nil)
				groupedTaggedRefLocKeys[$0] = Set(arrayLiteral: $0)
			}
		}
		let allUntaggedRefLocKeys = Set(groupedTaggedRefLocKeys.keys)
		
		/* Group the **untagged** RefLoc keys by versions. For instance:
		 *    'hello' and 'hello#2' are two different versions of the 'hello' key.
		 *    They’ll be grouped as (ordered)
		 *       ['hello': ['hello', 'hello#2']]
		 *    'hello' and 'hello#1a' are two different keys altogether (1a is not
		 *    a valid number). */
		var groupedOctothorpedUntaggedRefLocKeys = [LineKey: [LineKey]]()
		do {
			func parseOctothorpedKey(_ keyStr: String) -> (String, Int)? {
				let parts = keyStr.split(separator: "#")
				guard parts.count > 1 else {return nil}
				
//				if parts.count > 2 {/* TODO: Add suspicious RefLoc key report */}
				
				let baseStr = parts.dropLast().joined(separator: "#")
				let numberStr = parts.last!.trimmingCharacters(in: .whitespaces)
				guard let number = Int(numberStr) else {
					/* TODO: Add suspicious RefLoc key report */
					return nil
				}
				
				return (baseStr, number)
			}
			
			var toProcess = allUntaggedRefLocKeys
			while let key = toProcess.first {
				let base: LineKey
				let value: [LineKey]
				
				if let (baseStr, _) = parseOctothorpedKey(key.locKey) {
					var matches = [(LineKey, Int)]()
					for k in allUntaggedRefLocKeys.filter({ $0.locKey.hasPrefix(baseStr) }) {
						let minusBase = k.locKey.dropFirst(baseStr.count)
						if minusBase.isEmpty {
							matches.append((k, 1))
						} else if minusBase.first == "#" {
							let numberStr = minusBase.dropFirst().trimmingCharacters(in: .whitespaces)
							guard let number = Int(numberStr) else {
								/* TODO: Add suspicious RefLoc key report */
								continue
							}
							matches.append((k, number))
						} else {
							/* TODO: Add suspicious RefLoc key report */
						}
					}
					/* TODO: Detect cases where two matches have the same index */
					base = LineKey(copying: key, newLocKey: baseStr)
					value = matches.sorted(by: { $0.1 < $1.1 }).map{ $0.0 }
				} else {
					base = key
					value = [key]
				}
				
				groupedOctothorpedUntaggedRefLocKeys[base] = value
				toProcess.subtract(value)
			}
		}
		
		/* *** Detect keys whose filename is not localized *** */
		for f in Set(allNonRefLocKeys.map({ $0.filename })) {
			if !f.contains("//LANGUAGE//") {
				ret.append(.unlocalizedFilename(f))
			}
		}
		
		/* *** Detect invalid mappings *** */
		for k in entryKeys(matchingFilters: allEnvironments + [.uiPresentable, .stateMappedInvalid]) {
			ret.append(.invalidMapping(k))
		}
		
		/* *** Detect unused RefLoc keys (if asked) *** */
		if detectUnusedRefLoc {
			let refLocKeys = Set(entryKeys(matchingFilters: [.env("RefLoc"), .uiPresentable, .stateTodoloc, .stateHardCodedValues]))
			for k in refLocKeys.subtracting(usedKeys) {
				ret.append(.unusedRefLoc(k))
			}
		}
		
		/* *** Detect unmapped variant for StdRefLoc mappings *** */
		for (untaggedBase, taggedVariants) in groupedTaggedRefLocKeys {
			let i = usedKeys.intersection(taggedVariants)
			let c = i.count
			if c > 0 && c < taggedVariants.count {
				ret.append(contentsOf: taggedVariants.subtracting(i).map{ LintReport.unmappedVariant(base: untaggedBase, key: $0) })
			}
		}
		
		/* *** Detect latest mapped RefLoc version *** */
		for (_, octothorpedUntaggedVersions) in groupedOctothorpedUntaggedRefLocKeys {
			let i = untaggedUsedKeys.intersection(octothorpedUntaggedVersions)
			switch i.count {
			case 1:
				let mapped = i.first!
				let expected = octothorpedUntaggedVersions.last!
				if mapped != expected {
					ret.append(.notLatestKeyVersion(currentKey: mapped, expectedKey: expected))
				}
				
			case 2...:
				ret.append(.multipleKeyVersionsMapped(Array(i)))
				
			default: (/*nop*/)
			}
		}
		
		return ret
	}
	
}
