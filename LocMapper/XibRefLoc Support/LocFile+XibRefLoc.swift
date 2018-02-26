/*
 * LocFile+RefLoc.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension LocFile {
	
	static let referenceTranslationsFilename = "ReferencesTranslations.csv"
	static let referenceTranslationsGroupComment = "••••••••••••••••••••••••••••••••••••• START OF REF TRADS — DO NOT MODIFY •••••••••••••••••••••••••••••••••••••"
	static let referenceTranslationsUserReadableComment = "REF TRAD. DO NOT MODIFY."
	
	func replaceRefLocsWithXibRefLocFile(_ xibRefLocFile: XibRefLocFile) {
		/* Remove all previous RefLoc entries */
		for key in entries.keys {
			guard key.env == "RefLoc" else {continue}
			entries.removeValue(forKey: key)
		}
		
		/* Adding languages in reference translations. But not removing languages
		 * not in reference translations! */
		for l in xibRefLocFile.languages {
			if !languages.contains(l) {
				languages.append(l)
			}
		}
		
		/* Import new RefLoc entries */
		var isFirst = true
		for (refKey, refVals) in xibRefLocFile.entries {
			let key = LineKey(locKey: refKey, env: "RefLoc", filename: LocFile.referenceTranslationsFilename, index: isFirst ? 0 : 1, comment: "", userInfo: [:], userReadableGroupComment: isFirst ? LocFile.referenceTranslationsGroupComment : "", userReadableComment: LocFile.referenceTranslationsUserReadableComment)
			entries[key] = .entries(refVals)
			isFirst = false
		}
	}
	
	public func mergeRefLocsWithXibRefLocFile(_ xibRefLocFile: XibRefLocFile) {
		/* Adding languages in reference translations. But not removing languages
		 * not in reference translations! */
		for l in xibRefLocFile.languages {
			if !languages.contains(l) {
				languages.append(l)
			}
		}
		
		/* Import new RefLoc entries */
		var isFirst = entryKeys.contains{ $0.env == "RefLoc" }
		for (refKey, refVals) in xibRefLocFile.entries {
			let key = LineKey(locKey: refKey, env: "RefLoc", filename: LocFile.referenceTranslationsFilename, index: isFirst ? 0 : 1, comment: "", userInfo: [:], userReadableGroupComment: isFirst ? LocFile.referenceTranslationsGroupComment : "", userReadableComment: LocFile.referenceTranslationsUserReadableComment)
			entries[key] = .entries(refVals)
			isFirst = false
		}
	}
	
}
