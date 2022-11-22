/*
 * FilesListViewController.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 12/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Cocoa



class FilesListViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate, BecameFirstResponderTextFieldDelegate {
	
	@IBOutlet var tableView: NSTableView!
	@IBOutlet var buttonAddFile: NSButton!
	@IBOutlet var buttonRemoveFile: NSButton!
	
	@IBOutlet var buttonLintSelectedFile: NSButton!
	@IBOutlet var buttonKeyVersionsCheck: NSButton!
	
	var filesDescriptions = [InputFileDescription]() {
		didSet {
			saveFileList()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if let v = UserDefaults.standard.value(forKey: "FilesDescriptions") as? [Data] {
			let u = v.map{ try? NSKeyedUnarchiver.unarchivedObject(ofClass: InputFileDescription.self, from: $0) }
			let f = u.compactMap{ $0 }
			if u.count == f.count {
				filesDescriptions = f
			}
		}
		refreshUI(reloadTableViewData: true)
	}
	
	/* *****************************************
	   MARK: - Table View Data Source & Delegate
	   ***************************************** */
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return filesDescriptions.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn = tableColumn else {return nil}
		guard let r = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) else {return nil}
		
		switch tableColumn.identifier.rawValue {
			case "nickname":
				if let textField = r.viewWithTag(1) as? NSTextField {
					textField.stringValue = filesDescriptions[row].nickname ?? "<Unnamed>"
				}
				
			case "path":
				if let textField = r.viewWithTag(1) as? NSTextField {
					textField.stringValue = filesDescriptions[row].url.path
				}
				
			case "git": (/*TODO*/)
				
			case "reflocType":
				if let menuButton = r.viewWithTag(1) as? NSPopUpButton {
					menuButton.selectItem(withTag: filesDescriptions[row].refLocType.rawValue)
				}
				
			default: NSLog("Weird…")
		}
		return r
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		refreshUI(reloadTableViewData: false)
	}
	
	/* ***************************
	   MARK: - Text Field Delegate
	   *************************** */
	
	func didBecomeFirstResponder(_ textField: NSTextField) {
		(view as? KeyEquivalentDisablingView)?.disableKeyEquivalent = true
	}
	
	func controlTextDidEndEditing(_ obj: Notification) {
		DispatchQueue.main.async{
			(self.view as? KeyEquivalentDisablingView)?.disableKeyEquivalent = false
		}
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func addFile(_ sender: AnyObject) {
		let openPanel = NSOpenPanel()
		
		openPanel.canChooseFiles = true
		openPanel.allowedFileTypes = ["lcm"]
		openPanel.canChooseDirectories = false
		
		openPanel.beginSheetModal(for: view.window!, completionHandler: { response in
			guard response == .OK, let url = openPanel.url else {return}
			
			DispatchQueue.main.async{
				do {
					self.filesDescriptions.append(try InputFileDescription(url: url))
					self.refreshUI(reloadTableViewData: true)
				} catch {
					let alert = NSAlert(error: error)
					alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
				}
			}
		})
	}
	
	@IBAction func removeSelectedFile(_ sender: AnyObject) {
		let idx = tableView.selectedRow
		guard idx >= 0 else {return}
		
		filesDescriptions.remove(at: idx)
		self.refreshUI(reloadTableViewData: true)
	}
	
	@IBAction func lintSelectedFile(_ sender: AnyObject) {
		let idx = tableView.selectedRow
		guard idx >= 0 else {return}
		
		let fileDescription = filesDescriptions[idx]
		print("lint file at path \(fileDescription.url.path)")
	}
	
	@IBAction func startKeyVersionsCheck(_ sender: AnyObject) {
		let windowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "KeyVersionCheckResultsWindowController") as! NSWindowController
		let viewController = windowController.contentViewController as! KeyVersionsCheckViewController
		viewController.filesDescriptions = filesDescriptions
		windowController.showWindow(nil)
	}
	
	@IBAction func nicknameEdited(_ sender: AnyObject) {
		guard let textField = sender as? NSTextField else {return}
		let row = tableView.row(for: textField) /* Note: O(n)… */
		guard row >= 0 else {return}
		
		filesDescriptions[row].nickname = textField.stringValue
		saveFileList()
	}
	
	@IBAction func refLocTypeEdited(_ sender: AnyObject) {
		guard let menuButton = sender as? NSPopUpButton else {return}
		let row = tableView.row(for: menuButton) /* Note: O(n)… */
		guard row >= 0 else {return}
		
		filesDescriptions[row].refLocType = InputFileDescription.RefLocType(rawValue: menuButton.selectedTag()) ?? .xibRefLoc
		saveFileList()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func saveFileList() {
		let archived = filesDescriptions.map{
			return try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
		}
		UserDefaults.standard.set(archived, forKey: "FilesDescriptions")
	}
	
	private func refreshUI(reloadTableViewData: Bool) {
		if reloadTableViewData {tableView.reloadData()}
		
		let hasSelection = tableView.selectedRow >= 0
		buttonRemoveFile.isEnabled = hasSelection
		buttonLintSelectedFile.isEnabled = hasSelection && false /* Disabled for the time being (not implemented) */
		buttonKeyVersionsCheck.isEnabled = !filesDescriptions.isEmpty
	}
	
}
