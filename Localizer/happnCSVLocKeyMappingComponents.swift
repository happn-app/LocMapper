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
	static func createCSVLocKeyMappingFromSerialization(serialization: [String: AnyObject]) -> happnCSVLocKeyMappingComponent {
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
	
	final func serialize() -> [String: AnyObject] {
		var serializedData = self.serializePrivateData()
		if      self is CSVLocKeyMappingComponentToConstant      {serializedData["__type"] = "to_constant"}
		else if self is CSVLocKeyMappingComponentValueTransforms {serializedData["__type"] = "value_transforms"}
		else {
			print("*** Warning: Did not get a type for component \(self)")
		}
		return serializedData
	}
	
	private func serializePrivateData() -> [String: AnyObject] {
		preconditionFailure("This method is abstract")
	}
	
	func applyWithCurrentValue(currentValue: String, language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
		preconditionFailure("This method is abstract")
	}
}



/* ***** */
class CSVLocKeyMappingComponentInvalid : happnCSVLocKeyMappingComponent {
	let invalidSerialization: [String: AnyObject]
	
	init(serialization: [String: AnyObject]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: AnyObject] {
		return invalidSerialization
	}
	
	override func applyWithCurrentValue(currentValue: String, language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
		return nil
	}
}



/* ***** */
class CSVLocKeyMappingComponentToConstant : happnCSVLocKeyMappingComponent {
	let constant: String
	
	init(serialization: [String: AnyObject]) throws {
		guard let c = serialization["constant"] as? String else {
			constant = "" /* Won't be needed in Swift 2.2? */
			super.init() /* Won't be needed in Swift 2.2? */
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"constant\" is either undefined or not a String."])
		}
		
		constant = c
		super.init()
	}
	
	override func serializePrivateData() -> [String: AnyObject] {
		return ["constant": constant]
	}
	
	override func applyWithCurrentValue(currentValue: String, language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
		return constant
	}
}



/* ***** */
class CSVLocKeyMappingComponentValueTransforms : happnCSVLocKeyMappingComponent {
	let sourceKey: happnCSVLocFile.LineKey
	
	let subTransformComponents: [LocValueTransformer]
	
	init(serialization: [String: AnyObject]) throws {
		guard let
			env          = serialization["env"] as? String,
			filename     = serialization["filename"] as? String,
			locKey       = serialization["loc_key"] as? String,
			dtransform_s = serialization["transforms"] else
		{
			/* The three lines below won't be needed in Swift 2.2? */
			subTransformComponents = []
			sourceKey = happnCSVLocFile.LineKey(locKey: "", env: "", filename: "", comment: "", index: 0, userReadableGroupComment: "", userReadableComment:  "") /* Won't be needed in Swift 2.1 */
			super.init()
			
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Some keys are missing or invalid."])
		}
		let dtransforms: [[String: AnyObject]]
		if      let array = dtransform_s as? [[String: AnyObject]] {dtransforms = array}
		else if let simple = dtransform_s as? [String: AnyObject]  {dtransforms = [simple]}
		else {
			/* The three lines below won't be needed in Swift 2.2? */
			subTransformComponents = []
			sourceKey = happnCSVLocFile.LineKey(locKey: "", env: "", filename: "", comment: "", index: 0, userReadableGroupComment: "", userReadableComment:  "") /* Won't be needed in Swift 2.1 */
			super.init()
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot convert transforms to array of dictionary from serialization: \"\(serialization)\"."])
		}
		
		sourceKey = happnCSVLocFile.LineKey(
			locKey: locKey,
			env: env,
			filename: filename,
			comment: "",
			index: 0,
			userReadableGroupComment: "",
			userReadableComment: ""
		)
		subTransformComponents = dtransforms.map {return LocValueTransformer.createComponentTransformFromSerialization($0)}
		super.init()
	}
	
	override func serializePrivateData() -> [String: AnyObject] {
		let serializedTransforms = subTransformComponents.map {return $0.serialize()}
		
		return [
			"env":        sourceKey.env,
			"filename":   sourceKey.filename,
			"loc_key":    sourceKey.locKey,
			"transforms": (serializedTransforms.count == 1 ? serializedTransforms[0] as AnyObject : serializedTransforms as AnyObject)
		]
	}
	
	override func applyWithCurrentValue(currentValue: String, language: String, entries: [happnCSVLocFile.LineKey: [String /* Language */: String /* Value */]]) -> String? {
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
	static func createComponentTransformFromSerialization(serialization: [String: AnyObject]) -> LocValueTransformer {
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
	
	final func serialize() -> [String: AnyObject] {
		var serializedData = self.serializePrivateData()
		if      self is LocValueTransformerSimpleStringReplacements    {serializedData["__type"] = "simple_string_replacements"}
		else if self is LocValueTransformerRegionDelimitersReplacement {serializedData["__type"] = "region_delimiters_replacement"}
		else {
			print("*** Warning: Did not get a type for loc value transformer component \(self)")
		}
		return serializedData
	}
	
	private func serializePrivateData() -> [String: AnyObject] {
		preconditionFailure("This method is abstract")
	}
	
	func applyToValue(value: String?, withLanguage: String) -> String? {
		preconditionFailure("This method is abstract")
	}
}



/* ***** */
class LocValueTransformerInvalid : LocValueTransformer {
	let invalidSerialization: [String: AnyObject]
	
	init(serialization: [String: AnyObject]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: AnyObject] {
		return invalidSerialization
	}
	
	override func applyToValue(value: String?, withLanguage: String) -> String? {
		/* The transform is invalid; we don't know what to do, let's do nothing. */
		return value
	}
}



/* ***** */
class LocValueTransformerSimpleStringReplacements : LocValueTransformer {
	let replacements: [String: String]
	
	init(serialization: [String: AnyObject]) throws {
		guard let r = serialization["replacements"] as? [String: String] else {
			replacements = [:] /* Won't be needed in Swift 2.2? */
			super.init() /* Won't be needed in Swift 2.2? */
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"replacements\" is either undefined or not [String: String]."])
		}
		
		replacements = r
		super.init()
	}
	
	override func serializePrivateData() -> [String: AnyObject] {
		return ["replacements": replacements]
	}
	
	override func applyToValue(value: String?, withLanguage: String) -> String? {
		guard var ret = value else {
			return nil
		}
		
		for (r, v) in replacements {
			ret = ret.stringByReplacingOccurrencesOfString(r, withString: v)
		}
		return ret
	}
}



/* ***** */
class LocValueTransformerRegionDelimitersReplacement : LocValueTransformer {
	let openDelim: String
	let openDelimReplacement: String
	let closeDelim: String
	let closeDelimReplacement: String
	let escapeToken: String?
	
	init(serialization: [String: AnyObject]) throws {
		guard let
			od  = serialization["open_delimiter"] as? String,
			odr = serialization["open_delimiter_replacement"] as? String,
			cd  = serialization["close_delimiter"] as? String,
			cdr = serialization["close_delimiter_replacement"] as? String else
		{
			openDelim = "" /* Won't be needed in Swift 2.2? */
			openDelimReplacement = "" /* Won't be needed in Swift 2.2? */
			closeDelim = "" /* Won't be needed in Swift 2.2? */
			closeDelimReplacement = "" /* Won't be needed in Swift 2.2? */
			escapeToken = nil /* Won't be needed in Swift 2.2? */
			super.init() /* Won't be needed in Swift 2.2? */
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing either open_delimiter, open_delimiter_replacement, close_delimiter or close_delimiter_replacement."])
		}
		
		openDelim = od
		openDelimReplacement = odr
		closeDelim = cd
		closeDelimReplacement = cdr
		if let e = serialization["escape_token"] as? String where e.characters.count >= 1 {escapeToken = e}
		else                                                                              {escapeToken = nil}
		super.init()
	}
	
	override func serializePrivateData() -> [String: AnyObject] {
		var ret = [
			"open_delimiter": openDelim,
			"open_delimiter_replacement": openDelimReplacement,
			"close_delimiter": closeDelim,
			"close_delimiter_replacement": closeDelimReplacement
		]
		if let e = escapeToken {ret["escape_token"] = e}
		return ret
	}
	
	override func applyToValue(value: String?, withLanguage: String) -> String? {
		guard var ret = value else {
			return nil
		}
		
		/* TODO */
		return ret
	}
}
