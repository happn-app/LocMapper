/*
 * TaggedObject.swift
 * LocMapper
 *
 * Created by François Lamboley on 02/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



typealias TaggedString = TaggedObject<String>

struct TaggedObject<O> : CustomDebugStringConvertible {
	
	var value: O
	var tags: [String]
	
	init(value v: O, tags t: [String]) {
		value = v
		tags = t
	}
	
	var debugDescription: String {
		return "\"\(value)\"<" + tags.joined(separator: ",") + ">"
	}
	
}


extension TaggedObject : Equatable where O : Equatable {
	
	static func ==(lhs: TaggedObject<O>, rhs: TaggedObject<O>) -> Bool {
		return lhs.value == rhs.value && lhs.tags == rhs.tags
	}
	
}


extension TaggedObject : Hashable where O : Hashable {
	
	var hashValue: Int {
		return value.hashValue &+ tags.reduce(0, { $0 &+ $1.hashValue })
	}
	
}


extension TaggedObject where O == String {
	
	init(string: String) {
		let (v, t) = string.splitAppendedTags()
		self.init(value: v, tags: t ?? [])
	}
	
}
