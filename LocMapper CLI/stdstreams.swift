/*
 * stdstreams.swift
 * LocMapper CLI
 *
 * From https://stackoverflow.com/a/25226794/1152894
 *
 * Created by François Lamboley on 1/6/18.
 * Copyright © 2018 Frizlab. All rights reserved.
 */

import Foundation



class FileHandleOutputStream : TextOutputStream {
	
	let closeOnDeinit: Bool
	let fileHandle: FileHandle
	
	convenience init(forPath path: String, fileManager: FileManager = .default) throws {
		try Data().write(to: URL(fileURLWithPath: path), options: []) /* We do not delete original file if present to keep xattrs... */
		guard let fh = FileHandle(forWritingAtPath: path) else {
			throw NSError(domain: "LocMapperCLIErrDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open file at path \(path) for writing"])
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


var stdinStream  = FileHandleOutputStream(fh: FileHandle.standardInput)
var stderrStream = FileHandleOutputStream(fh: FileHandle.standardError)
