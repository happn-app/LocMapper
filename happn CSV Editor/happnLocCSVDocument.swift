/*
 * happnLocCSVDocument.swift
 * happn CSV Editor
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class happnLocCSVDocument: NSDocument {
	
	var csvLocFile: happnCSVLocFile
	
	override init() {
		csvLocFile = happnCSVLocFile()
		super.init()
	}
	
	override func windowControllerDidLoadNib(aController: NSWindowController) {
		super.windowControllerDidLoadNib(aController)
		// Add any code here that needs to be executed once the windowController has loaded the document's window.
	}
	
	override class func autosavesInPlace() -> Bool {
		return false
	}
	
	override func makeWindowControllers() {
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let windowController = storyboard.instantiateControllerWithIdentifier("Document Window Controller") as! NSWindowController
		self.addWindowController(windowController)
	}
	
	override func dataOfType(typeName: String) throws -> NSData {
		var strData = ""
		print(csvLocFile, terminator: "", toStream: &strData)
		guard let data = strData.dataUsingEncoding(NSUTF8StringEncoding) else {
			throw NSError(domain: "fr.happn.happn-CSV-Editor.happnLocCSVDocument", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot convert data to UTF8."])
		}
		return data
	}
	
	override func readFromData(data: NSData, ofType typeName: String) throws {
		guard let fileContentStr = String(data: data, encoding: NSUTF8StringEncoding) else {
			throw NSError(domain: "fr.happn.happn-CSV-Editor.happnLocCSVDocument", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read file as UTF8."])
		}
		
		csvLocFile = try happnCSVLocFile(filecontent: fileContentStr, withCSVSeparator: ",")
	}
	
}
