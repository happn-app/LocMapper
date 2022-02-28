/*
 * LocFile+EditingSupport.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/4/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension LocFile {
	
	public enum MergeStyle {
		
		case replace
		case add
		
	}
	
	/**
	 Converts the given value for the given key to a hard-coded value.
	 The previous mapping for the given key is then dropped (obviously).
	 
	 If the key was not present in the file, nothing is done.
	 
	 - Returns: `true` if the value of the key was indeed a mapping and has been converted,
	 `false` if nothing had to be done (value was already hard-coded or not present). */
	public func convertKeyToHardCoded(_ key: LineKey) -> Bool {
		guard case .mapping? = entries[key] else {
			return false
		}
		
		var values = [String: String]()
		for l in languages {
			values[l] = editorDisplayedValueForKey(key, withLanguage: l)
		}
		
		entries[key] = .entries(values)
		return true
	}
	
	/**
	 Sets the given value for the given key and language.
	 
	 - Important: If the key had a mapping, the mapping is **dropped**.
	 
	 - Returns: `true` if the key had to be added to the list of entries, `false` if the key was already present and was only modified. */
	public func setValue(_ val: String, forKey key: LineKey, withLanguage language: String) -> Bool {
		let created: Bool
		var entriesForKey: [String: String]
		if case .entries(let e)? = entries[key] {created = false;               entriesForKey = e}
		else                                    {created = entries[key] == nil; entriesForKey = [:]}
		entriesForKey[language] = val
		entries[key] = .entries(entriesForKey)
		return created
	}
	
	/**
	 Sets the given mapping for the given key.
	 
	 - Important: All of the non-mapped values will be dropped for the given key.
	 
	 - Returns: `true` if the key had to be added to the list of entries, `false` if the key was already present and was only modified. */
	func setValue(_ val: LocKeyMapping, forKey key: LineKey) -> Bool {
		let created = (entries[key] == nil)
		entries[key] = .mapping(val)
		return created
	}
	
	/**
	 Sets the given value for the given key.
	 
	 - Returns: `true` if the key had to be added to the list of entries, `false` if the key was already present and was only modified. */
	public func setValue(_ val: LineValue, forKey key: LineKey) -> Bool {
		let created = (entries[key] == nil)
		entries[key] = val
		return created
	}
	
}
