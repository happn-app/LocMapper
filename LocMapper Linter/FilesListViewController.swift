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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Do any additional setup after loading the view.
	}
	
	/* *****************************************
      MARK: - Table View Data Source & Delegate
	   ***************************************** */
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return 1
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn = tableColumn else {return nil}
		return tableView.makeView(withIdentifier: tableColumn.identifier, owner: self)
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
	
	@IBAction func nicknameEdited(_ sender: AnyObject) {
		guard let textView = sender as? NSTextField else {return}
		let row = tableView.row(for: textView) /* Note: O(n)… */
		guard row >= 0 else {return}
		print("nicknameEdited")
	}
	
	@IBAction func startKeyVersionsCheck(_ sender: AnyObject) {
		print("startKeyVersionsCheck")
	}
	
}
