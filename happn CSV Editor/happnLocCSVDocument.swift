/*
 * happnLocCSVDocument.swift
 * happn CSV Editor
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class happnLocCSVDocument: NSDocument {
	
	/** If nil, the file is loading. */
	var csvLocFile: happnCSVLocFile? {
		didSet {
			sendRepresentedObjectToSubControllers()
		}
	}
	
	private var mainWindowController: NSWindowController?
	
	override init() {
		csvLocFile = happnCSVLocFile()
		super.init()
	}
	
	override func windowControllerDidLoadNib(aController: NSWindowController) {
		super.windowControllerDidLoadNib(aController)
	}
	
	override class func autosavesInPlace() -> Bool {
		return false
	}
	
	override func makeWindowControllers() {
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let windowController = storyboard.instantiateControllerWithIdentifier("Document Window Controller") as! NSWindowController
		self.addWindowController(windowController)
		
		sendRepresentedObjectToSubControllers()
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
		
		csvLocFile = nil
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
			do {
				let locFile = try happnCSVLocFile(filecontent: fileContentStr, withCSVSeparator: ",")
				dispatch_async(dispatch_get_main_queue()) {
					self.csvLocFile = locFile
				}
			} catch {
				dispatch_async(dispatch_get_main_queue()) {
					let alert = NSAlert(error: error as NSError)
					alert.runModal()
					self.close()
				}
			}
		}
	}
	
	private func sendRepresentedObjectToSubControllers() {
		for v in self.windowControllers {
			v.contentViewController?.representedObject = csvLocFile
		}
	}
	
}
