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
	
	var filesDescription = [InputFileDescription]() {
		didSet {
			saveFileList()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if let v = UserDefaults.standard.value(forKey: "FilesDescription") as? [Data] {
			let u = v.map{ NSKeyedUnarchiver.unarchiveObject(with: $0) as? InputFileDescription }
			let f = u.compactMap{ $0 }
			if u.count == f.count {
				filesDescription = f
				refreshUI(reloadTableViewData: true)
			}
		}
	}
	
	/* *****************************************
      MARK: - Table View Data Source & Delegate
	   ***************************************** */
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return filesDescription.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn = tableColumn else {return nil}
		guard let r = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) else {return nil}
		
		switch tableColumn.identifier.rawValue {
		case "nickname":
			if let textField = r.viewWithTag(1) as? NSTextField {
				textField.stringValue = filesDescription[row].nickname ?? "<Unnamed>"
			}
			
		case "path":
			if let textField = r.viewWithTag(1) as? NSTextField {
				textField.stringValue = filesDescription[row].url.path
			}
			
		case "git": (/*TODO*/)
			
		case "reflocType":
			if let menuButton = r.viewWithTag(1) as? NSPopUpButton {
				menuButton.selectItem(withTag: filesDescription[row].refLocType.rawValue)
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
				self.filesDescription.append(InputFileDescription(url: url))
				self.refreshUI(reloadTableViewData: true)
			}
		})
	}
	
	@IBAction func removeSelectedFile(_ sender: AnyObject) {
		let idx = tableView.selectedRow
		guard idx >= 0 else {return}
		
		filesDescription.remove(at: idx)
		self.refreshUI(reloadTableViewData: true)
	}
	
	@IBAction func lintSelectedFile(_ sender: AnyObject) {
		let idx = tableView.selectedRow
		guard idx >= 0 else {return}
		
		let fileDescription = filesDescription[idx]
		print("lint file at path \(fileDescription.url.path)")
	}
	
	@IBAction func startKeyVersionsCheck(_ sender: AnyObject) {
		print("startKeyVersionsCheck")
	}
	
	@IBAction func nicknameEdited(_ sender: AnyObject) {
		guard let textField = sender as? NSTextField else {return}
		let row = tableView.row(for: textField) /* Note: O(n)… */
		guard row >= 0 else {return}
		
		filesDescription[row].nickname = textField.stringValue
		saveFileList()
	}
	
	@IBAction func refLocTypeEdited(_ sender: AnyObject) {
		guard let menuButton = sender as? NSPopUpButton else {return}
		let row = tableView.row(for: menuButton) /* Note: O(n)… */
		guard row >= 0 else {return}
		
		filesDescription[row].refLocType = InputFileDescription.RefLocType(rawValue: menuButton.selectedTag()) ?? .xibRefLoc
		saveFileList()
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private func saveFileList() {
		let archived = filesDescription.map{
			return NSKeyedArchiver.archivedData(withRootObject: $0)
		}
		UserDefaults.standard.set(archived, forKey: "FilesDescription")
	}
	
	private func refreshUI(reloadTableViewData: Bool) {
		if reloadTableViewData {tableView.reloadData()}
		
		let hasSelection = tableView.selectedRow >= 0
		buttonRemoveFile.isEnabled = hasSelection
		buttonLintSelectedFile.isEnabled = hasSelection && false /* Disabled for the time being (not implemented) */
		buttonKeyVersionsCheck.isEnabled = !filesDescription.isEmpty
	}
	
}