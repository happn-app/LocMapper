/*
 * LocFile.swift
 * LocMapper
 *
 * Created by François Lamboley on 9/26/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

import Logging



/* Note: Should probably be a struct... */
public class LocFile {
	
	internal var metadata: [String: String]
	
	public internal(set) var languages: [String]
	internal var entries: [LineKey: LineValue] {
		didSet {
			/* We could probably be more precise on cache invalidation and
			 * invalidate only what’s needed, but it would have to be done when
			 * setting the new values in the entries directly and we might miss
			 * some places. We do not really need to care about the cache much, so
			 * we invalidate it any time the entries are modified. */
			invalidateCache()
		}
	}
	
	/* Serialization options */
	public enum SerializationStyle : String {
		case csvFriendly = "csv"
		case gitFriendly = "git"
	}
	public var csvSeparator: String {willSet {if newValue.utf16.count != 1 {fatalError("Cannot use \"\(newValue)\" as a CSV separator")}}}
	public var serializationStyle: SerializationStyle
	
	/* ********************
	   MARK: - Initializers
	   ******************** */
	
	/* *** Init *** */
	init(languages l: [String], entries e: [LineKey: LineValue], metadata md: Any?, csvSeparator csvSep: String, serializationStyle ss: SerializationStyle) {
		if csvSep.utf16.count != 1 {fatalError("Cannot use \"\(csvSep)\" as a CSV separator")}
		serializationStyle = ss
		csvSeparator = csvSep
		languages = l
		entries = e
		metadata = md as? [String: String] ?? [:]
	}
	
	public convenience init(csvSeparator csvSep: String = ",") {
		self.init(languages: [], entries: [:], metadata: [:], csvSeparator: csvSep, serializationStyle: .csvFriendly)
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
		
		if languages.firstIndex(of: languageName) == nil {
			languages.append(languageName)
			languages.sort()
		}
		
		return (filenameNoLproj, languageName)
	}
	
	/** Search the given key in the keys already in the LocFile.
	
	If the key is not already present in the file, simply add it to the keys in
	the file and return it.
	
	If the key is already in the file, try and merge the comments and user info
	from the key given in argument and return the merged key, after updating the
	keys registered in the file.
	
	- Returns: Either the original key, or a merge of the corresponding existing
	key in the already known keys with the one given in argument. */
	func getKeyFrom(_ refKey: LineKey, useNonEmptyCommentIfOneEmptyTheOtherNot: Bool, withListOfKeys keys: inout [LineKey]) -> LineKey {
		if let idx = keys.firstIndex(of: refKey) {
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
					#if canImport(os)
						LocMapperConfig.oslog.flatMap{ os_log("Got different comment for same loc key \"%@\" (file %@): \"%@\" and \"%@\"", log: $0, type: .info, refKey.locKey, refKey.filename, keys[idx].comment, refKey.comment) }
					#endif
					LocMapperConfig.logger?.info("Got different comment for same loc key \"\(refKey.locKey)\" (file \(refKey.filename): \"\(keys[idx].comment)\" and \"\(refKey.comment)\"")
				}
			}
			return keys[idx]
		}
		keys.append(refKey)
		return refKey
	}
	
	/* *********************************
	   MARK: - Private (for LintSupport)
	   ********************************* */
	
	internal var cachedEntryKeys: [LineKey]?
	
	internal var cachedAllStrEnvs: Set<String>?
	internal var cachedAllEnvironments: [Filter]?
	internal var cachedAllNonRefLocEnvironments: [Filter]?
	internal var cachedAllRefLocKeys: Set<LineKey>?
	internal var cachedAllNonRefLocKeys: Set<LineKey>?
	
	internal var cachedKeysReferencedInMappings: Set<LineKey>?
	internal var cachedUntaggedKeysReferencedInMappings: Set<LineKey>?
	
	/* Groupped RefLoc keys that have the same root, but different variants. For
	 * instance:
	 *    ‘hello"gf' and 'hello"gm' have the same 'hello' root, and the 'gf'
	 *    and 'gm' variants. They’ll be grouped as
	 *       ['hello': [‘hello"gf', 'hello"gm']] */
	internal var cachedGroupedTaggedRefLocKeys: [LineKey: Set<LineKey>]?
	internal var cachedAllUntaggedRefLocKeys: Set<LineKey>?
	
	/* Groupped **untagged** RefLoc keys by versions. For instance:
	 *    'hello#2' and 'hello' are two different versions of the 'hello' key.
	 *    They’ll be grouped as (in this order)
	 *       ['hello': ['hello', 'hello#2']]
	 *    'hello' and 'hello#1a' are two different keys altogether (1a is not
	 *    a valid number). */
	internal var cachedGroupedOctothorpedUntaggedRefLocKeys: [LineKey: [LineKey]]?
	
	internal func invalidateCache() {
		cachedEntryKeys = nil
		
		cachedAllStrEnvs = nil
		cachedAllEnvironments = nil
		cachedAllNonRefLocEnvironments = nil
		cachedAllRefLocKeys = nil
		cachedAllNonRefLocKeys = nil
		
		cachedKeysReferencedInMappings = nil
		cachedUntaggedKeysReferencedInMappings = nil
		
		cachedGroupedTaggedRefLocKeys = nil
		cachedAllUntaggedRefLocKeys = nil
		
		cachedGroupedOctothorpedUntaggedRefLocKeys = nil
	}
	
}
