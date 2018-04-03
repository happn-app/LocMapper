/*
 * LocKeyMappingComponentStdToXibLoc.swift
 * LocMapper
 *
 * Created by François Lamboley on 3/8/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocKeyMappingComponentStdToXibLoc : LocKeyMappingComponent {
	
	override class var serializedType: String {return "std2xib"}
	
	override var isValid: Bool {
		return true
	}
	
	let taggedKeys: [TaggedObject<LocFile.LineKey>]
	
	init(serialization: [String: Any]) throws {
		guard let keys = serialization["tagged_keys"] as? [[String: Any]] else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "No tagged keys."])
		}
		
		var taggedKeysBuilding = [TaggedObject<LocFile.LineKey>]()
		for serializedTaggedKey in keys {
			guard
				let env      = serializedTaggedKey["env"] as? String,
				let filename = serializedTaggedKey["filename"] as? String,
				let locKey   = serializedTaggedKey["loc_key"] as? String,
				let tags     = serializedTaggedKey["tags"] as? [String]
			else {
				throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "At least one invalid tagged key found."])
			}
			
			let key = LocFile.LineKey(
				locKey: locKey,
				env: env,
				filename: filename,
				index: 0,
				comment: "",
				userInfo: [:],
				userReadableGroupComment: "",
				userReadableComment: ""
			)
			taggedKeysBuilding.append(TaggedObject(value: key, tags: tags))
		}
		taggedKeys = taggedKeysBuilding
	}
	
	override func serializePrivateData() -> [String: Any] {
		var serializedTaggedKeys = [[String: Any]]()
		for taggedKey in taggedKeys {
			serializedTaggedKeys.append([
				"env":      taggedKey.value.env,
				"filename": taggedKey.value.filename,
				"loc_key":  taggedKey.value.locKey,
				"tags":     taggedKey.tags
			])
		}
		return ["tagged_keys": serializedTaggedKeys]
	}
	
	override func apply(forLanguage language: String, entries: [LocFile.LineKey: LocFile.LineValue]) throws -> String {
		let taggedValues = try taggedKeys.map{ taggedKey -> TaggedObject<String> in
			let key = taggedKey.value
			switch entries[key] {
			case nil:                   throw MappingResolvingError.keyNotFound
			case .mapping?:             throw MappingResolvingError.mappedToMappedKey
			case .entries(let values)?: return TaggedObject(value: values[language] ?? "", tags: taggedKey.tags)
			}
		}
		
		return Std2Xib.untaggedValue(from: taggedValues)
		
//		for entry in entries.keys.filter({ $0.env == baseSourceKey.env && $0.filename == baseSourceKey.filename && $0.locKey.hasPrefix(baseSourceKey.locKey) }) {
//			print(entry)
//		}
	}
	
}