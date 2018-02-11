/*
 * IOUtils.swift
 * LocMapper
 *
 * Created by François Lamboley on 12/4/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



func writeText(_ text: String, toFile filePath: String, usingEncoding encoding: String.Encoding) throws {
	guard let data = text.data(using: encoding, allowLossyConversion: false) else {
		throw NSError(domain: "LocMapperErrDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot convert text to expected encoding"])
	}
	
	if FileManager.default.fileExists(atPath: filePath) {
		try FileManager.default.removeItem(atPath: filePath)
	}
	if !FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil) {
		throw NSError(domain: "LocMapperErrDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot file at path \(filePath)"])
	}
	
	if let output_stream = FileHandle(forWritingAtPath: filePath) {
		defer {output_stream.closeFile()}
		
		/* This line actually raises an exception if cannot write... We should
		 * handle that! (In Swift? How...) */
		output_stream.write(data)
	} else {
		throw NSError(domain: "LocMapperErrDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open file at path \(filePath) for writing"])
	}
}
