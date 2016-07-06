/*
 * stderr.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

class StandardErrorOutputStream: OutputStream {
	func write(_ string: String) {
		let stderr = FileHandle.withStandardError
		stderr.write(string.data(using: String.Encoding.utf8)!)
	}
}

var mx_stderr = StandardErrorOutputStream()
