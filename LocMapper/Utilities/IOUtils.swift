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
		
		/* This line actually raises an exception if cannot write…
		 * We should handle that! (In Swift? How…) */
		output_stream.write(data)
	} else {
		throw NSError(domain: "LocMapperErrDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open file at path \(filePath) for writing"])
	}
}


class FileHandleOutputStream : TextOutputStream {
	
	let closeOnDeinit: Bool
	let fileHandle: FileHandle
	
	convenience init(forPath path: String) throws {
		try Data().write(to: URL(fileURLWithPath: path), options: []) /* We do not delete original file if present to keep xattrs... */
		guard let fh = FileHandle(forWritingAtPath: path) else {
			throw NSError(domain: "LocMapperErrDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open file at path \(path) for writing"])
		}
		self.init(fh: fh, closeOnDeinit: true)
	}
	
	init(fh: FileHandle, closeOnDeinit c: Bool = false) {
		closeOnDeinit = c
		fileHandle = fh
	}
	
	deinit {
		if closeOnDeinit {fileHandle.closeFile()}
	}
	
	func write(_ string: String) {
		fileHandle.write(Data(string.utf8))
	}
	
}
