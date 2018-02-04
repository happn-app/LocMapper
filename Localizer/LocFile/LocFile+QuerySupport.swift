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
		
		guard !envFilters.isEmpty && !stateFilters.isEmpty else {
			return []
		}
		
		return entryKeys.filter{ lineKey -> Bool in
			/* Filter env */
			guard envFilters.contains(lineKey.env) else {return false}
			
			/* Filter state */
			let warning = "todo: state filters"
			
			/* Search filter */
			if !stringFilters.isEmpty {
				for stringFilter in stringFilters {
					let stringComponents = stringFilter.components(separatedBy: ",")
					let keyFilter: String?
					let contentFilter: String
					if let filter = stringComponents.last, stringComponents.count > 1 {
						keyFilter = filter.isEmpty ? nil : filter
						contentFilter = stringComponents[0..<stringComponents.count-2].joined(separator: ",")
					} else {
						keyFilter = nil
						contentFilter = stringFilter
					}
					var keyOk = true
					if let keyFilter = keyFilter {
						keyOk = false
						for k in [lineKey.locKey, lineKey.filename] {
							if k.range(of: keyFilter, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil {
								keyOk = true
								break
							}
						}
					}
					guard keyOk else {return false}
					guard !contentFilter.isEmpty else {return true}
					for l in self.languages {
						let str = editorDisplayedValueForKey(lineKey, withLanguage: l)
						if str.range(of: contentFilter, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil {
							return true
						}
					}
				}
				return false
			}
			return true
		}
	}
	
	public func lineValueForKey(_ key: LineKey) -> LineValue? {
		return entries[key]
	}
	
	public func exportedValueForKey(_ key: LineKey, withLanguage language: String) -> String? {
        let warning = "why replace the \n here?"
        let v = editorDisplayedValueForKey(key, withLanguage: language).replacingOccurrences(of: "\n", with: "\\n")
		return (v != "---" ? v : nil)
	}
	
	public func editorDisplayedValueForKey(_ key: LineKey, withLanguage language: String) -> String {
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
	
	public func resolvedValueForKey(_ key: LineKey, withLanguage language: String) throws -> String {
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
				
			case "s": self = .string(substring)
			case "e": self = .env(substring)
				
			default: return nil
			}
		}
		
		public func toString() -> String {
			switch self {
			case .string(let str):      return "s" + str
			case .env(let env):         return "e" + env
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
		
		public var isStateFilter: Bool {
			return !isStringFilter && !isEnvFilter
		}
	}
	
}
