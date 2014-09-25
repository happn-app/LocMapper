/*
 * stderr.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

class StandardErrorOutputStream: OutputStreamType {
	func write(string: String) {
		let stderr = NSFileHandle.fileHandleWithStandardError()
		stderr.writeData(string.dataUsingEncoding(NSUTF8StringEncoding)!)
	}
}

var mx_stderr = StandardErrorOutputStream()
