/*
 * LocFile+QuerySupport.swift
 * Localizer
 *
 * Created by François Lamboley on 2/4/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension LocFile {
	
	public enum ValueResolvingError : Error {
		case keyNotFound
		case noValueForLanguage
	}
	
	public func hasEntryKey(_ key: LineKey) -> Bool {
		return (entries[key] != nil)
	}
	
	public func entryKeys(matchingFilters filters: [Filter]) -> [LineKey] {
		let stringFilters = filters.flatMap{ filter -> String? in
			if case .string(let str) = filter, !str.isEmpty {return str}
			return nil
		}
		let envFilters = filters.flatMap{ filter -> String? in
			if case .env(let env) = filter {return env}
			return nil
		}
		let stateFilters = filters.filter{ $0.isStateFilter }
		let showUIHidden = filters.contains{ if case .uiHidden = $0 {return true} else {return false} }
		let showUIPresentable = filters.contains{ if case .uiPresentable = $0 {return true} else {return false} }
		
		guard !envFilters.isEmpty && !stateFilters.isEmpty && (showUIHidden || showUIPresentable) else {
			return []
		}
		
		func stringFilter(_ stringFilter: String, match lineKey: LineKey) -> Bool {
			/* A string filter is a key and value filter. The two of them should be
			 * joined with a comma (eg. “value_filter,key_filter”). If the string
			 * filter does not contain a comma, it is considered to be a single
			 * value filter. If it has more than one comma, everything after the
			 * last one is the key filter, the rest is the value filter. */
			let keyFilter: String
			let contentFilter: String
			let stringComponents = stringFilter.components(separatedBy: ",")
			if let filter = stringComponents.last, stringComponents.count > 1 {
				keyFilter = filter
				contentFilter = stringComponents.dropLast().joined(separator: ",")
			} else {
				keyFilter = ""
				contentFilter = stringFilter
			}
			
			/* Let's process the key filter */
			if !keyFilter.isEmpty {
				guard [lineKey.locKey, lineKey.filename].contains(where: { k -> Bool in
					return k.range(of: keyFilter, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
				}) else {return false}
			}
			
			/* Now we process the value filter */
			if !contentFilter.isEmpty {
				guard self.languages.contains(where: { l -> Bool in
					let str = editorDisplayedValueForKey(lineKey, withLanguage: l)
					return str.range(of: contentFilter, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
				}) else {return false}
			}
			
			return true
		}
		
		return entryKeys.filter{ lineKey -> Bool in
			/* Env filters */
			guard envFilters.contains(lineKey.env) else {return false}
			
			/* UI filters */
			if !showUIHidden || !showUIPresentable {
				let isUIHidden = (lineKey.env == "Android" && ["o", "s", "c"].contains{ lineKey.locKey.first == $0 })
				guard showUIPresentable ||  isUIHidden else {return false}
				guard showUIHidden      || !isUIHidden else {return false}
			}
			
			/* State filters */
			let warning = "todo: state filters"
			
			/* Search filters */
			guard stringFilters.isEmpty || stringFilters.contains(where: { f -> Bool in
				stringFilter(f, match: lineKey)
			}) else {return false}
			
			return true
		}
	}
	
	public func lineValueForKey(_ key: LineKey) -> LineValue? {
		return entries[key]
	}
	
	public func exportedValueForKey(_ key: LineKey, withLanguage language: String) -> String? {
		let v = resolvedValueErrorInValueForKey(key, withLanguage: language)
		return (v != "---" ? v : nil)
	}
	
	public func editorDisplayedValueForKey(_ key: LineKey, withLanguage language: String) -> String {
		let v = resolvedValueErrorInValueForKey(key, withLanguage: language)
		return (v != "---" ? v : "(Skipped Value)")
	}
	
	private func resolvedValueErrorInValueForKey(_ key: LineKey, withLanguage language: String) -> String {
		do {
			return try resolvedValueForKey(key, withLanguage: language)
		} catch _ as ValueResolvingError {
			return "!¡!TODOLOC!¡!"
		} catch let error as MappingResolvingError {
			switch error {
			case .invalidMapping, .mappedToMappedKey: return "!¡!TODOLOC_INVALIDMAPPING!¡!"
			case .languageNotFound:                   return "!¡!TODOLOC_LANGUAGENOTFOUND!¡!"
			case .keyNotFound:                        return "!¡!TODOLOC_MAPPINGKEYNOTFOUND!¡!"
			}
		} catch {
			return "!¡!TODOLOC_INTERNALLOCALIZERERROR!¡!"
		}
	}
	
	private func resolvedValueForKey(_ key: LineKey, withLanguage language: String) throws -> String {
		guard let v = entries[key] else {throw ValueResolvingError.keyNotFound}
		switch v {
		case .entries(let entries):
			guard let r = entries[language] else {throw ValueResolvingError.noValueForLanguage}
			return r
			
		case .mapping(let mapping):
			return try mapping.apply(forLanguage: language, entries: entries)
		}
	}
	
	/* *******************
	   MARK: - Filter Enum
	   ******************* */
	
	public enum Filter {
		
		case string(String)
		case env(String)
		case uiPresentable, uiHidden
		case stateTodoloc, stateHardCodedValues, stateMappedValid, stateMappedInvalid
		
		public init?(string: String) {
			guard let first = string.first else {return nil}
			let substring = String(string.dropFirst())
			
			switch first {
			case "t":
				switch substring {
				case "t":  self = .stateTodoloc
				case "v":  self = .stateHardCodedValues
				case "mv": self = .stateMappedValid
				case "mi": self = .stateMappedInvalid
				default: return nil
				}
				
			case "u":
				switch substring {
				case "p":  self = .uiPresentable
				case "h":  self = .uiHidden
				default: return nil
				}
				
			case "s": self = .string(substring)
			case "e": self = .env(substring)
				
			default: return nil
			}
		}
		
		public func toString() -> String {
			switch self {
			case .string(let str):      return "s" + str
			case .env(let env):         return "e" + env
			case .uiPresentable:        return "up"
			case .uiHidden:             return "uh"
			case .stateTodoloc:         return "tt"
			case .stateHardCodedValues: return "tv"
			case .stateMappedValid:     return "tmv"
			case .stateMappedInvalid:   return "tmi"
			}
		}
		
		public var isStringFilter: Bool {
			guard case .string = self else {return false}
			return true
		}
		
		public var isEnvFilter: Bool {
			guard case .env = self else {return false}
			return true
		}
		
		public var isUIFilter: Bool {
			switch self {
			case .uiPresentable, .uiHidden: return true
			default:                        return false
			}
		}
		
		public var isStateFilter: Bool {
			return !isStringFilter && !isEnvFilter && !isUIFilter
		}
		
	}
	
}
