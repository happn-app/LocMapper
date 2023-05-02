/*
 * Scanner+LinuxCompat.swift
 * XibLoc
 *
 * Created by François Lamboley on 15/09/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension Scanner {
	
	struct Location {
		
		init(index: String.Index, in str: String) {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
			if #available(OSX 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
				self.init(index: index)
			} else {
				self.init(obsolete: NSRange(str.startIndex..<index, in: str).length)
			}
#else
			self.init(index: index)
#endif
		}
		
		func offset(by offset: Int, in str: String) -> Location {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
			if #available(OSX 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
				return Location(index: str.index(index, offsetBy: offset))
			} else {
				let currentIndex = Range(NSRange(location: 0, length: obsolete), in: str)!.upperBound
				let offsetIndex = str.index(currentIndex, offsetBy: offset)
				return Location(obsolete: NSRange(str.startIndex..<offsetIndex, in: str).length)
			}
#else
			return Location(index: str.index(index, offsetBy: offset))
#endif
		}
		
		fileprivate init(index: String.Index!) {
			self.index = index
		}
		
		fileprivate init(obsolete: Int!) {
			self.obsolete = obsolete
		}
		
		fileprivate var obsolete: Int!
		fileprivate var index: String.Index!
		
	}
	
	var lm_scanLocation: Location {
		get {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
			if #available(OSX 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
				return .init(index: currentIndex)
			} else {
				return .init(obsolete: scanLocation)
			}
#else
			return .init(index: currentIndex)
#endif
		}
		set {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
			if #available(OSX 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
				currentIndex = newValue.index
			} else {
				scanLocation = newValue.obsolete
			}
#else
			currentIndex = newValue.index
#endif
		}
	}
	
	func lm_scanString(_ string: String) -> String? {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
		if #available(OSX 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
			return scanString(string)
		} else {
			var result: NSString?
			guard scanString(string, into: &result) else {return nil}
			return result! as String
		}
#else
		return scanString(string)
#endif
	}
	
	func lm_scanUpToString(_ string: String) -> String? {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
		if #available(macOS 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
			return scanUpToString(string)
		} else {
			var result: NSString?
			guard scanUpTo(string, into: &result) else {return nil}
			return result! as String
		}
#else
		return scanUpToString(string)
#endif
	}
	
	func lm_scanCharacters(from set: CharacterSet) -> String? {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
		if #available(macOS 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
			return scanCharacters(from: set)
		} else {
			var result: NSString?
			guard scanCharacters(from: set, into: &result) else {return nil}
			return result! as String
		}
#else
		return scanCharacters(from: set)
#endif
	}
	
	func lm_scanUpToCharacters(from set: CharacterSet) -> String? {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
		if #available(macOS 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *) {
			return scanUpToCharacters(from: set)
		} else {
			var result: NSString?
			guard scanUpToCharacters(from: set, into: &result) else {return nil}
			return result! as String
		}
#else
		return scanUpToCharacters(from: set)
#endif
	}
	
}
