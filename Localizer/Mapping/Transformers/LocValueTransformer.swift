/*
 * LocValueTransformer.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



public class LocValueTransformer {
	
	public var isValid: Bool {
		fatalError("isValid is abstract.")
	}
	
	/**
	Instantiate the correct subclass for the given serialization.
	
	Cannot fail because if the serialization is invalid, will return a
	LocValueTransformerInvalid that will simply hold the serialization and will
	not do any transform. This allows storing the given invalid transform so it
	is not lost when the transform is serialized back. */
	public static func createComponentTransformFromSerialization(_ serialization: [String: Any]) -> LocValueTransformer {
		do {
			guard let type = serialization["__type"] as? String else {
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid loc value transformer component: Key __type is undefined or not a string."])
			}
			
			let c: LocValueTransformer
			
			switch type {
			case "simple_string_replacements":    c = try LocValueTransformerSimpleStringReplacements(serialization: serialization)
			case "to_upper":                      c = try LocValueTransformerToUpper(serialization: serialization)
			case "gender_variant_pick":           c = try LocValueTransformerGenderVariantPick(serialization: serialization)
			case "plural_variant_pick":           c = try LocValueTransformerPluralVariantPick(serialization: serialization)
			case "region_delimiters_replacement": c = try LocValueTransformerRegionDelimitersReplacement(serialization: serialization)
			default:
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid loc value transformer component: Unknown __type value \"\(type)\"."])
			}
			
			return c
		} catch {
			if let errMsg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got error: %@", log: $0, type: .info, errMsg) }}
				else                        {NSLog("Got error: %@", errMsg)}
			}
			return LocValueTransformerInvalid(serialization: serialization)
		}
	}
	
	public final func serialize() -> [String: Any] {
		var serializedData = self.serializePrivateData()
		switch self {
		case _ as LocValueTransformerSimpleStringReplacements:    serializedData["__type"] = "simple_string_replacements"
		case _ as LocValueTransformerToUpper:                     serializedData["__type"] = "to_upper"
		case _ as LocValueTransformerGenderVariantPick:           serializedData["__type"] = "gender_variant_pick"
		case _ as LocValueTransformerPluralVariantPick:           serializedData["__type"] = "plural_variant_pick"
		case _ as LocValueTransformerRegionDelimitersReplacement: serializedData["__type"] = "region_delimiters_replacement"
		default:
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Did not get a type for loc value transformer component %@", log: $0, type: .info, String(describing: self)) }}
			else                        {NSLog("Did not get a type for loc value transformer component %@", String(describing: self))}
		}
		return serializedData
	}
	
	func serializePrivateData() -> [String: Any] {
		preconditionFailure("This method is abstract")
	}
	
	func apply(toValue value: String, withLanguage: String) throws -> String {
		preconditionFailure("This method is abstract")
	}
	
}
