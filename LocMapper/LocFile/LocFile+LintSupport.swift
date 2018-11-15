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
		case invalidMapping(LocFile.LineKey)
		case unusedRefLoc(LocFile.LineKey)
		
		case unmappedVariant(base: LocFile.LineKey, key: LocFile.LineKey)
		
	}
	
	public func lint(detectUnusedRefLoc: Bool) -> [LintReport] {
		var ret = [LintReport]()
		
		let allStrEnvs = Set(entryKeys.map{ $0.env })
		let allEnvironments = allStrEnvs.map{ LocFile.Filter.env($0) }
		let allNonRefLocEnvironments = allStrEnvs.filter{ !$0.contains("RefLoc") }.map{ LocFile.Filter.env($0) }
		let usedKeys = Set(entryKeys(matchingFilters: allEnvironments + [.uiPresentable, .stateMappedValid]).flatMap{
			lineValueForKey($0)!.mapping!.linkedKeys
		})
		var untaggedStdRefLocKeys = [LocFile.LineKey: Set<LocFile.LineKey>]()
		entryKeys(matchingFilters: [.env("StdRefLoc"), .uiPresentable, .uiHidden, .stateTodoloc, .stateHardCodedValues, .stateMappedValid, .stateMappedInvalid]).forEach{
			let parsed = TaggedString(string: $0.locKey)
			untaggedStdRefLocKeys[LocFile.LineKey(copying: $0, newLocKey: parsed.value), default: []].insert($0)
		}
		
		/* *** Detect keys whose filename is not localized *** */
		for f in Set(entryKeys(matchingFilters: allNonRefLocEnvironments + [.uiPresentable, .uiHidden, .stateTodoloc, .stateHardCodedValues, .stateMappedValid, .stateMappedInvalid]).map{ $0.filename }) {
			if !f.contains("//LANGUAGE//") {
				ret.append(.unlocalizedFilename(f))
			}
		}
		
		/* *** Detect invalid mappings *** */
		for k in entryKeys(matchingFilters: allEnvironments + [.uiPresentable, .stateMappedInvalid]) {
			ret.append(.invalidMapping(k))
		}
		
		/* *** Detect unused RefLoc keys *** */
		if detectUnusedRefLoc {
			let refLocKeys = Set(entryKeys(matchingFilters: [.env("RefLoc"), .uiPresentable, .stateTodoloc, .stateHardCodedValues]))
			for k in refLocKeys.subtracting(usedKeys) {
				ret.append(.unusedRefLoc(k))
			}
		}
		
		/* *** Detect unmapped variant for StdRefLoc mappings *** */
		for (untaggedBase, taggedVariants) in untaggedStdRefLocKeys {
			let i = usedKeys.intersection(taggedVariants)
			let c = i.count
			if c > 0 && c < taggedVariants.count {
				ret.append(contentsOf: taggedVariants.subtracting(i).map{ LintReport.unmappedVariant(base: untaggedBase, key: $0) })
			}
		}
		
		/* *** Detect latest mapped RefLoc version *** */
//		print(untaggedStdRefLocKeys)
		
		return ret
	}
	
}
