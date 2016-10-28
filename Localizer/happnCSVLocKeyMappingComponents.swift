/*
 * happnCSVLocKeyMappingComponents.swift
 * Localizer
 *
 * Created by François Lamboley on 12/3/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



/* Abstract */
class happnCSVLocKeyMappingComponent {
	/**
   Instantiate the correct subclass for the given serialization.
	
   Cannot fail because if the serialization is invalid, will return a
	`CSVLocKeyMappingComponentInvalid` that will simply hold the serialization
	and will not do any transform. This allows storing the given invalid
	transform so it is not lost when the transform is serialized back. */
	static func createCSVLocKeyMappingFromSerialization(_ serialization: [String: Any]) -> happnCSVLocKeyMappingComponent {
		do {
			guard let type = serialization["__type"] as? String else {
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid mapping component: Key __type is undefined or not a string."])
			}
			
			let c: happnCSVLocKeyMappingComponent
			
			switch type {
			case "to_constant":      c = try CSVLocKeyMappingComponentToConstant(serialization: serialization)
			case "value_transforms": c = try CSVLocKeyMappingComponentValueTransforms(serialization: serialization)
			default:
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid mapping component: Unknown __type value \"\(type)\"."])
			}
			
			return c
		} catch {
			if let errMsg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String {
				print("*** Warning: \(errMsg)")
			}
			return CSVLocKeyMappingComponentInvalid(serialization: serialization)
		}
	}
	
	final func serialize() -> [String: Any] {
		var serializedData = self.serializePrivateData()
		if      self is CSVLocKeyMappingComponentToConstant      {serializedData["__type"] = "to_constant"}
		else if self is CSVLocKeyMappingComponentValueTransforms {serializedData["__type"] = "value_transforms"}
		else {
			print("*** Warning: Did not get a type for component \(self)")
		}
		return serializedData
	}
	
	fileprivate func serializePrivateData() -> [String: Any] {
		preconditionFailure("This method is abstract")
	}
	
	func applyWithCurrentValue(_ language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
		preconditionFailure("This method is abstract")
	}
}



/* ***** */
class CSVLocKeyMappingComponentInvalid : happnCSVLocKeyMappingComponent {
	let invalidSerialization: [String: Any]
	
	init(serialization: [String: Any]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: Any] {
		return invalidSerialization
	}
	
	override func applyWithCurrentValue(_ language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
		return nil
	}
}



/* ***** */
class CSVLocKeyMappingComponentToConstant : happnCSVLocKeyMappingComponent {
	let constant: String
	
	init(serialization: [String: Any]) throws {
		guard let c = serialization["constant"] as? String else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"constant\" is either undefined or not a String."])
		}
		
		constant = c
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		return ["constant": constant]
	}
	
	override func applyWithCurrentValue(_ language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
		return constant
	}
}



/* ***** */
class CSVLocKeyMappingComponentValueTransforms : happnCSVLocKeyMappingComponent {
	let sourceKey: happnCSVLocFile.LineKey
	
	let subTransformComponents: [LocValueTransformer]
	
	init(serialization: [String: Any]) throws {
		guard
			let env          = serialization["env"] as? String,
			let filename     = serialization["filename"] as? String,
			let locKey       = serialization["loc_key"] as? String,
			let dtransform_s = serialization["transforms"]
			else
		{
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Some keys are missing or invalid."])
		}
		let dtransforms: [[String: Any]]
		if      let array = dtransform_s as? [[String: Any]] {dtransforms = array}
		else if let simple = dtransform_s as? [String: Any]  {dtransforms = [simple]}
		else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot convert transforms to array of dictionary from serialization: \"\(serialization)\"."])
		}
		
		sourceKey = happnCSVLocFile.LineKey(
			locKey: locKey,
			env: env,
			filename: filename,
			index: 0,
			comment: "",
			userInfo: [:],
			userReadableGroupComment: "",
			userReadableComment: ""
		)
		subTransformComponents = dtransforms.map {return LocValueTransformer.createComponentTransformFromSerialization($0)}
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		let serializedTransforms = subTransformComponents.map {return $0.serialize()}
		
		return [
			"env":        sourceKey.env,
			"filename":   sourceKey.filename,
			"loc_key":    sourceKey.locKey,
			"transforms": (serializedTransforms.count == 1 ? serializedTransforms[0] as Any : serializedTransforms as Any)
		]
	}
	
	override func applyWithCurrentValue(_ language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
		var result = entries[sourceKey]?[language]
		for subTransform in subTransformComponents {
			result = subTransform.applyToValue(result, withLanguage: language)
		}
		return result
	}
}



/* Abstract */
class LocValueTransformer {
	/**
   Instantiate the correct subclass for the given serialization.
	
   Cannot fail because if the serialization is invalid, will return a
	LocValueTransformerInvalid that will simply hold the serialization and will
	not do any transform. This allows storing the given invalid transform so it
	is not lost when the transform is serialized back. */
	static func createComponentTransformFromSerialization(_ serialization: [String: Any]) -> LocValueTransformer {
		do {
			guard let type = serialization["__type"] as? String else {
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid loc value transformer component: Key __type is undefined or not a string."])
			}
			
			let c: LocValueTransformer
			
			switch type {
			case "simple_string_replacements":    c = try LocValueTransformerSimpleStringReplacements(serialization: serialization)
			case "region_delimiters_replacement": c = try LocValueTransformerRegionDelimitersReplacement(serialization: serialization)
			default:
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid loc value transformer component: Unknown __type value \"\(type)\"."])
			}
			
			return c
		} catch {
			if let errMsg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String {
				print("*** Warning: \(errMsg)")
			}
			return LocValueTransformerInvalid(serialization: serialization)
		}
	}
	
	final func serialize() -> [String: Any] {
		var serializedData = self.serializePrivateData()
		if      self is LocValueTransformerSimpleStringReplacements    {serializedData["__type"] = "simple_string_replacements"}
		else if self is LocValueTransformerRegionDelimitersReplacement {serializedData["__type"] = "region_delimiters_replacement"}
		else {
			print("*** Warning: Did not get a type for loc value transformer component \(self)")
		}
		return serializedData
	}
	
	fileprivate func serializePrivateData() -> [String: Any] {
		preconditionFailure("This method is abstract")
	}
	
	func applyToValue(_ value: String?, withLanguage: String) -> String? {
		preconditionFailure("This method is abstract")
	}
}



/* ***** */
class LocValueTransformerInvalid : LocValueTransformer {
	let invalidSerialization: [String: Any]
	
	init(serialization: [String: Any]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: Any] {
		return invalidSerialization
	}
	
	override func applyToValue(_ value: String?, withLanguage: String) -> String? {
		/* The transform is invalid; we don't know what to do, let's do nothing. */
		return value
	}
}



/* ***** */
class LocValueTransformerSimpleStringReplacements : LocValueTransformer {
	let replacements: [String: String]
	
	init(serialization: [String: Any]) throws {
		guard let r = serialization["replacements"] as? [String: String] else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"replacements\" is either undefined or not [String: String]."])
		}
		
		replacements = r
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		return ["replacements": replacements]
	}
	
	override func applyToValue(_ value: String?, withLanguage: String) -> String? {
		guard var ret = value else {
			return nil
		}
		
		for (r, v) in replacements {
			ret = ret.replacingOccurrences(of: r, with: v)
		}
		return ret
	}
}



/* ***** */
class LocValueTransformerRegionDelimitersReplacement : LocValueTransformer {
	let openDelim: String
	let replacement: String
	let closeDelim: String
	let escapeToken: String?
	
	init(serialization: [String: Any]) throws {
		guard
			let od = serialization["open_delimiter"] as? String,
			let r  = serialization["replacement"] as? String,
			let cd = serialization["close_delimiter"] as? String
			else
		{
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing either open_delimiter, replacement or close_delimiter."])
		}
		
		openDelim = od
		replacement = r
		closeDelim = cd
		if let e = serialization["escape_token"] as? String, e.characters.count >= 1 {escapeToken = e}
		else                                                                         {escapeToken = nil}
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		var ret = [
			"open_delimiter": openDelim,
			"replacement": replacement,
			"close_delimiter": closeDelim
		]
		if let e = escapeToken {ret["escape_token"] = e}
		return ret
	}
	
	override func applyToValue(_ value: String?, withLanguage: String) -> String? {
		guard let ret = value else {
			return nil
		}
		
		/* TODO */
		return ret
	}
}
