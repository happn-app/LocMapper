/*
 * IOUtils.swift
 * Localizer
 *
 * Created by François Lamboley on 12/4/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



func writeText(text: String, toFile filePath: String, usingEncoding encoding: NSStringEncoding) throws {
	guard let data = text.dataUsingEncoding(encoding, allowLossyConversion: false) else {
		throw NSError(domain: "LocalizerErrDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot convert text to expected encoding"])
	}
	
	if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
		try NSFileManager.defaultManager().removeItemAtPath(filePath)
	}
	if !NSFileManager.defaultManager().createFileAtPath(filePath, contents: nil, attributes: nil) {
		throw NSError(domain: "LocalizerErrDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot file at path \(filePath)"])
	}
	
	if let output_stream = NSFileHandle(forWritingAtPath: filePath) {
		defer {output_stream.closeFile()}
		
		/* This line actually raises an exception if cannot write... We should
		* handle that! (In Swift? How...) */
		output_stream.writeData(data)
	} else {
		throw NSError(domain: "LocalizerErrDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open file at path \(filePath) for writing"])
	}
}
