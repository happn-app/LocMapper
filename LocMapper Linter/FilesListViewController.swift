/*
 * FilesListViewController.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 12/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Cocoa



class FilesListViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Do any additional setup after loading the view.
	}
	
	override var representedObject: Any? {
		didSet {
		}
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
	
}
