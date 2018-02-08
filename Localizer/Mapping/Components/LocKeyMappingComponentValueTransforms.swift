/*
 * LocKeyMappingComponentValueTransforms.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



public class LocKeyMappingComponentValueTransforms : LocKeyMappingComponent {
	
	override class var serializedType: String {return "value_transforms"}
	
	public override var isValid: Bool {
		for transform in subTransformComponents {guard transform.isValid else {return false}}
		return true
	}
	
	public let sourceKey: LocFile.LineKey
	
	public let subTransformComponents: [LocValueTransformer]
	
	public init(sourceKey k: LocFile.LineKey, subTransformsComponents s: [LocValueTransformer]) {
		sourceKey = k
		subTransformComponents = s
	}
	
	init(serialization: [String: Any]) throws {
		guard
			let env          = serialization["env"] as? String,
			let filename     = serialization["filename"] as? String,
			let locKey       = serialization["loc_key"] as? String,
			let dtransform_s = serialization["transforms"]
		else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Some keys are missing or invalid."])
		}
		let dtransforms: [[String: Any]]
		if      let array = dtransform_s as? [[String: Any]] {dtransforms = array}
		else if let simple = dtransform_s as? [String: Any]  {dtransforms = [simple]}
		else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot convert transforms to array of dictionary from serialization: \"\(serialization)\"."])
		}
		
		sourceKey = LocFile.LineKey(
			locKey: locKey,
			env: env,
			filename: filename,
			index: 0,
			comment: "",
			userInfo: [:],
			userReadableGroupComment: "",
			userReadableComment: ""
		)
		subTransformComponents = dtransforms.map{ LocValueTransformer.createComponentTransformFromSerialization($0) }
	}
	
	override func serializePrivateData() -> [String: Any] {
		let serializedTransforms = subTransformComponents.map{ $0.serialize() }
		
		return [
			"env":        sourceKey.env,
			"filename":   sourceKey.filename,
			"loc_key":    sourceKey.locKey,
			"transforms": (serializedTransforms.count == 1 ? serializedTransforms[0] as Any : serializedTransforms as Any)
		]
	}
	
	override func apply(forLanguage language: String, entries: [LocFile.LineKey: LocFile.LineValue]) throws -> String {
		switch entries[sourceKey] {
		case nil:                   throw MappingResolvingError.keyNotFound
		case .mapping?:             throw MappingResolvingError.mappedToMappedKey
		case .entries(let values)?: return try subTransformComponents.reduce(values[language] ?? ""){ try $1.apply(toValue: $0, withLanguage: language) }
		}
	}
	
}
