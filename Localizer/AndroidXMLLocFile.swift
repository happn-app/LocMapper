/*
 * AndroidXMLLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 11/14/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



protocol AndroidLocComponent {
	var stringValue: String { get }
}

extension String {
	var xmlTextValue: String {
		var v = self
//		v = v.stringByReplacingOccurrencesOfString("\\", withString: "\\\\", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("\"", withString: "\\\"", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("'", withString: "\\'", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("<", withString: "&lt;", options: NSStringCompareOptions.LiteralSearch)
		return v
	}
	var valueFromXMLText: String {
		var v = self
		v = v.stringByReplacingOccurrencesOfString("&lt;", withString: "<", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("&gt;", withString: ">", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("\\'", withString: "'", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("\\\"'", withString: "\"", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("\\\\", withString: "\\", options: NSStringCompareOptions.LiteralSearch)
		return v
	}
}

class AndroidXMLLocFile: Streamable {
	let filepath: String
	let components: [AndroidLocComponent]
	
	class GroupOpening: AndroidLocComponent {
		let fullString: String
		let groupNameAndAttr: (String, [String: String])?
		
		var stringValue: String {
			return fullString
		}
		
		init(fullString: String) {
			self.fullString = fullString
		}
		
		init(groupName: String, attributes: [String: String]) {
			self.groupNameAndAttr = (groupName, attributes)
			
			var ret = "<\(groupName)"
			for attr in attributes {
				ret += " \(attr.0)=\"\(attr.1)\""
			}
			ret += ">"
			self.fullString = ret
		}
	}
	
	class GroupClosing: AndroidLocComponent {
		let groupName: String
		let nameAttr: String?
		
		var stringValue: String {
			return "</\(groupName)>"
		}
		
		convenience init(groupName: String) {
			self.init(groupName: groupName, nameAttributeValue: nil)
		}
		
		init(groupName: String, nameAttributeValue: String?) {
			self.groupName = groupName
			self.nameAttr = nameAttributeValue
		}
	}
	
	class WhiteSpace: AndroidLocComponent {
		let content: String
		
		var stringValue: String {return content}
		
		init(_ c: String) {
			assert(c.rangeOfCharacterFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet) == nil, "Invalid white space string")
			content = c
		}
	}
	
	class Comment: AndroidLocComponent {
		let content: String
		
		var stringValue: String {return "<!--\(content)-->"}
		
		init(_ c: String) {
			assert(c.rangeOfString("-->") == nil, "Invalid comment string")
			content = c
		}
	}
	
	class StringValue: AndroidLocComponent {
		let key: String
		let value: String
		
		var stringValue: String {
			return "<string name=\"\(key)\">\(value.xmlTextValue)</string>"
		}
		
		init(key k: String, value v: String) {
			key = k
			value = v
		}
	}
	
	class ArrayItem: AndroidLocComponent {
		let idx: Int
		let value: String
		let parentName: String
		
		var stringValue: String {
			return "<item>\(value.xmlTextValue)</string>"
		}
		
		init(value v: String, index: Int, parentName pn: String) {
			value = v
			idx = index
			parentName = pn
		}
	}
	
	class PluralItem: AndroidLocComponent {
		let quantity: String
		let value: String
		let parentName: String
		
		var stringValue: String {
			return "<item quantity=\"\(quantity)\">\(value.xmlTextValue)</string>"
		}
		
		init(quantity q: String, value v: String, parentName pn: String) {
			quantity = q
			value = v
			parentName = pn
		}
	}
	
	class ParserDelegate: NSObject, NSXMLParserDelegate {
		/* Equality comparison does not compare argument values for cases with
		 * arguments */
		enum Status: Equatable {
			case OutStart
			case InResources
			case InString(String /* key */)
			case InArray(String /* key */), InArrayItem
			case InPlurals(String /* key */), InPluralItem(String /* quantity */)
			case OutEnd
			
			case Error
			
			func numericId() -> Int {
				switch self {
					case .OutStart:     return 0
					case .InResources:  return 1
					case .InString:     return 2
					case .InArray:      return 3
					case .InArrayItem:  return 4
					case .InPlurals:    return 5
					case .InPluralItem: return 6
					case .OutEnd:       return 7
					case .Error:        return 8
				}
			}
		}
		
		var currentArrayIdx = 0
		var currentChars = String()
		var currentGroupName: String?
		var previousStatus = Status.Error
		var status: Status = .OutStart {
			willSet {
				previousStatus = status
			}
		}
		var components = [AndroidLocComponent]()
		
		func parserDidStartDocument(parser: NSXMLParser!) {
			assert(status == .OutStart)
		}
		
		func parserDidEndDocument(parser: NSXMLParser!) {
			if status != Status.OutEnd {
				parser.abortParsing()
			}
		}
		
		func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: [NSObject : AnyObject]!) {
//			println("didStartElement \(elementName) namespaceURI \(namespaceURI) qualifiedName \(qName) attributes \(attributeDict)")
			let attrs = attributeDict as [String: String]
			
			switch (status, elementName) {
				case (.OutStart, "resources"):
					status = .InResources
				
				case (.InResources, "string"):
					if let name = attrs["name"] {status = .InString(name)}
					else                        {status = .Error}
				
				case (.InResources, "string-array"):
					if let name = attrs["name"] {status = .InArray(name); currentGroupName = name}
					else                        {status = .Error}
				
				case (.InResources, "plurals"):
					if let name = attrs["name"] {status = .InPlurals(name); currentGroupName = name}
					else                        {status = .Error}
				
				case (.InArray, "item"):
					status = .InArrayItem
				
				case (.InPlurals, "item"):
					if let quantity = attrs["quantity"] {status = .InPluralItem(quantity)}
					else                                {status = .Error}
				
				default:
					status = .Error
			}
			
			if status == .Error {
				parser.abortParsing()
				return
			}
			
			if countElements(currentChars) > 0 {
				components.append(WhiteSpace(currentChars))
				currentChars = ""
			}
			if elementName != "string" && elementName != "item" {
				components.append(GroupOpening(groupName: elementName, attributes: attrs))
			}
		}
		
		func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!) {
//			println("didEndElement \(elementName) namespaceURI \(namespaceURI) qualifiedName \(qName)")
			switch (status, elementName) {
				case (.InResources, "resources"):
					if countElements(currentChars) > 0 {components.append(WhiteSpace(currentChars))}
					components.append(GroupClosing(groupName: elementName))
					status = .OutEnd
				
				case (.InString(let name), "string"):
					components.append(StringValue(key: name, value: currentChars.valueFromXMLText))
					status = .InResources
				
				case (.InArray, "string-array"):
					currentArrayIdx = 0
					fallthrough
				case (.InPlurals, "plurals"):
					if countElements(currentChars) > 0 {components.append(WhiteSpace(currentChars))}
					components.append(GroupClosing(groupName: elementName, nameAttributeValue: currentGroupName))
					currentGroupName = nil
					status = .InResources
				
				case (.InArrayItem, "item"):
					switch previousStatus {
					case .InArray(let arrayName):
						components.append(ArrayItem(value: currentChars.valueFromXMLText, index: currentArrayIdx++, parentName: arrayName))
						status = previousStatus
					default:
						status = .Error
					}
				
				case (.InPluralItem(let quantity), "item"):
					switch previousStatus {
					case .InPlurals(let pluralsName):
						components.append(PluralItem(quantity: quantity, value: currentChars.valueFromXMLText, parentName: pluralsName))
						status = previousStatus
					default:
						status = .Error
					}
				
				default:
					status = .Error
			}
			
			currentChars = ""
			
			if status == .Error {
				parser.abortParsing()
				return
			}
		}
		
		func parser(parser: NSXMLParser!, foundCharacters string: String!) {
//			println("foundCharacters \(string)")
			currentChars += string
		}
		
		func parser(parser: NSXMLParser!, foundIgnorableWhitespace whitespaceString: String!) {
			println("foundIgnorableWhitespace \(whitespaceString)")
		}
		
		func parser(parser: NSXMLParser!, foundComment comment: String!) {
//			println("foundComment \(comment)")
			switch status {
				case .InResources: fallthrough
				case .InArray:     fallthrough
				case .InPlurals:
					if countElements(currentChars) > 0 {
						components.append(WhiteSpace(currentChars))
						currentChars = ""
					}
					components.append(Comment(comment))
				default:
					parser.abortParsing()
					status = .Error
			}
		}
		
		func parser(parser: NSXMLParser!, foundCDATA CDATABlock: NSData!) {
			println("foundCDATA \(CDATABlock)")
		}
		
		func parser(parser: NSXMLParser!, parseErrorOccurred parseError: NSError!) {
			println("parseErrorOccurred \(parseError)")
		}
	}
	
	class func locFilesInProject(root_folder: String, resFolder: String, stringsFilenames: [String], languageFolderNames: [String], inout err: NSError?) -> [AndroidXMLLocFile]? {
		var parsed_loc_files = [AndroidXMLLocFile]()
		for languageFolder in languageFolderNames {
			for stringsFilename in stringsFilenames {
				var err: NSError?
				let cur_file = resFolder.stringByAppendingPathComponent(languageFolder).stringByAppendingPathComponent(stringsFilename)
				if let locFile = AndroidXMLLocFile(fromPath: cur_file, relativeToProjectPath: root_folder, error: &err) {
					parsed_loc_files.append(locFile)
				} else {
					println("*** Warning: Got error while parsing strings file \(cur_file): \(err)", &mx_stderr)
				}
			}
		}
		return parsed_loc_files
	}
	
	convenience init?(fromPath path: String, relativeToProjectPath projectPath: String, inout error: NSError?) {
		if let url = NSURL(fileURLWithPath: projectPath.stringByAppendingPathComponent(path)) {
			self.init(pathRelativeToProject: path, fileURL: url, error: &error)
		} else {
			self.init(pathRelativeToProject: path, components: [])
			return nil
		}
	}
	
	convenience init?(pathRelativeToProject: String, fileURL url: NSURL, inout error: NSError?) {
		let xmlParser: NSXMLParser! = NSXMLParser(contentsOfURL: url)
		if xmlParser == nil {
			/* Must init before failing */
			self.init(pathRelativeToProject: pathRelativeToProject, components: [])
			return nil
		}
		
		let parserDelegate = ParserDelegate()
		xmlParser.delegate = parserDelegate
		xmlParser.parse()
		if parserDelegate.status != .OutEnd {
			self.init(pathRelativeToProject: pathRelativeToProject, components: [])
			return nil
		}
		
		self.init(pathRelativeToProject: pathRelativeToProject, components: parserDelegate.components)
	}
	
	init(pathRelativeToProject: String, components: [AndroidLocComponent]) {
		self.filepath   = pathRelativeToProject
		self.components = components
	}
	
	func writeTo<Target: OutputStreamType>(inout target: Target) {
		"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n".writeTo(&target)
		for component in components {
			component.stringValue.writeTo(&target)
		}
	}
}

func ==(val1: AndroidXMLLocFile.ParserDelegate.Status, val2: AndroidXMLLocFile.ParserDelegate.Status) -> Bool {
	return val1.numericId() == val2.numericId()
}
