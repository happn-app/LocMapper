/*
 * LocFile+MigrationsSupport.swift
 * LocMapper
 *
 * Created by François Lamboley on 19/05/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension LocFile {
	
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
		
		/* We preprocess the mapping transformations array for faster access later in the entries loop. */
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
	
	public func createInitialHappnAndroidMappingForStdRefLoc() {
		for k in entryKeys(matchingFilters: [.env("Android"), .stateTodoloc, .uiPresentable]) {
			guard let stdKeyName = stdRefLocKeyNameFromAndroidKeyName(k.locKey) else {
				continue
			}
			let destinationKey = LineKey(
				locKey: stdKeyName, env: "StdRefLoc", filename: "StandardReferencesTranslations.csv",
				index: 0, comment: "", userInfo: [:], userReadableGroupComment: "", userReadableComment: ""
			)
			entries[k] = .mapping(LocKeyMapping(components: [LocKeyMappingComponentValueTransforms(sourceKey: destinationKey, transforms: [
				LocValueTransformerRegionDelimitersReplacement(replacement: "<b>__DELIMITED_VALUE__</b>", openDelim: "*", closeDelim: "*", escapeToken: "~"),
				LocValueTransformerRegionDelimitersReplacement(replacement: "<i>__DELIMITED_VALUE__</i>", openDelim: "_", closeDelim: "_", escapeToken: "~")
			])]))
		}
	}
	
	private func stdRefLocKeyNameFromAndroidKeyName(_ androidKeyName: String) -> String? {
		var base = String(androidKeyName.dropFirst())
		
		var tagsToMatchAll = Set<String>()
		var tagsToMatchAny = Set<String>()
		let baseSplitForPlural = base.split(separator: "\"")
		if androidKeyName.first == "p", baseSplitForPlural.count >= 2 {
			base = String(baseSplitForPlural.dropLast().joined(separator: "\""))
			switch baseSplitForPlural.last! {
				case "zero":  tagsToMatchAll.insert("p0")
				case "one":   tagsToMatchAll.insert("p1")
				case "two":   tagsToMatchAll.insert("p2")
				case "few":   tagsToMatchAll.insert("pf")
				case "many":  tagsToMatchAll.insert("pm")
				case "other": tagsToMatchAll.insert("px")
				default: (/*nop*/)
			}
		}
		
		let isMaleLevel1: Bool?
		let isMaleLevel2: Bool?
		if      base.hasSuffix("_m") {isMaleLevel1 = true;  base = String(base[base.startIndex..<base.index(base.endIndex, offsetBy: -2)])}
		else if base.hasSuffix("_f") {isMaleLevel1 = false; base = String(base[base.startIndex..<base.index(base.endIndex, offsetBy: -2)])}
		else                         {isMaleLevel1 = nil}
		if      base.hasSuffix("_m") {isMaleLevel2 = true;  base = String(base[base.startIndex..<base.index(base.endIndex, offsetBy: -2)])}
		else if base.hasSuffix("_f") {isMaleLevel2 = false; base = String(base[base.startIndex..<base.index(base.endIndex, offsetBy: -2)])}
		else                         {isMaleLevel2 = nil}
		
		let genderMeTagPrefix = "g{₋}"
		let genderOtherTagPrefix = "g"
		
		if let isMaleLevel1 = isMaleLevel1, let isMaleLevel2 = isMaleLevel2 {
			tagsToMatchAll.insert(genderMeTagPrefix    + (isMaleLevel1 ? "m" : "f"))
			tagsToMatchAll.insert(genderOtherTagPrefix + (isMaleLevel2 ? "m" : "f"))
		} else if let isMaleLevel1 = isMaleLevel1 {
			tagsToMatchAny.insert(genderMeTagPrefix    + (isMaleLevel1 ? "m" : "f"))
			tagsToMatchAny.insert(genderOtherTagPrefix + (isMaleLevel1 ? "m" : "f"))
		} else if let isMaleLevel2 = isMaleLevel2 {
			tagsToMatchAny.insert(genderMeTagPrefix    + (isMaleLevel2 ? "m" : "f"))
			tagsToMatchAny.insert(genderOtherTagPrefix + (isMaleLevel2 ? "m" : "f"))
		}
		
		let possibleKeys = entries.keys.lazy.map{ ($0.locKey, TaggedString(string: $0.locKey)) }.filter{ k in
			let tags = Set(k.1.tags)
			return (k.1.value == base && tags.isSuperset(of: tagsToMatchAll) && (tagsToMatchAny.isEmpty || !tags.intersection(tagsToMatchAny).isEmpty))
		}
		
		return possibleKeys.first?.0
	}
	
}
