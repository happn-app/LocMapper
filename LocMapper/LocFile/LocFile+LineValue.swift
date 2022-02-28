/*
 * LocFile+LineValue.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/4/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension LocFile {
	
	public enum LineValue {
		case mapping(LocKeyMapping)
		case entries([String /* Language */: String /* Value */])
		
		public var mapping: LocKeyMapping? {
			switch self {
				case .mapping(let mapping): return mapping
				default:                    return nil
			}
		}
		
		public var entries: [String: String]? {
			switch self {
				case .entries(let entries): return entries
				default:                    return nil
			}
		}
		
		public func entryForLanguage(_ language: String) -> String? {
			guard let entries = entries else {return nil}
			return entries[language]
		}
	}
	
}
