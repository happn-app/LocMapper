/*
 * AppendedTagsStrings.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/27/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension String {
	
	func infoForSplitAppendedTags() -> (stringEndOffset: Int, tags: [String]?) {
		enum State {
			case waitStartKey
			case waitEndTag
			case waitEndTagSlash
			case remainingString
			
			func process(char: Character, withCurrentTag currentTag: inout String, currentTags: inout [String]) -> State? {
				switch self {
				case .waitStartKey:
					switch char {
					case "\"": return .remainingString
					case ",":  return .waitEndTag
					default: return nil
					}
					
				case .waitEndTag:
					switch char {
					case "/": return .waitEndTagSlash
					case ",":  currentTags.append(String(currentTag.reversed())); currentTag = ""; return .waitEndTag
					case "\"": currentTags.append(String(currentTag.reversed())); currentTag = ""; return .remainingString
					default: currentTag.append(char); return .waitEndTag
					}
					
				case .waitEndTagSlash:
					currentTag.append(char)
					return .waitEndTag
					
				case .remainingString:
					fatalError("Invalid call to engine processor on a final state.")
				}
			}
		}
		
		var tags = [String]()
		var idx = 0
		var currentTag = ""
		var currentState = State.waitStartKey
		for (curIdx, char) in reversed().enumerated() {
			guard currentState != .remainingString else {break}
			guard let newState = currentState.process(char: char, withCurrentTag: &currentTag, currentTags: &tags) else {
				return (stringEndOffset: 0, tags: nil)
			}
			currentState = newState
			idx = curIdx
		}
		
		guard currentState == .remainingString else {return (stringEndOffset: 0, tags: nil)}
		return (stringEndOffset: idx+1, tags: tags.reversed())
	}
	
	/** Parses the string (eg. the result of calling byAppending(tags:)) into the
	tags and the remaining string. If parsing the string fails, the tags will
	contain nil and string will be the original string. If parsing the string
	succeed, tags will never be nil. It might be empty though. */
	func splitAppendedTags() -> (string: String, tags: [String]?) {
		let (offset, tags) = infoForSplitAppendedTags()
		return (string: String(dropLast(offset)), tags: tags)
	}
	
	/** Returns a new string containing a serialization of the user info and the
	original string. The format guarantees that:
	
	    str.byAppending(tags: tags) == str + "".byAppending(tags: tags)
	
	Use `infoForSplitAppendedTags` or `splitAppendedTags` to de-serialize
	the user info.
	
	- returns: The new string with the serialized user info. */
	func byAppending(tags: [String]) -> String {
		var res = self
		res += "\""
		for tag in tags {
			res += tag.replacingOccurrences(of: "/", with: "//").replacingOccurrences(of: ",", with: ",/").replacingOccurrences(of: "\"", with: "\"/")
			res += ","
		}
		return res
	}
	
}
