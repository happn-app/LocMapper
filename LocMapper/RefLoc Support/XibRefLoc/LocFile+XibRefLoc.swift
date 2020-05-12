/*
 * LocFile+XibRefLoc.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

import Logging



extension LocFile {
	
	static let xibReferenceTranslationsFilename = "ReferencesTranslations.csv"
	static let xibReferenceTranslationsGroupComment = "••••••••••••••••••••••••••••••••••••• START OF XIB REF TRADS — DO NOT MODIFY •••••••••••••••••••••••••••••••••••••"
	static let xibReferenceTranslationsUserReadableComment = "XIB REF TRAD. DO NOT MODIFY."
	
	public func mergeRefLocsWithXibRefLocFile(_ xibRefLocFile: XibRefLocFile, mergeStyle: MergeStyle) {
		/* Switching instead of just checking for equality with .replace because
		 * we **want** to err when new merge styles are added later (if ever). */
		switch mergeStyle {
		case .add: (/*nop*/)
		case .replace:
			/* Remove all previous XibRefLoc entries */
			for key in entries.keys {
				guard key.env == "RefLoc" else {continue}
				entries.removeValue(forKey: key)
			}
		}
		
		/* Adding languages in reference translations. But not removing languages
		 * not in reference translations! */
		for l in xibRefLocFile.languages {
			if !languages.contains(l) {
				languages.append(l)
			}
		}
		
		/* Import new XibRefLoc entries */
		var isFirst = entryKeys.contains{ $0.env == "RefLoc" }
		for (refKey, refVals) in xibRefLocFile.entries {
			let key = LineKey(locKey: refKey, env: "RefLoc", filename: LocFile.xibReferenceTranslationsFilename, index: isFirst ? 0 : 1, comment: "", userInfo: [:], userReadableGroupComment: isFirst ? LocFile.xibReferenceTranslationsGroupComment : "", userReadableComment: LocFile.xibReferenceTranslationsUserReadableComment)
			for (l, v) in refVals {
				let curValue = entries[key]
				switch curValue {
				case .entries(var curEntries)?: curEntries[l] = v; entries[key] = .entries(curEntries)
				case .mapping?:                 entries[key] = .entries(refVals); /* Or manage an error, depending on the error management we want… */
				case nil:                       entries[key] = .entries(refVals)
				}
			}
			isFirst = false
		}
	}
	
	public func exportXibRefLoc(to path: String, csvSeparator: String) {
		do {
			var stream = try FileHandleOutputStream(forPath: path)
			
			/* Printing header */
			print("KEY".csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)
			for l in languages {print(csvSeparator + l.csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)}
			print("", to: &stream)
			
			/* Printing values */
			for k in entryKeys.sorted() {
				guard k.env == "RefLoc" else {continue}
				print(k.locKey.csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)
				for l in languages {print(csvSeparator + (exportedValueForKey(k, withLanguage: l) ?? "---").csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)}
				print("", to: &stream)
			}
		} catch {
			#if canImport(os)
				LocMapperConfig.oslog.flatMap{ os_log("Cannot write file to path %@, got error %@", log: $0, type: .error, path, String(describing: error)) }
			#endif
			LocMapperConfig.logger?.error("Cannot write file to path \(path), got error \(String(describing: error))")
		}
	}
	
}
