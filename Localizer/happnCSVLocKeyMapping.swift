/*
 * happnCSVLocKeyMapping.swift
 * Localizer
 *
 * Created by François Lamboley on 12/3/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



enum MappingResolvingError : Error {
	case invalidMapping
	case keyNotFound
	case mappedToMappedKey /* When mapping points to a mapped key. This is invalid to avoid infinite recursions... */
}


class happnCSVLocKeyMapping {
	
	let originalStringRepresentation: String
	var components: [happnCSVLocKeyMappingComponent]?
	
	/** Compute whether the given transform is valid (do not check for
	existence of keys for mapping components though). */
	var isValid: Bool {
		guard let components = components else {return false}
		for c in components {guard c.isValid else {return false}}
		return true
	}
	
	/** Inits a happn CSV Loc Key Mapping from a string representation (JSON).
	
	If the string is empty, returns nil.
	
	If the string representation is invalid (invalid JSON, etc.), a fully
	inited object is returned with nil components. */
	convenience init?(stringRepresentation: String) {
		guard !stringRepresentation.isEmpty else {return nil}
		
		guard
			let data = stringRepresentation.data(using: .utf8),
			let serializedComponent_s = try? JSONSerialization.jsonObject(with: data, options: []) else
		{
			print("*** Warning: Invalid mapping; cannot serialize JSON string: \"\(stringRepresentation)\"")
			self.init(components: nil, stringRepresentation: stringRepresentation)
			return
		}
		let serializedComponents: [[String: AnyObject]]
		if      let array = serializedComponent_s as? [[String: AnyObject]] {serializedComponents = array}
		else if let simple = serializedComponent_s as? [String: AnyObject]  {serializedComponents = [simple]}
		else {
			print("*** Warning: Invalid mapping; cannot convert string to array of dictionary: \"\(stringRepresentation)\"")
			self.init(components: nil, stringRepresentation: stringRepresentation)
			return
		}
		
		self.init(components: serializedComponents.map {happnCSVLocKeyMappingComponent.createCSVLocKeyMappingFromSerialization($0)}, stringRepresentation: stringRepresentation)
	}
	
	convenience init(components: [happnCSVLocKeyMappingComponent]) {
		self.init(components: components, stringRepresentation: happnCSVLocKeyMapping.stringRepresentationFromComponentsList(components))
	}
	
	init(components c: [happnCSVLocKeyMappingComponent]?, stringRepresentation: String) {
		components = c
		originalStringRepresentation = stringRepresentation
	}
	
	func stringRepresentation() -> String {
		if let components = components {
			return happnCSVLocKeyMapping.stringRepresentationFromComponentsList(components)
		} else {
			return originalStringRepresentation
		}
	}
	
	func apply(forLanguage language: String, entries: [happnCSVLocFile.LineKey: happnCSVLocFile.LineValue]) throws -> String {
		guard isValid, let components = components else {
			throw MappingResolvingError.invalidMapping
		}
		
		var res = ""
		for component in components {
			assert(component.isValid) /* Checked above with isValid */
			res += try component.apply(forLanguage: language, entries: entries)
		}
		return res
	}
	
	private static func stringRepresentationFromComponentsList(_ components: [happnCSVLocKeyMappingComponent]) -> String {
		let allSerialized = components.map {$0.serialize()}
		return try! String(
			data: JSONSerialization.data(
				withJSONObject: (allSerialized.count == 1 ? allSerialized[0] as AnyObject : allSerialized as AnyObject),
				options: [.prettyPrinted]
			),
			encoding: .utf8
		)!
	}
	
}



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
	
	/** Subclasses must implement to check if mapping is syntactically valid (do
	not check if resolving component is possible). */
	var isValid: Bool {
		fatalError("This computed property is abstract.")
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
	
	func apply(forLanguage language: String, entries: [happnCSVLocFile.LineKey: happnCSVLocFile.LineValue]) throws -> String {
		preconditionFailure("This method is abstract")
	}
	
}



/* ***** */
class CSVLocKeyMappingComponentInvalid : happnCSVLocKeyMappingComponent {
	
	override var isValid: Bool {
		return false
	}
	
	let invalidSerialization: [String: Any]
	
	init(serialization: [String: Any]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: Any] {
		return invalidSerialization
	}
	
	override func apply(forLanguage language: String, entries: [happnCSVLocFile.LineKey: happnCSVLocFile.LineValue]) throws -> String {
		throw MappingResolvingError.invalidMapping
	}
	
}



/* ***** */
class CSVLocKeyMappingComponentToConstant : happnCSVLocKeyMappingComponent {
	
	override var isValid: Bool {
		return true
	}
	
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
	
	override func apply(forLanguage language: String, entries: [happnCSVLocFile.LineKey: happnCSVLocFile.LineValue]) throws -> String {
		return constant
	}
	
}



/* ***** */
class CSVLocKeyMappingComponentValueTransforms : happnCSVLocKeyMappingComponent {
	
	override var isValid: Bool {
		for transform in subTransformComponents {guard transform.isValid else {return false}}
		return true
	}
	
	let sourceKey: happnCSVLocFile.LineKey
	
	let subTransformComponents: [LocValueTransformer]
	
	init(sourceKey k: happnCSVLocFile.LineKey, subTransformsComponents s: [LocValueTransformer]) {
		sourceKey = k
		subTransformComponents = s
	}
	
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
	
	override func apply(forLanguage language: String, entries: [happnCSVLocFile.LineKey: happnCSVLocFile.LineValue]) throws -> String {
		switch entries[sourceKey] {
		case nil:                   throw MappingResolvingError.keyNotFound
		case .mapping?:             throw MappingResolvingError.mappedToMappedKey
		case .entries(let values)?: return try subTransformComponents.reduce(values[language] ?? "") { try $1.apply(toValue: $0, withLanguage: language) }
		}
	}
	
}



/* Abstract */
class LocValueTransformer {
	
	var isValid: Bool {
		fatalError("isValid is abstract.")
	}
	
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
			case "gender_variant_pick":           c = try LocValueTransformerGenderVariantPick(serialization: serialization)
			case "plural_variant_pick":           c = try LocValueTransformerPluralVariantPick(serialization: serialization)
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
		switch self {
		case _ as LocValueTransformerSimpleStringReplacements:    serializedData["__type"] = "simple_string_replacements"
		case _ as LocValueTransformerGenderVariantPick:           serializedData["__type"] = "gender_variant_pick"
		case _ as LocValueTransformerPluralVariantPick:           serializedData["__type"] = "plural_variant_pick"
		case _ as LocValueTransformerRegionDelimitersReplacement: serializedData["__type"] = "region_delimiters_replacement"
		default:
			print("*** Warning: Did not get a type for loc value transformer component \(self)")
		}
		return serializedData
	}
	
	fileprivate func serializePrivateData() -> [String: Any] {
		preconditionFailure("This method is abstract")
	}
	
	func apply(toValue value: String, withLanguage: String) throws -> String {
		preconditionFailure("This method is abstract")
	}
	
}



/* ***** */
class LocValueTransformerInvalid : LocValueTransformer {
	
	override var isValid: Bool {
		return false
	}
	
	let invalidSerialization: [String: Any]
	
	init(serialization: [String: Any]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: Any] {
		return invalidSerialization
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		throw NSError()
	}
	
}



/* ***** */
class LocValueTransformerSimpleStringReplacements : LocValueTransformer {
	
	override var isValid: Bool {
		return true
	}
	
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
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		var ret = value
		for (r, v) in replacements {
			ret = ret.replacingOccurrences(of: r, with: v)
		}
		return ret
	}
	
}



/* ***** */
class LocValueTransformerRegionDelimitersReplacement : LocValueTransformer {
	
	override var isValid: Bool {
		return true
	}
	
	let openDelim: String
	let replacement: String
	let closeDelim: String
	let escapeToken: String?
	
	init(serialization: [String: Any]) throws {
		guard
			let od = serialization["open_delimiter"] as? String, !od.isEmpty,
			let r  = serialization["replacement"] as? String,
			let cd = serialization["close_delimiter"] as? String, !cd.isEmpty
			else
		{
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid or missing open_delimiter, replacement or close_delimiter."])
		}
		
		openDelim = od
		replacement = r
		closeDelim = cd
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = nil}
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
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		/* TODO */
		var ret = value
		return ret
	}
	
}



/* ***** */
class LocValueTransformerGenderVariantPick : LocValueTransformer {
	
	enum Gender {
		case male, female
		init?(string: String) {
			switch string.lowercased() {
			case "male",   "m": self = .male
			case "female", "f": self = .female
			default: return nil
			}
		}
		func toString() -> String {
			switch self {
			case .male:   return "male"
			case .female: return "female"
			}
		}
	}
	
	override var isValid: Bool {
		return true
	}
	
	let gender: Gender
	let openDelim: String
	let middleDelim: String
	let closeDelim: String
	let escapeToken: String?
	
	init(serialization: [String: Any]) throws {
		guard let gs = serialization["gender"] as? String, let g = Gender(string: gs) else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid gender."])
		}
		
		if let d = serialization["open_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty open delimiter, which is invalid."])}
			openDelim = d
		} else {openDelim = "`"}
		
		if let d = serialization["middle_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty middle delimiter, which is invalid."])}
			middleDelim = d
		} else {middleDelim = "¦"}
		
		if let d = serialization["close_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty close delimiter, which is invalid."])}
			closeDelim = d
		} else {closeDelim = "´"}
		
		gender = g
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = nil}
		
		/* Let's check the values retrieved from serialization are ok.
		 * TODO: Check the weird open/close/middle delimiter constraints from HCUtils+Language */
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		var ret = [
			"gender": gender.toString(),
			"open_delimiter": openDelim,
			"middle_delimiter": middleDelim,
			"close_delimiter": closeDelim
		]
		if let e = escapeToken {ret["escape_token"] = e}
		return ret
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		let ret = NSMutableString(string: value)
		let regexp = try! NSRegularExpression(pattern: "\(openDelim)(.*?)\(middleDelim)(.*?)\(closeDelim)", options: [])
		regexp.replaceMatches(in: ret, options: [], range: NSRange(location: 0, length: ret.length), withTemplate: (gender == .male ? "$1" : "$2"))
		return ret as String
	}
	
}



/* ***** */
class LocValueTransformerPluralVariantPick : LocValueTransformer {
	
	override var isValid: Bool {
		return true
	}
	
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
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = nil}
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
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		/* TODO */
		var ret = value
		return ret
	}
	
}
