/*
 * UserAttributedStrings.swift
 * Localizer
 *
 * Created by François Lamboley on 10/27/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation



extension String {
	
	/** Parses the string (eg. the result of calling byPrepending(userInfo:))
	into the user info and the remaining string. If parsing the string fails, the
	userInfo will contain nil and string will be the original string. If parsing
	the string succeed, userInfo will never be nil. It might be empty though. */
	func splitUserInfo() -> (string: String, userInfo: [String: String]?) {
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
					default: currentKey.characters.append(char); return .waitEndKey
					}
					
				case .waitEndKeyBackslash:
					currentKey.characters.append(char)
					return .waitEndKey
					
				case .waitEndValue:
					switch char {
					case "\\": return .waitEndValueBackslash
					case ",": currentUserInfo[currentKey] = currentValue; currentKey = ""; currentValue = ""; return .waitEndKey
					case ";": currentUserInfo[currentKey] = currentValue; currentKey = ""; currentValue = ""; return .remainingString
					default: currentValue.characters.append(char); return .waitEndValue
					}
					
				case .waitEndValueBackslash:
					currentValue.characters.append(char)
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
		for (curIdx, char) in characters.enumerated() {
			guard currentState != .remainingString else {break}
			guard let newState = currentState.process(char: char, withCurrentKey: &currentKey, currentValue: &currentValue, currentUserInfo: &userInfo) else {
				return (string: self, userInfo: nil)
			}
			currentState = newState
			idx = curIdx
		}
		
		guard currentState == .remainingString else {return (string: self, userInfo: nil)}
		return (string: self.substring(from: characters.index(characters.startIndex, offsetBy: idx+1)), userInfo: userInfo)
	}
	
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
