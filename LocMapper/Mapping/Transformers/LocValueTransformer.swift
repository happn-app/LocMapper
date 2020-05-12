/*
 * LocValueTransformer.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

import Logging



public class LocValueTransformer {
	
	class var serializedType: String {
		fatalError("serializedType is abstract.")
	}
	
	public var isValid: Bool {
		fatalError("isValid is abstract.")
	}
	
	/**
	Instantiate the correct subclass for the given serialization.
	
	Cannot fail because if the serialization is invalid, will return a
	LocValueTransformerInvalid that will simply hold the serialization and will
	not do any transform. This allows storing the given invalid transform so it
	is not lost when the transform is serialized back. */
	public static func createComponentTransformFromSerialization(_ serialization: [String: Any?]) -> LocValueTransformer {
		do {
			guard let type = serialization["__type"] as? String else {
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid loc value transformer component: Key __type is undefined or not a string."])
			}
			
			let c: LocValueTransformer
			
			switch type {
			case LocValueTransformerSimpleStringReplacements.serializedType:    c = try LocValueTransformerSimpleStringReplacements(serialization: serialization)
			case LocValueTransformerRegexReplacements.serializedType:           c = try LocValueTransformerRegexReplacements(serialization: serialization)
			case LocValueTransformerToUpper.serializedType:                     c = try LocValueTransformerToUpper(serialization: serialization)
			case LocValueTransformerGenderVariantPick.serializedType:           c = try LocValueTransformerGenderVariantPick(serialization: serialization)
			case LocValueTransformerPluralVariantPick.serializedType:           c = try LocValueTransformerPluralVariantPick(serialization: serialization)
			case LocValueTransformerRegionDelimitersReplacement.serializedType: c = try LocValueTransformerRegionDelimitersReplacement(serialization: serialization)
			default:
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid loc value transformer component: Unknown __type value \"\(type)\"."])
			}
			
			return c
		} catch {
			#if canImport(os)
				LocMapperConfig.oslog.flatMap{ os_log("Got error: %@", log: $0, type: .info, String(describing: error)) }
			#endif
			LocMapperConfig.logger?.warning("Got error: \(String(describing: error))")
			return LocValueTransformerInvalid(serialization: serialization)
		}
	}
	
	public final func serialize() -> [String: Any?] {
		var serializedData = self.serializePrivateData()
		if !(self is LocValueTransformerInvalid) {serializedData["__type"] = type(of: self).serializedType}
		return serializedData
	}
	
	func serializePrivateData() -> [String: Any?] {
		preconditionFailure("This method is abstract")
	}
	
	func apply(toValue value: String, withLanguage: String) throws -> String {
		preconditionFailure("This method is abstract")
	}
	
}
