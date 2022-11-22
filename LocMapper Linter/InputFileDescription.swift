/*
 * InputFileDescription.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 13/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class InputFileDescription : NSObject, NSSecureCoding {
	
	static var supportsSecureCoding: Bool = true
	
	/* Raw value is tag in menu. */
	enum RefLocType : Int {
		
		case xibRefLoc = 1
		case stdRefLoc = 2
		
	}
	
	var nickname: String?
	
	let url: URL
	let urlBookmarkData: Data
	
	var refLocType = RefLocType.xibRefLoc
	
	init(url u: URL) throws {
		url = u
		urlBookmarkData = try u.bookmarkData()
		
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		nickname = aDecoder.decodeObject(forKey: "nickname") as? String
		refLocType = RefLocType(rawValue: aDecoder.decodeInteger(forKey: "refLocType")) ?? .xibRefLoc
		
		guard let bData = aDecoder.decodeObject(forKey: "urlBookmark") as? Data else {
			return nil
		}
		urlBookmarkData = bData
		
		var stale = false
		guard let u = try? URL(resolvingBookmarkData: urlBookmarkData, bookmarkDataIsStale: &stale) else {
			return nil
		}
		url = u
		
		super.init()
	}
	
	func encode(with aCoder: NSCoder) {
		aCoder.encode(nickname, forKey: "nickname")
		aCoder.encode(urlBookmarkData, forKey: "urlBookmark")
		aCoder.encode(refLocType.rawValue, forKey: "refLocType")
	}
	
	var stringHash: String {
		return url.path + ":" + String(refLocType.rawValue)
	}
	
	static func == (lhs: InputFileDescription, rhs: InputFileDescription) -> Bool {
		return (
			lhs.url        == rhs.url &&
			lhs.refLocType == rhs.refLocType
		)
	}
	
}
