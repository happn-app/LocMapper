/*
 * stdstreams.swift
 * LocMapper CLI
 *
 * From https://stackoverflow.com/a/25226794
 *
 * Created by François Lamboley on 2018-01-06.
 * Copyright © 2018 Frizlab. All rights reserved.
 */

import Foundation



final class FileHandleOutputStream : TextOutputStream, Sendable {
	
	let closeOnDeinit: Bool
	let fileHandle: FileHandle
	
	convenience init(forPath path: String) throws {
		try Data().write(to: URL(fileURLWithPath: path), options: []) /* We do not delete original file if present to keep xattrs… */
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
		_ = try? fileHandle.write(contentsOf: Data(string.utf8))
	}
	
}

/* TODO: Verify this is safe (it probably is? worst case scenario we get interleaved writes in the output AFAICT). */
nonisolated(unsafe) var stdoutStream = FileHandleOutputStream(fh: FileHandle.standardOutput)
nonisolated(unsafe) var stderrStream = FileHandleOutputStream(fh: FileHandle.standardError)
