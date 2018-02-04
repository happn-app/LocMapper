/*
 * LocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/26/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation
import os.log



/* Note: Should probably be a struct... */
public class LocFile {
	
	public let csvSeparator: String
	internal var metadata: [String: String]
	
	public internal(set) var languages: [String]
	internal var entries: [LineKey: LineValue]
	public var entryKeys: [LineKey] {
		return Array(entries.keys)
	}
	
	/* ********************
	   MARK: - Initializers
	   ******************** */
	
	/* *** Init *** */
	init(languages l: [String], entries e: [LineKey: LineValue], metadata md: Any?, csvSeparator csvSep: String) {
		if csvSep.utf16.count != 1 {NSException(name: NSExceptionName(rawValue: "Invalid Separator"), reason: "Cannot use \"\(csvSep)\" as a CSV separator", userInfo: nil).raise()}
		csvSeparator = csvSep
		languages = l
		entries = e
		metadata = md as? [String: String] ?? [:]
	}
	
	/** Remove the references to a language from the given path and add the
	language found in the list of known languages in the LocFile.
	
	- Returns: A tuple of the language agnostic filename and the found language
	name*/
	func getLanguageAgnosticFilenameAndAddLanguageToList(_ filename: String, withMapping languageMapping: [String: String]) -> (String, String) {
		var found = false
		var languageName = "(Unknown)"
		var filenameNoLproj = filename
		
		for (fn, ln) in languageMapping {
			if let range = filenameNoLproj.range(of: "/" + fn + "/") {
				assert(!found)
				found = true
				
				languageName = ln
				filenameNoLproj.replaceSubrange(range, with: "//LANGUAGE//")
			}
		}
		
		if languages.index(of: languageName) == nil {
			languages.append(languageName)
			languages.sort()
		}
		
		return (filenameNoLproj, languageName)
	}
	
	/** Search the given key in the keys already in the LocFile.
	
	If the key is not already present in the file, simple add it to the keys in
	the file and return it.
	
	If the key is already in the file, try and merge the comments and user info
	from the key given in argument and return the merged key, after updating the
	keys registered in the file.
	
	- Returns: Either the original key, or a merge of the corresponding existing
	key in the already known keys with the one given in argument. */
	func getKeyFrom(_ refKey: LineKey, useNonEmptyCommentIfOneEmptyTheOtherNot: Bool, withListOfKeys keys: inout [LineKey]) -> LineKey {
		if let idx = keys.index(of: refKey) {
			if keys[idx].comment != refKey.comment {
				if useNonEmptyCommentIfOneEmptyTheOtherNot && (keys[idx].comment.isEmpty || refKey.comment.isEmpty) {
					/* We use the non-empty comment because one of the two comments
					 * compared is empty; the other not (both are different and one
					 * of them is empty) */
					if keys[idx].comment.isEmpty {
						let newKey = LineKey(
							locKey: keys[idx].locKey, env: keys[idx].env, filename: keys[idx].filename,
							index: keys[idx].index, comment: refKey.comment, userInfo: refKey.userInfo /* We might need a more delicate merging handling for the userInfo... */,
							userReadableGroupComment: refKey.userReadableGroupComment,
							userReadableComment: refKey.userReadableComment
						)
						keys[idx] = newKey
					}
				} else {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got different comment for same loc key \"%@\" (file %@): \"%@\" and \"%@\"", log: $0, type: .info, refKey.locKey, refKey.filename, keys[idx].comment, refKey.comment) }}
					else                        {NSLog("Got different comment for same loc key \"%@\" (file %@): \"%@\" and \"%@\"", refKey.locKey, refKey.filename, keys[idx].comment, refKey.comment)}
				}
			}
			return keys[idx]
		}
		keys.append(refKey)
		return refKey
	}
	
}
