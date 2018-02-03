/*
 * happnCSVLocKeyMappingComponent.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



public class happnCSVLocKeyMappingComponent {
	
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
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got error: %@", log: $0, type: .info, errMsg) }}
				else                        {NSLog("Got error: %@", errMsg)}
			}
			return CSVLocKeyMappingComponentInvalid(serialization: serialization)
		}
	}
	
	/** Subclasses must implement to check if mapping is syntactically valid (do
	not check if resolving component is possible). */
	public var isValid: Bool {
		fatalError("This computed property is abstract.")
	}
	
	final func serialize() -> [String: Any] {
		var serializedData = self.serializePrivateData()
		if      self is CSVLocKeyMappingComponentToConstant      {serializedData["__type"] = "to_constant"}
		else if self is CSVLocKeyMappingComponentValueTransforms {serializedData["__type"] = "value_transforms"}
		else {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Did not get a type for component %@", log: $0, type: .info, String(describing: self)) }}
			else                        {NSLog("Did not get a type for component %@", String(describing: self))}
		}
		return serializedData
	}
	
	func serializePrivateData() -> [String: Any] {
		preconditionFailure("This method is abstract")
	}
	
	func apply(forLanguage language: String, entries: [happnCSVLocFile.LineKey: happnCSVLocFile.LineValue]) throws -> String {
		preconditionFailure("This method is abstract")
	}
	
}
