/*
 * TaggedObject.swift
 * LocMapper
 *
 * Created by François Lamboley on 02/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



public typealias TaggedString = TaggedObject<String>

public struct TaggedObject<O> : CustomDebugStringConvertible {
	
	var value: O
	var tags: [String]
	
	public init(value v: O, tags t: [String]) {
		value = v
		tags = t
	}
	
	public var debugDescription: String {
		return "\"\(value)\"<" + tags.joined(separator: ",") + ">"
	}
	
}


extension TaggedObject : Equatable where O : Equatable {
}


extension TaggedObject : Hashable where O : Hashable {
}


public extension TaggedObject where O == String {
	
	init(string: String) {
		let (v, t) = string.splitAppendedTags()
		self.init(value: v, tags: t ?? [])
	}
	
}
