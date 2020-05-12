/*
 * LocFile+StdRefLoc.swift
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
	
	static let stdReferenceTranslationsFilename = "StandardReferencesTranslations.csv"
	static let stdReferenceTranslationsGroupComment = "••••••••••••••••••••••••••••••••••••• START OF STD REF TRADS — DO NOT MODIFY •••••••••••••••••••••••••••••••••••••"
	static let stdReferenceTranslationsUserReadableComment = "STD REF TRAD. DO NOT MODIFY."
	
	public func mergeRefLocsWithStdRefLocFile(_ stdRefLocFile: StdRefLocFile, mergeStyle: MergeStyle) {
		/* Switching instead of just checking for equality with .replace because
		 * we **want** to err when new merge styles are added later (if ever). */
		switch mergeStyle {
		case .add: (/*nop*/)
		case .replace:
			/* Remove all previous StdRefLoc entries */
			for key in entries.keys {
				guard key.env == "StdRefLoc" else {continue}
				entries.removeValue(forKey: key)
			}
		}
		
		/* Adding languages in reference translations. But not removing languages
		 * not in reference translations! */
		for l in stdRefLocFile.languages {
			if !languages.contains(l) {
				languages.append(l)
			}
		}
		
		/* Import new RefLoc entries */
		var isFirst = entries.keys.contains{ $0.env == "StdRefLoc" }
		for (refKey, refVals) in stdRefLocFile.entries {
			for (language, taggedValues) in refVals {
				for taggedValue in taggedValues {
					let key = LineKey(locKey: refKey.byAppending(tags: taggedValue.tags, sortTags: true), env: "StdRefLoc", filename: LocFile.stdReferenceTranslationsFilename, index: isFirst ? 0 : 1, comment: "", userInfo: [:], userReadableGroupComment: isFirst ? LocFile.stdReferenceTranslationsGroupComment : "", userReadableComment: LocFile.stdReferenceTranslationsUserReadableComment)
					var values = entries[key]?.entries ?? [:]
					values[language] = taggedValue.value
					entries[key] = .entries(values)
				}
			}
			isFirst = false
		}
	}
	
	public func exportStdRefLoc(to path: String, csvSeparator: String) {
		do {
			var stream = try FileHandleOutputStream(forPath: path)
			
			/* Printing header */
			print("KEY".csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)
			for l in languages {print(csvSeparator + l.csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)}
			print("", to: &stream)
			
			/* Printing values */
			for k in entryKeys.sorted() {
				guard k.env == "StdRefLoc" else {continue}
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
