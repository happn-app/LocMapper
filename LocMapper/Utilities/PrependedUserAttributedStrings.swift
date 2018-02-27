/*
 * UserAttributedStrings.swift
 * LocMapper
 *
 * Created by François Lamboley on 10/27/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation



extension String {
	
	func infoForSplitPrependedUserInfo() -> (stringStartOffset: Int, userInfo: [String: String]?) {
		enum State {
			case waitStartKey
			case waitEndKey
			case waitEndKeyBackslash
			case waitEndValue
			case waitEndValueBackslash
			case remainingString
			
			func process(char: Character, withCurrentKey currentKey: inout String, currentValue: inout String, currentUserInfo: inout [String: String]) -> State? {
				switch self {
				case .waitStartKey:
					switch char {
					case ";": return .remainingString
					case ",": return .waitEndKey
					default: return nil
					}
					
				case .waitEndKey:
					switch char {
					case "\\": return .waitEndKeyBackslash
					case ":": return .waitEndValue
					default: currentKey.append(char); return .waitEndKey
					}
					
				case .waitEndKeyBackslash:
					currentKey.append(char)
					return .waitEndKey
					
				case .waitEndValue:
					switch char {
					case "\\": return .waitEndValueBackslash
					case ",": currentUserInfo[currentKey] = currentValue; currentKey = ""; currentValue = ""; return .waitEndKey
					case ";": currentUserInfo[currentKey] = currentValue; currentKey = ""; currentValue = ""; return .remainingString
					default: currentValue.append(char); return .waitEndValue
					}
					
				case .waitEndValueBackslash:
					currentValue.append(char)
					return .waitEndValue
					
				case .remainingString:
					fatalError("Invalid call to engine processor on a final state.")
				}
			}
		}
		
		var userInfo = [String: String]()
		var idx = 0
		var currentKey = ""
		var currentValue = ""
		var currentState = State.waitStartKey
		for (curIdx, char) in enumerated() {
			guard currentState != .remainingString else {break}
			guard let newState = currentState.process(char: char, withCurrentKey: &currentKey, currentValue: &currentValue, currentUserInfo: &userInfo) else {
				return (stringStartOffset: 0, userInfo: nil)
			}
			currentState = newState
			idx = curIdx
		}
		
		guard currentState == .remainingString else {return (stringStartOffset: 0, userInfo: nil)}
		return (stringStartOffset: idx+1, userInfo: userInfo)
	}
	
	/** Parses the string (eg. the result of calling byPrepending(userInfo:))
	into the user info and the remaining string. If parsing the string fails, the
	userInfo will contain nil and string will be the original string. If parsing
	the string succeed, userInfo will never be nil. It might be empty though. */
	func splitPrependedUserInfo() -> (string: String, userInfo: [String: String]?) {
		let (offset, userInfo) = infoForSplitPrependedUserInfo()
		return (string: String(dropFirst(offset)), userInfo: userInfo)
	}
	
	/** Returns a new string containing a serialization of the user info and the
	original string. The format guarantees that:
	
	    str.byPrepending(userInfo: userInfo) == "".byPrepending(userInfo: userInfo) + str
	
	Use `infoForSplitPrependedUserInfo` or `splitPrependedUserInfo` to
	de-serialize the user info.
	
	- returns: The new string with the serialized user info. */
	func byPrepending(userInfo: [String: String]) -> String {
		var res = ""
		for (key, val) in userInfo {
			res += ","
			res += key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ":", with: "\\:")
			res += ":"
			res += val.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: ";", with: "\\;")
		}
		res += ";"
		res += self
		return res
	}
	
}
