/*
 * String+CSVUtils.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/4/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension String {
	
	func csvCellValueWithSeparator(_ sep: String) -> String {
		guard sep.utf16.count == 1, sep != "\"", sep != "\n", sep != "\r" else {fatalError("Cannot use \"\(sep)\" as a CSV separator")}
		/* We use the large “newlines” character set instead of simply \n and \r to solve some problems when solving merge conflicts with FileMerge.
		 * (FileMerge sees a weird UTF-8 newline and proposes to solve the problem by converting the newlines in the file to CR, LF or CRLF.
		 *  When it does that, a field containing such a character becomes incomplete and the line stops there.) */
		if rangeOfCharacter(from: CharacterSet(charactersIn: "\(sep)\"").union(.newlines)) != nil {
			/* Double quotes needed */
			let doubledDoubleQuotes = replacingOccurrences(of: "\"", with: "\"\"")
			return "\"\(doubledDoubleQuotes)\""
		} else {
			/* Double quotes not needed */
			return self
		}
	}
	
}
