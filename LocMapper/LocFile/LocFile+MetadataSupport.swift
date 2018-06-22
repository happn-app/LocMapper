/*
 * LocFile+Metadata.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/4/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



extension LocFile {
	
	public func stringMetadataValueForKey(_ key: String) -> String? {
		return metadata[key]
	}
	
	public func urlMetadataValueForKey(_ key: String) -> URL? {
		return metadata[key].flatMap{ URL(string: $0) }
	}
	
	public func intMetadataValueForKey(_ key: String) -> Int? {
		guard let strVal = metadata[key] else {return nil}
		return Int(strVal)
	}
	
	public func filtersMetadataValueForKey(_ key: String) -> [Filter]? {
		guard let dataVal = metadata[key]?.data(using: .utf8), let filtersStr = (try? JSONSerialization.jsonObject(with: dataVal, options: [])) as? [String] else {return nil}
		return filtersStr.compactMap{ Filter(string: $0) }
	}
	
	public func setMetadataValue(_ value: String, forKey key: String) {
		metadata[key] = value
	}
	
	public func setMetadataValue(_ value: URL, forKey key: String) {
		metadata[key] = value.absoluteString
	}
	
	public func setMetadataValue(_ value: Int, forKey key: String) {
		metadata[key] = String(value)
	}
	
	public func setMetadataValue(_ value: [Filter], forKey key: String) throws {
		try setMetadataValue(value.map{ $0.toString() }, forKey: key)
	}
	
	public func setMetadataValue(_ value: Any, forKey key: String) throws {
		let jsonOptions: JSONSerialization.WritingOptions
		if #available(OSX 10.13, *) {jsonOptions = [.sortedKeys]}
		else                        {jsonOptions = []}
		guard let str = String(data: try JSONSerialization.data(withJSONObject: value, options: jsonOptions), encoding: .utf8) else {
			throw NSError(domain: "LocFile set filters metadata value", code: 1, userInfo: nil)
		}
		metadata[key] = str
	}
	
	public func removeMetadata(forKey key: String) {
		metadata.removeValue(forKey: key)
	}
	
	public func serializedMetadata() -> Data {
		return Data("".byPrepending(userInfo: metadata, sortKeys: true).utf8)
	}
	
	/** Unserialize the given metadata. Should be used when initing an instance
	of `LocFile`. */
	public static func unserializedMetadata(from serializedMetadata: Data) -> Any? {
		guard let strSerializedMetadata = String(data: serializedMetadata, encoding: .utf8) else {return nil}
		
		let (string, decodedMetadata) = strSerializedMetadata.splitPrependedUserInfo()
		if !string.isEmpty {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got stray data in serialized metadata. Ignoring.", log: $0, type: .info) }}
			else                        {NSLog("Got stray data in serialized metadata. Ignoring.")}
		}
		
		return decodedMetadata
	}
	
}
