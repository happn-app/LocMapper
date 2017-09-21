/*
 * happnLocCSVDocument.swift
 * happn CSV Editor
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



private extension NSStoryboard.Name {
	
	static let main = NSStoryboard.Name(rawValue: "Main")
	
}

private extension NSStoryboard.SceneIdentifier {
	
	static let documentWindowController = NSStoryboard.SceneIdentifier(rawValue: "Document Window Controller")
	
}

private extension NSNib.Name {
	
	static let accessoryViewForImportReferenceTranslations = NSNib.Name(rawValue: "AccessoryViewForImportReferenceTranslations")
	static let accessoryViewForImportKeyStructure = NSNib.Name(rawValue: "AccessoryViewForImportKeyStructure")
	
}

class happnLocCSVDocument: NSDocument, NSTokenFieldDelegate {
	
	/** If nil, the file is loading. */
	var csvLocFile: happnCSVLocFile? {
		didSet {
			sendRepresentedObjectToSubControllers(csvLocFile)
		}
	}
	
	override init() {
		csvLocFile = happnCSVLocFile()
		super.init()
	}
	
	override func windowControllerDidLoadNib(_ aController: NSWindowController) {
		super.windowControllerDidLoadNib(aController)
	}
	
	override class var autosavesInPlace: Bool {
		return false
	}
	
	override func makeWindowControllers() {
		let storyboard = NSStoryboard(name: .main, bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: .documentWindowController) as! NSWindowController
		addWindowController(windowController)
		
		if let windowFrame = windowFrameToRestore {
			windowController.window?.setFrameFrom(windowFrame)
		}
		
		mainViewController.handlerNotifyDocumentModification = { [weak self] in
			self?.updateChangeCount(.changeDone)
		}
		
		sendRepresentedObjectToSubControllers(csvLocFile)
	}
	
	override func data(ofType typeName: String) throws -> Data {
		guard let csvLocFile = csvLocFile else {
			return Data()
		}
		
		/* Let's save the UI state */
		if let frameStr = mainWindowController?.window?.stringWithSavedFrame {csvLocFile.setMetadataValue(frameStr, forKey: "UIWindowFrame")}
		else                                                                 {csvLocFile.removeMetadata(forKey: "UIWindowFrame")}
		do    {try csvLocFile.setMetadataValue(mainViewController.uiState, forKey: "UIState")}
		catch {Swift.print("*** Warning: Cannot save UIState metadata")}
		
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
		
		windowFrameToRestore = fileContentStr.infoForSplitUserInfo().userInfo?["UIWindowFrame"]
		
		csvLocFile = nil
		DispatchQueue.global(qos: .userInitiated).async {
			do {
				let locFile = try happnCSVLocFile(filecontent: fileContentStr, csvSeparator: ",")
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
		guard currentOpenPanel == nil, let csvLocFile = csvLocFile else {
			NSSound.beep()
			return
		}
		
		/* Getting accessory view. */
		var objects: NSArray?
		Bundle.main.loadNibNamed(.accessoryViewForImportReferenceTranslations, owner: nil, topLevelObjects: &objects)
		let accessoryView = (objects ?? []).flatMap{ $0 as? NSView }.first!
		let tokenField = accessoryView.viewWithTag(1) as! NSTokenField
		
		tokenField.delegate = self
		tokenField.stringValue = csvLocFile.languages.joined(separator: ",")
		
		let openPanel = NSOpenPanel()
		currentOpenPanel = openPanel
		
		openPanel.canChooseFiles = true
		openPanel.allowedFileTypes = ["csv"]
		openPanel.canChooseDirectories = false
		
		configureAccessoryView(accessoryView, forOpenPanel: openPanel)
		
		openPanel.beginSheetModal(for: windowForSheet!) { response in
			self.currentOpenPanel = nil
			guard response == .OK, let url = openPanel.url else {return}
			
			let loadingWindow = UINavigationUtilities.createLoadingWindow()
			self.windowForSheet?.beginSheet(loadingWindow, completionHandler: nil)
			
			let languages = tokenField.stringValue.split(separator: ",").map(String.init)
			DispatchQueue.global().async {
				defer {
					DispatchQueue.main.async {
						self.mainViewController.noteContentHasChanged()
						self.windowForSheet?.endSheet(loadingWindow)
						self.updateChangeCount(.changeDone)
					}
				}
				
				do {
					let referenceTranslations = try ReferenceTranslationsLocFile(fromURL: url, languages: languages, csvSeparator: ",")
					csvLocFile.replaceReferenceTranslationsWithLocFile(referenceTranslations)
				} catch let error {
					DispatchQueue.main.async {
						NSAlert(error: error as NSError).beginSheetModal(for: self.windowForSheet!, completionHandler: nil)
					}
				}
			}
		}
	}
	
	@IBAction func importKeyStructure(sender: AnyObject) {
		guard currentOpenPanel == nil, let csvLocFile = csvLocFile else {
			NSSound.beep()
			return
		}
		
		let openPanel = NSOpenPanel()
		
		/* Getting accessory view. */
		let controller = ImportKeyStructurePanelController(nibName: .accessoryViewForImportKeyStructure, bundle: nil, csvLocFile: csvLocFile, openPanel: openPanel)!
		
		currentOpenPanel = openPanel
		configureAccessoryView(controller.view, forOpenPanel: openPanel)
		
		openPanel.beginSheetModal(for: windowForSheet!) { response in
			assert(Thread.isMainThread)
			
			openPanel.accessoryView = nil /* Fixes a crash... (macOS 10.12 (16A239j) */
			self.currentOpenPanel = nil
			
			guard response == .OK else {return}
			
			controller.saveImportSettings()
			self.updateChangeCount(.changeDone)
			
			/* Let's fetch all the data from the controller before dispatching
			 * async as we want the controller to be released on the main thread
			 * (to avoid a CATransaction warning in the logs). */
			let selectedImportType = controller.selectedImportType
			let excludedPaths = controller.excludedPaths
			let languageName = controller.importedLanguageName
			let importedFolder = controller.importedFolderForXcode
			
			let loadingWindow = UINavigationUtilities.createLoadingWindow()
			self.windowForSheet?.beginSheet(loadingWindow, completionHandler: nil)
			
			DispatchQueue.global().async {
				defer {
					DispatchQueue.main.async {
						self.mainViewController.noteContentHasChanged()
						self.windowForSheet?.endSheet(loadingWindow)
						self.updateChangeCount(.changeDone)
					}
				}
				
				do {
					switch selectedImportType {
					case .Xcode:
						guard let url = openPanel.url else {return}
						let stringsFiles = try XcodeStringsFile.stringsFilesInProject(url.absoluteURL.path, excluded_paths: excludedPaths, included_paths: ["/"+importedFolder+"/"])
						csvLocFile.mergeXcodeStringsFiles(stringsFiles, folderNameToLanguageName: [importedFolder: languageName])
						
					case .Android:
						for url in openPanel.urls {
							let urlPath = url.absoluteURL.path
							let noFilename = url.deletingLastPathComponent()
							let folderName = noFilename.lastPathComponent
							let noFolderName = noFilename.deletingLastPathComponent()
							let relativePath = "./" + urlPath.dropFirst(noFolderName.absoluteURL.path.count + 1)
							if let androidXMLLocFile = try? AndroidXMLLocFile(fromPath: relativePath, relativeToProjectPath: noFolderName.absoluteURL.path) {
								csvLocFile.mergeAndroidXMLLocStringsFiles([androidXMLLocFile], folderNameToLanguageName: [folderName: languageName])
							}
						}
					}
				} catch {
					DispatchQueue.main.async {
						NSAlert(error: error as NSError).beginSheetModal(for: self.windowForSheet!, completionHandler: nil)
					}
				}
			}
		}
	}
	
	@IBAction func exportTranslations(sender: AnyObject) {
		let alert = NSAlert()
		alert.messageText = "Unimplemented"
		alert.informativeText = "This feature has not yet been implemented. Please check with the dev!"
		alert.addButton(withTitle: "OK")
		alert.beginSheetModal(for: windowForSheet!, completionHandler: nil)
	}
	
	/* ****************************
	   MARK: - Token Field Delegate
	   **************************** */
	
	/* Implementing this method disables the whitespace-trimming behavior. */
	func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
		return editingString
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var windowFrameToRestore: String?
	
	private var currentOpenPanel: NSOpenPanel?
	
	private func sendRepresentedObjectToSubControllers(_ object: AnyObject?) {
		for w in windowControllers {
			w.contentViewController?.representedObject = csvLocFile
		}
	}
	
	private func configureAccessoryView(_ accessoryView: NSView, forOpenPanel openPanel: NSOpenPanel) {
		openPanel.accessoryView = accessoryView
		openPanel.isAccessoryViewDisclosed = true
		if let superview = accessoryView.superview {
			/* Adjust size of accessory view. */
			accessoryView.frame.origin.x = superview.bounds.minX
			accessoryView.frame.size.width = superview.bounds.width
			accessoryView.autoresizingMask = [.width] /* Doesn't work though :( */
		}
	}
	
	/* **********
	   MARK: → UI
	   ********** */
	
	/* Root Window Controller */
	
	private var mainWindowController: NSWindowController! {
		return windowControllers.first
	}
	
	/* Document Root & Loading UI */
	
	private var mainViewController: happnLocCSVDocTabViewController! {
		return mainWindowController.contentViewController as? happnLocCSVDocTabViewController
	}
	
	/* Left Pane (Filters) */
	
	private var filtersSplitViewController: happnLocCSVDocFiltersSplitViewController! {
		return mainViewController.tabViewItemDocContent.viewController as? happnLocCSVDocFiltersSplitViewController
	}
	
	private var filtersViewController: happnLocCSVDocFiltersViewController! {
		return filtersSplitViewController.splitItemFilters.viewController as? happnLocCSVDocFiltersViewController
	}
	
	/* Top-Right Pane (Translations) */
	
	private var contentSplitViewController: happnLocCSVDocContentSplitViewController! {
		return filtersSplitViewController.splitItemContent.viewController as? happnLocCSVDocContentSplitViewController
	}
	
	private var tableViewController: happnLocCSVDocTableViewController! {
		return contentSplitViewController.splitItemTableView.viewController as? happnLocCSVDocTableViewController
	}
	
	/* Bottom-Right Pane (Details) */
	
	private var locEntrySplitViewController: LocEntryViewController! {
		return contentSplitViewController.splitItemLocEntry.viewController as? LocEntryViewController
	}
	
	private var locEntryContextViewController: LocEntryContextViewController! {
		return locEntrySplitViewController.tabViewItemContext.viewController as? LocEntryContextViewController
	}
	
	private var locEntryMappingViewController: LocEntryMappingViewController! {
		return locEntrySplitViewController.tabViewItemMapping.viewController as? LocEntryMappingViewController
	}
	
	private var locEntryAdvancedMappingViewController: LocEntryAdvancedMappingViewController! {
		return locEntrySplitViewController.tabViewItemAdvancedMapping.viewController as? LocEntryAdvancedMappingViewController
	}
	
}
