/*
 * happnLocCSVDocument.swift
 * happn CSV Editor
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class happnLocCSVDocument: NSDocument, NSTokenFieldDelegate {
	
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
	
	override func windowControllerDidLoadNib(_ aController: NSWindowController) {
		super.windowControllerDidLoadNib(aController)
	}
	
	override class func autosavesInPlace() -> Bool {
		return false
	}
	
	override func makeWindowControllers() {
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
		addWindowController(windowController)
		
		sendRepresentedObjectToSubControllers()
	}
	
	override func data(ofType typeName: String) throws -> Data {
		guard let csvLocFile = csvLocFile else {
			return Data()
		}
		
		var strData = ""
		Swift.print(csvLocFile, terminator: "", to: &strData)
		guard let data = strData.data(using: String.Encoding.utf8) else {
			throw NSError(domain: "fr.happn.happn-CSV-Editor.happnLocCSVDocument", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot convert data to UTF8."])
		}
		return data
	}
	
	override func read(from data: Data, ofType typeName: String) throws {
		guard let fileContentStr = String(data: data, encoding: String.Encoding.utf8) else {
			throw NSError(domain: "fr.happn.happn-CSV-Editor.happnLocCSVDocument", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read file as UTF8."])
		}
		
		csvLocFile = nil
		DispatchQueue.global(attributes: .qosUserInitiated).async {
			do {
				let locFile = try happnCSVLocFile(filecontent: fileContentStr, withCSVSeparator: ",")
				DispatchQueue.main.async {
					self.csvLocFile = locFile
				}
			} catch {
				DispatchQueue.main.async {
					let alert = NSAlert(error: error as NSError)
					alert.runModal()
					self.close()
				}
			}
		}
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func importReferenceTranslations(sender: AnyObject) {
		guard let csvLocFile = csvLocFile else {
			NSBeep()
			return
		}
		
		/* Getting accessory view. */
		var objects: NSArray = []
		Bundle.main.loadNibNamed("AccessoryViewForImportReferenceTranslations", owner: nil, topLevelObjects: &objects)
		let accessoryView = (objects.filter {$0 is NSView} as! [NSView]).first!
		let tokenField = accessoryView.viewWithTag(1) as! NSTokenField
		
		tokenField.setDelegate(self)
		tokenField.stringValue = csvLocFile.languages.joined(separator: ",")
		
		let openPanel = NSOpenPanel()
		openPanel.canChooseFiles = true
		openPanel.allowedFileTypes = ["csv"]
		openPanel.canChooseDirectories = false
		
		/* Configuring accessory view. */
		openPanel.accessoryView = accessoryView
		openPanel.isAccessoryViewDisclosed = true
		if let superview = accessoryView.superview {
			/* Adjust size of accessory view. */
			accessoryView.frame.origin.x = superview.bounds.minX
			accessoryView.frame.size.width = superview.bounds.width
			accessoryView.autoresizingMask = [.viewWidthSizable] /* Doesn't work though :( */
		}
		
		openPanel.beginSheetModal(for: windowForSheet!) { response in
			guard response == NSFileHandlingPanelOKButton, let url = openPanel.url else {return}
			
			let languages = tokenField.stringValue.characters.split(separator: ",").map(String.init)
			do {
				let referenceTranslations = try ReferenceTranslationsLocFile(fromURL: url, languages: languages, csvSeparator: ",")
				csvLocFile.replaceReferenceTranslationsWithLocFile(referenceTranslations)
				self.updateChangeCount(.changeDone)
			} catch let error {
				NSAlert(error: error as NSError).beginSheetModal(for: self.windowForSheet!, completionHandler: nil)
			}
		}
	}
	
	/* ****************************
	   MARK: - Token Field Delegate
	   **************************** */
	
	/* Implementing this method disables the whitespace-trimming behavior. */
	func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> AnyObject {
		return editingString
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func sendRepresentedObjectToSubControllers() {
		for v in windowControllers {
			v.contentViewController?.representedObject = csvLocFile
		}
	}
	
}
