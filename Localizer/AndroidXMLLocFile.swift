/*
 * AndroidXMLLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 11/14/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



class AndroidXMLLocFile: Streamable {
	let filepath: String
	
	class ParserDelegate: NSObject, NSXMLParserDelegate {
		func parserDidStartDocument(parser: NSXMLParser!) {
			println("did start doc")
		}
		
		func parserDidEndDocument(parser: NSXMLParser!) {
			println("did end doc")
		}
		
		func parser(parser: NSXMLParser!, foundNotationDeclarationWithName name: String!, publicID: String!, systemID: String!) {
			println("foundNotationDeclarationWithName \(name) publicID \(publicID) systemID \(systemID)")
		}
		
		func parser(parser: NSXMLParser!, foundUnparsedEntityDeclarationWithName name: String!, publicID: String!, systemID: String!, notationName: String!) {
			println("foundUnparsedEntityDeclarationWithName \(name) publicID \(publicID) systemID \(systemID) notationName \(notationName)")
		}
		
		func parser(parser: NSXMLParser!, foundAttributeDeclarationWithName attributeName: String!, forElement elementName: String!, type: String!, defaultValue: String!) {
			println("foundAttributeDeclarationWithName \(attributeName) forElement \(elementName) type \(type) defaultValue \(defaultValue)")
		}
		
		func parser(parser: NSXMLParser!, foundElementDeclarationWithName elementName: String!, model: String!) {
			println("foundElementDeclarationWithName \(elementName) model \(model)")
		}
		
		func parser(parser: NSXMLParser!, foundInternalEntityDeclarationWithName name: String!, value: String!) {
			println("foundInternalEntityDeclarationWithName \(name) value \(value)")
		}
		
		func parser(parser: NSXMLParser!, foundExternalEntityDeclarationWithName name: String!, publicID: String!, systemID: String!) {
			println("foundExternalEntityDeclarationWithName \(name) publicID \(publicID) systemID \(systemID)")
		}
		
		func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: [NSObject : AnyObject]!) {
			println("didStartElement \(elementName) namespaceURI \(namespaceURI) qualifiedName \(qName) attributes \(attributeDict)")
		}
		
		func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!) {
			println("didEndElement \(elementName) namespaceURI \(namespaceURI) qualifiedName \(qName)")
		}
		
		func parser(parser: NSXMLParser!, didStartMappingPrefix prefix: String!, toURI namespaceURI: String!) {
			println("didStartMappingPrefix \(prefix) toURI \(namespaceURI)")
		}
		
		func parser(parser: NSXMLParser!, didEndMappingPrefix prefix: String!) {
			println("didEndMappingPrefix \(prefix)")
		}
		
		func parser(parser: NSXMLParser!, foundCharacters string: String!) {
			println("foundCharacters \(string)")
		}
		
		func parser(parser: NSXMLParser!, foundIgnorableWhitespace whitespaceString: String!) {
			println("foundIgnorableWhitespace \(whitespaceString)")
		}
		
		func parser(parser: NSXMLParser!, foundProcessingInstructionWithTarget target: String!, data: String!) {
			println("foundProcessingInstructionWithTarget \(target) data \(data)")
		}
		
		func parser(parser: NSXMLParser!, foundComment comment: String!) {
			println("foundComment \(comment)")
		}
		
		func parser(parser: NSXMLParser!, foundCDATA CDATABlock: NSData!) {
			println("foundCDATA \(CDATABlock)")
		}
		
		func parser(parser: NSXMLParser!, parseErrorOccurred parseError: NSError!) {
			println("parseErrorOccurred \(parseError)")
		}
		
		func parser(parser: NSXMLParser!, validationErrorOccurred validationError: NSError!) {
			println("validationErrorOccurred \(validationError)")
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
		self.init(pathRelativeToProject: path)
	}
	
	convenience init?(pathRelativeToProject: String, fileURL url: NSURL, inout error: NSError?) {
		let xmlParser: NSXMLParser! = NSXMLParser(contentsOfURL: url)
		if xmlParser == nil {
			/* Must init before failing */
			self.init(pathRelativeToProject: pathRelativeToProject)
			return nil
		}
		
		xmlParser.delegate = ParserDelegate()
		
		self.init(pathRelativeToProject: pathRelativeToProject)
	}
	
	init(pathRelativeToProject: String) {
		filepath = pathRelativeToProject
	}
	
	func writeTo<Target: OutputStreamType>(inout target: Target) {
	}
}
