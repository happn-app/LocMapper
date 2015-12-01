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
		v = v.stringByReplacingOccurrencesOfString("&", withString: "&amp;", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("<", withString: "&lt;", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString(">", withString: "&gt;", options: NSStringCompareOptions.LiteralSearch) /* Shouldn't be needed... */
		return v
	}
	var valueFromXMLText: String {
		var v = self
		v = v.stringByReplacingOccurrencesOfString("\\'", withString: "'", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("\\\"'", withString: "\"", options: NSStringCompareOptions.LiteralSearch)
		v = v.stringByReplacingOccurrencesOfString("\\\\", withString: "\\", options: NSStringCompareOptions.LiteralSearch)
		return v
	}
}

class AndroidXMLLocFile: Streamable {
	let filepath: String
	let components: [AndroidLocComponent]
	
	class GenericGroupOpening: AndroidLocComponent {
		let fullString: String
		let groupNameAndAttr: (String, [String: String])?
		
		var stringValue: String {
			return fullString
		}
		
		init(fullString: String) {
			self.groupNameAndAttr = nil
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
	
	class GenericGroupClosing: AndroidLocComponent {
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
		let isCDATA: Bool
		
		var stringValue: String {
			if value.xmlTextValue.isEmpty {
				return "<string name=\"\(key)\"/>"
			}
			if !isCDATA {return "<string name=\"\(key)\">\(value.xmlTextValue)</string>"}
			else        {return "<string name=\"\(key)\"><![CDATA[\(value)]]></string>"}
		}
		
		init(key k: String, value v: String) {
			key = k
			value = v
			isCDATA = false
		}
		
		init(key k: String, cDATAValue v: String) {
			key = k
			value = v
			isCDATA = true
		}
	}
	
	class ArrayItem: AndroidLocComponent {
		let idx: Int
		let value: String
		let parentName: String
		
		var stringValue: String {
			return "<item>\(value.xmlTextValue)</item>"
		}
		
		init(value v: String, index: Int, parentName pn: String) {
			value = v
			idx = index
			parentName = pn
		}
	}
	
	class PluralGroup: AndroidLocComponent {
		class PluralItem: AndroidLocComponent {
			let quantity: String
			let value: String
			let isCDATA: Bool
			
			var stringValue: String {
				if value.xmlTextValue.isEmpty {
					return "<item quantity=\"\(quantity)\"/>"
				}
				if !isCDATA {return "<item quantity=\"\(quantity)\">\(value.xmlTextValue)</item>"}
				else        {return "<item quantity=\"\(quantity)\"><![CDATA[\(value)]]></item>"}
			}
			
			init(quantity q: String, value v: String) {
				quantity = q
				value = v
				isCDATA = false
			}
			
			init(quantity q: String, cDATAValue v: String) {
				quantity = q
				value = v
				isCDATA = true
			}
		}
		
		let name: String
		let values: [String /* Quantity */: ([AndroidLocComponent /* Only WhiteSpace and Comment */], PluralItem)?]
		
		var stringValue: String {
			var ret = "<plurals name=\"\(name)\">"
			for (quantity, value) in values where value != nil {
				let (spaces, pluralItem) = value!
				assert(pluralItem.quantity == quantity)
				
				for component in spaces {ret += component.stringValue}
				ret += pluralItem.stringValue
			}
			return ret
		}
		
		init(name n: String, values v: [String /* Quantity */: ([AndroidLocComponent], PluralItem)?]) {
			name = n
			values = v
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
		var isCurrentCharsCDATA = false
		var previousStatus = Status.Error
		var status: Status = .OutStart {
			willSet {
				previousStatus = status
			}
		}
		var components = [AndroidLocComponent]()
		
		var currentPluralSpaces = [AndroidLocComponent]()
		var currentPluralValues: [String /* Quantity */: ([AndroidLocComponent], PluralGroup.PluralItem)?]?
		
		private var addingSpacesToPlural = false
		private func addSpaceComponent(space: AndroidLocComponent) {
			assert(space is WhiteSpace || space is Comment)
			if !addingSpacesToPlural {components.append(space)}
			else                     {currentPluralSpaces.append(space)}
		}
		
		func parserDidStartDocument(parser: NSXMLParser) {
			assert(status == .OutStart)
		}
		
		func parserDidEndDocument(parser: NSXMLParser) {
			if status != Status.OutEnd {
				parser.abortParsing()
			}
		}
		
		func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
//			println("didStartElement \(elementName) namespaceURI \(namespaceURI) qualifiedName \(qName) attributes \(attributeDict)")
			let attrs = attributeDict 
			
			if currentChars.characters.count > 0 {
				addSpaceComponent(WhiteSpace(currentChars))
				currentChars = ""
			}
			
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
					if let name = attrs["name"] {status = .InPlurals(name); currentGroupName = name; addingSpacesToPlural = true; currentPluralValues = [:]}
					else                        {status = .Error}
				
				case (.InArray, "item"):
					status = .InArrayItem
				
				case (.InPlurals, "item"):
					if let quantity = attrs["quantity"] {status = .InPluralItem(quantity)}
					else                                {status = .Error}
				
				default:
					currentChars += "<\(elementName)>"
					return
					//status = .Error
			}
			
			if status == .Error {
				parser.abortParsing()
				return
			}
			
			if elementName != "string" && elementName != "plurals" && elementName != "item" {
				components.append(GenericGroupOpening(groupName: elementName, attributes: attrs))
			}
		}
		
		func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
//			println("didEndElement \(elementName) namespaceURI \(namespaceURI) qualifiedName \(qName)")
			switch (status, elementName) {
				case (.InResources, "resources"):
					if currentChars.characters.count > 0 {addSpaceComponent(WhiteSpace(currentChars))}
					components.append(GenericGroupClosing(groupName: elementName))
					status = .OutEnd
				
				case (.InString(let name), "string"):
					let stringValue: StringValue
					if !isCurrentCharsCDATA {stringValue = StringValue(key: name, value: currentChars.valueFromXMLText)}
					else                    {stringValue = StringValue(key: name, cDATAValue: currentChars)}
					components.append(stringValue)
					status = .InResources
				
				case (.InArray, "string-array"):
					currentArrayIdx = 0
					if currentChars.characters.count > 0 {addSpaceComponent(WhiteSpace(currentChars))}
					components.append(GenericGroupClosing(groupName: elementName, nameAttributeValue: currentGroupName))
					currentGroupName = nil
					status = .InResources
				
				case (.InPlurals(let pluralsName), "plurals"):
					components.append(PluralGroup(name: pluralsName, values: currentPluralValues!))
					addingSpacesToPlural = false
					currentPluralValues = nil
					
					if currentChars.characters.count > 0 {addSpaceComponent(WhiteSpace(currentChars))}
					components.append(GenericGroupClosing(groupName: elementName, nameAttributeValue: currentGroupName))
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
						if currentPluralValues![quantity] != nil {
							print("*** Warning: Got more than one value for quantity \(quantity) of plurals named \(pluralsName)...")
							print("             Choosing the latest one found.")
						}
						currentPluralValues![quantity] = (
							currentPluralSpaces,
							isCurrentCharsCDATA ?
								PluralGroup.PluralItem(quantity: quantity, cDATAValue: currentChars) :
								PluralGroup.PluralItem(quantity: quantity, value: currentChars.valueFromXMLText)
						)
						currentPluralSpaces.removeAll()
						status = previousStatus
					default:
						status = .Error
					}
				
				default:
					currentChars += "</\(elementName)>"
					return
					//status = .Error
			}
			
			currentChars = ""
			
			if status == .Error {
				parser.abortParsing()
				return
			}
		}
		
		func parser(parser: NSXMLParser, foundCharacters string: String) {
//			println("foundCharacters \(string)")
			if isCurrentCharsCDATA && currentChars.characters.count > 0 {
				print("Error parsing XML file: found non-CDATA character, but I also have CDATA characters.", toStream: &mx_stderr)
				parser.abortParsing()
				status = .Error
				return
			}
			
			isCurrentCharsCDATA = false
			currentChars += string
		}
		
		func parser(parser: NSXMLParser, foundIgnorableWhitespace whitespaceString: String) {
			print("foundIgnorableWhitespace \(whitespaceString)")
		}
		
		func parser(parser: NSXMLParser, foundComment comment: String) {
//			println("foundComment \(comment)")
			
			switch status {
				case .InResources: fallthrough
				case .InArray:     fallthrough
				case .InPlurals:
					if currentChars.characters.count > 0 {
						addSpaceComponent(WhiteSpace(currentChars))
						currentChars = ""
					}
					addSpaceComponent(Comment(comment))
				default:
					parser.abortParsing()
					status = .Error
			}
		}
		
		func parser(parser: NSXMLParser, foundCDATA CDATABlock: NSData) {
			if !isCurrentCharsCDATA && currentChars.characters.count > 0 {
				print("Error parsing XML file: found CDATA block, but I also have non-CDATA characters.", toStream: &mx_stderr)
				parser.abortParsing()
				status = .Error
				return
			}
			
			isCurrentCharsCDATA = true
			if let str = NSString(data: CDATABlock, encoding: NSUTF8StringEncoding) as? String {currentChars += str}
		}
		
		func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
			print("parseErrorOccurred \(parseError)")
		}
	}
	
	class func locFilesInProject(root_folder: String, resFolder: String, stringsFilenames: [String], languageFolderNames: [String]) throws -> [AndroidXMLLocFile] {
		var parsed_loc_files = [AndroidXMLLocFile]()
		for languageFolder in languageFolderNames {
			for stringsFilename in stringsFilenames {
				var err: NSError?
				let cur_file = ((resFolder as NSString).stringByAppendingPathComponent(languageFolder) as NSString).stringByAppendingPathComponent(stringsFilename)
				do {
					let locFile = try AndroidXMLLocFile(fromPath: cur_file, relativeToProjectPath: root_folder)
					parsed_loc_files.append(locFile)
				} catch let error as NSError {
					err = error
					print("*** Warning: Got error while parsing strings file \(cur_file): \(err)", toStream: &mx_stderr)
				}
			}
		}
		return parsed_loc_files
	}
	
	convenience init(fromPath path: String, relativeToProjectPath projectPath: String) throws {
		let url = NSURL(fileURLWithPath: (projectPath as NSString).stringByAppendingPathComponent(path))
		try self.init(pathRelativeToProject: path, fileURL: url)
	}
	
	convenience init(pathRelativeToProject: String, fileURL url: NSURL) throws {
		let error: NSError! = NSError(domain: "Migrator", code: 0, userInfo: nil)
		let xmlParser: NSXMLParser! = NSXMLParser(contentsOfURL: url)
		if xmlParser == nil {
			/* Must init before failing */
			self.init(pathRelativeToProject: pathRelativeToProject, components: [])
			throw error
		}
		
		let parserDelegate = ParserDelegate()
		xmlParser.delegate = parserDelegate
		xmlParser.parse()
		if parserDelegate.status != .OutEnd {
			self.init(pathRelativeToProject: pathRelativeToProject, components: [])
			throw error
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
