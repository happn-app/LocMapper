/*
 * LocFile+QuerySupport.swift
 * LocMapper
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
		let stringFilters = filters.compactMap{ filter -> (key: String, content: String)? in
			if case .string(let str) = filter, !str.isEmpty {
				/* A string filter is a key and value filter. The two of them should
				 * be joined with a comma (eg. “value_filter,key_filter”).
				 * If the string filter does not contain a comma, it is considered
				 * to be a single value filter. If it has more than one comma,
				 * everything after the last one is the key filter, the rest is the
				 * value filter. */
				let keyFilter: String
				let contentFilter: String
				let stringComponents = str.components(separatedBy: ",")
				if let filter = stringComponents.last, stringComponents.count > 1 {
					keyFilter = filter
					contentFilter = stringComponents.dropLast().joined(separator: ",")
				} else {
					keyFilter = ""
					contentFilter = str
				}
				return (key: keyFilter, content: contentFilter)
			}
			return nil
		}
		
		let envFilters: Set<String>
		let envFiltersRaw = Set(filters.compactMap{ filter -> String? in
			if case .env(let env) = filter {return env}
			return nil
		})
		if envFiltersRaw.contains("RefLoc") {envFilters = envFiltersRaw.union(["StdRefLoc", "XibRefLoc"])}
		else                                {envFilters = envFiltersRaw}
		
		let showStateTodoloc = filters.contains{ $0.isStateTodolocCase }
		let showStateHardCoded = filters.contains{ $0.isStateHardCodedValuesCase }
		let showStateMappedValid = filters.contains{ $0.isStateMappedValidCase }
		let showStateMappedInvalid = filters.contains{ $0.isStateMappedInvalidCase }
		
		let showUIHidden = filters.contains{ $0.isUIHiddenCase }
		let showUIPresentable = filters.contains{ $0.isUIPresentableCase }
		
		guard
			(showStateTodoloc || showStateHardCoded || showStateMappedValid || showStateMappedInvalid) &&
			(showUIHidden || showUIPresentable)
		else {return []}
		
		return entryKeys.filter{ lineKey -> Bool in
			/* Env filters */
			guard envFilters.contains(lineKey.env) else {return false}
			
			/* UI filters */
			if !showUIHidden || !showUIPresentable {
				let isUIHidden = (lineKey.env == "Android" && ["o", "s", "c"].contains{ lineKey.locKey.first == $0 })
				guard showUIPresentable ||  isUIHidden else {return false}
				guard showUIHidden      || !isUIHidden else {return false}
			}
			
			/* State and string filters (done in the same block to avoid looping on
			 * entries twice...) */
			if !stringFilters.isEmpty || !showStateTodoloc || !showStateHardCoded || !showStateMappedValid || !showStateMappedInvalid {
				/* Let's process the key filters */
				guard stringFilters.isEmpty || stringFilters.contains(where: { f -> Bool in
					guard !f.key.isEmpty else {return true}
					guard [lineKey.locKey, lineKey.filename].contains(where: { k -> Bool in
						return k.range(of: f.key, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
					}) else {return false}
					return true
				}) else {return false}
				
				/* Now we process the state and the string filters */
				switch entries[lineKey] {
				case .entries(let entries)?:
					/* State filters */
					guard showStateTodoloc || showStateHardCoded else {return false}
					let values = languages.compactMap{ entries[$0] }
					if languages.count != values.count {guard showStateTodoloc   else {return false}}
					else                               {guard showStateHardCoded else {return false}}
					/* String filters */
					guard stringFilters.isEmpty || stringFilters.contains(where: { f -> Bool in
						guard !f.content.isEmpty else {return true}
						guard values.contains(where: { k -> Bool in
							return k.range(of: f.content, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
						}) else {return false}
						return true
					}) else {return false}
					
				case .mapping(let mapping)?:
					/* State filters */
					guard showStateMappedValid || showStateMappedInvalid else {return false}
					let values = languages.compactMap{ try? mapping.apply(forLanguage: $0, entries: entries) }
					if languages.count != values.count {guard showStateMappedInvalid else {return false}}
					else                               {guard showStateMappedValid   else {return false}}
					/* String filters */
					guard stringFilters.isEmpty || stringFilters.contains(where: { f -> Bool in
						guard !f.content.isEmpty else {return true}
						guard values.contains(where: { k -> Bool in
							return k.range(of: f.content, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
						}) else {return false}
						return true
					}) else {return false}
					
				case nil:
					guard showStateTodoloc else {return false}
				}
			}
			
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
			return LocFile.todolocToken
		} catch let error as MappingResolvingError {
			switch error {
			case .invalidMapping, .mappedToMappedKey: return "!¡!TODOLOC_INVALIDMAPPING!¡!"
			case .unknownLanguage:                    return "!¡!TODOLOC_UNKNOWNLANGUAGE!¡!"
			case .keyNotFound:                        return "!¡!TODOLOC_MAPPINGKEYNOTFOUND!¡!"
			case .noValueForLanguage:                 return LocFile.todolocToken
			}
		} catch {
			return LocFile.internalLocMapperErrorToken
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
		case stateTodoloc, stateHardCodedValues /* And, implicitely NOT todoloc */, stateMappedValid, stateMappedInvalid
		
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
		
		public var isUIPresentableCase: Bool {
			guard case .uiPresentable = self else {return false}
			return true
		}
		
		public var isUIHiddenCase: Bool {
			guard case .uiHidden = self else {return false}
			return true
		}
		
		public var isStateTodolocCase: Bool {
			guard case .stateTodoloc = self else {return false}
			return true
		}
		
		public var isStateHardCodedValuesCase: Bool {
			guard case .stateHardCodedValues = self else {return false}
			return true
		}
		
		public var isStateMappedValidCase: Bool {
			guard case .stateMappedValid = self else {return false}
			return true
		}
		
		public var isStateMappedInvalidCase: Bool {
			guard case .stateMappedInvalid = self else {return false}
			return true
		}
		
	}
	
}
