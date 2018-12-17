/*
 * InputFileDescription.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 13/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class InputFileDescription : NSObject, NSCoding {
	
	/* Raw value is tag in menu. */
	enum RefLocType : Int {
		
		case xibRefLoc = 1
		case stdRefLoc = 2
		
	}
	
	var nickname: String?
	var url: URL
	
	var refLocType = RefLocType.xibRefLoc
	
	init(url u: URL) {
		url = u
		
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		url = aDecoder.decodeObject(forKey: "url") as! URL
		nickname = aDecoder.decodeObject(forKey: "nickname") as? String
		refLocType = RefLocType(rawValue: aDecoder.decodeInteger(forKey: "refLocType")) ?? .xibRefLoc
		
		super.init()
	}
	
	func encode(with aCoder: NSCoder) {
		aCoder.encode(url, forKey: "url")
		aCoder.encode(nickname, forKey: "nickname")
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
