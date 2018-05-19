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
	
	/** Converts the given value for the given key to a hard-coded value. The
	previous mapping for the given key is then dropped (obviously).
	
	If the key was not present in the file, nothing is done.
	
	- returns: `true` if the value of the key was indeed a mapping and has been
	converted, `false` if nothing had to be done (value was already hard-coded or
	not present). */
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
	
	/** Sets the given value for the given key and language.
	
	- important: If the key had a mapping, the mapping is **dropped**.
	
	- returns: `true` if the key had to be added to the list of entries, `false`
	if the key was already present and was only modified. */
	public func setValue(_ val: String, forKey key: LineKey, withLanguage language: String) -> Bool {
		let created: Bool
		var entriesForKey: [String: String]
		if case .entries(let e)? = entries[key] {created = false;               entriesForKey = e}
		else                                    {created = entries[key] == nil; entriesForKey = [:]}
		entriesForKey[language] = val
		entries[key] = .entries(entriesForKey)
		return created
	}
	
	/** Sets the given mapping for the given key.
	
	- important: All of the non-mapped values will be dropped for the given key.
	
	- returns: `true` if the key had to be added to the list of entries, `false`
	if the key was already present and was only modified. */
	func setValue(_ val: LocKeyMapping, forKey key: LineKey) -> Bool {
		let created = (entries[key] == nil)
		entries[key] = .mapping(val)
		return created
	}
	
	/** Sets the given value for the given key.
	
	- returns: `true` if the key had to be added to the list of entries, `false`
	if the key was already present and was only modified. */
	public func setValue(_ val: LineValue, forKey key: LineKey) -> Bool {
		let created = (entries[key] == nil)
		entries[key] = val
		return created
	}
	
	/* This enum is only useful for the method below it. */
	public enum MappingTransformation {
		
		public enum MappingKeySource {
			
			case dictionary([String: String])
			case fromCSVFile(URL)
			
			func dictionaryMapping(csvSeparator: String) throws -> [String: String] {
				switch self {
				case .dictionary(let r): return r
				case .fromCSVFile(let url):
					var ret = [String: String]()
					let csvString = try String(contentsOf: url)
					let parser = CSVParser(source: csvString, startOffset: 0, separator: csvSeparator, hasHeader: true, fieldNames: nil)
					guard let rows = parser.arrayOfParsedRows() else {
						throw NSError(domain: "LocFile.MappingTransformation.MappingKeySource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV source: cannot parse CSV"])
					}
					print(parser.fieldNames)
					guard parser.fieldNames.count == 2 else {
						throw NSError(domain: "LocFile.MappingTransformation.MappingKeySource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV source: not exactly two columns"])
					}
					let sourceFieldName = parser.fieldNames[0]
					let destinationFieldName = parser.fieldNames[1]
					for row in rows {
						guard let source = row[sourceFieldName], let destination = row[destinationFieldName] else {
							throw NSError(domain: "LocFile.MappingTransformation.MappingKeySource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV source: no source or destination in one of the lines"])
						}
						ret[source] = destination
					}
					return ret
				}
			}
			
		}
		
		case applyMappingOnKeys(MappingKeySource)
		
	}
	
	public func apply(mappingTransformations: [MappingTransformation], csvSeparator: String) throws {
		guard mappingTransformations.count > 0 else {return}
		
		/* We preprocess the mapping transformations array for faster access later
		 * in the entries loop. */
		let mappingTransformations = try mappingTransformations.map{ v -> MappingTransformation in
			switch v {
			case .applyMappingOnKeys(let source):
				return .applyMappingOnKeys(.dictionary(try source.dictionaryMapping(csvSeparator: csvSeparator)))
			}
		}
		
		entries = try entries.mapValues{ v -> LineValue in
			switch v {
			case .entries: return v
			case .mapping(let mapping):
				for transform in mappingTransformations {
					switch transform {
					case .applyMappingOnKeys(let keyMappingSource):
						let keyMapping = try keyMappingSource.dictionaryMapping(csvSeparator: csvSeparator)
						mapping.components = mapping.components?.map{ component -> LocKeyMappingComponent in
							switch component {
							case let valueTransforms as LocKeyMappingComponentValueTransforms:
								return LocKeyMappingComponentValueTransforms(
									sourceKey: LineKey(copying: valueTransforms.sourceKey, newLocKey: keyMapping[valueTransforms.sourceKey.locKey] ?? valueTransforms.sourceKey.locKey),
									transforms: valueTransforms.transforms
								)
								
							case let stdToXibLoc as LocKeyMappingComponentStdToXibLoc:
								return LocKeyMappingComponentStdToXibLoc(
									taggedKeys: stdToXibLoc.taggedKeys.map{ k in
										return TaggedObject<LineKey>(
											value: LineKey(copying: k.value, newLocKey: keyMapping[k.value.locKey] ?? k.value.locKey),
											tags: k.tags
										)
									}
								)
								
							default:
								return component
							}
						}
					}
				}
				return .mapping(mapping)
			}
		}
	}
	
}
