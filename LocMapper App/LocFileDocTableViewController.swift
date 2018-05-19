/*
 * LocFileDocTableViewController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa

import LocMapper



class LocFileDocTableViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	
	@IBOutlet var tableView: NSTableView!
	
	var uiState: [String: Any] {
		/* Todo: Save table view info in "DocTableViewController Table View Info" */
		return [:]
	}
	
	func restoreUIState(with uiState: [String: Any]) {
		/* nop */
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		createTableViewColumnsIfNeeded(reloadData: true)
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {noteContentHasChanged()}
	}
	
	var handlerNotifyDocumentModification: (() -> Void)?
	var handlerCanChangeSelection: ((_ handlerChangeNow: @escaping () -> Void) -> Bool)?
	var handlerSetEntryViewSelection: ((_ newSelection: (LocFile.LineKey, LocFile.LineValue)?) -> Void)?
	
	func noteSelectedLineHasChanged() {
		guard tableView.selectedRow > 0 else {return}
		tableView.reloadData(forRowIndexes: IndexSet(integer: tableView.selectedRow), columnIndexes: IndexSet(integersIn: 0..<self.tableView.numberOfColumns))
	}
	
	func noteContentHasChanged() {
		tableColumnsCreated = false
		createTableViewColumnsIfNeeded(reloadData: false)
		noteFiltersHaveChanged()
	}
	
	func noteFiltersHaveChanged() {
		if let csvLocFile = csvLocFile, let filters = csvLocFile.filtersMetadataValueForKey("filters") {sortedKeys = csvLocFile.entryKeys(matchingFilters: filters + [.uiPresentable]).sorted()}
		else if let csvLocFile = csvLocFile                                                            {sortedKeys = csvLocFile.entryKeys.sorted()}
		else                                                                                           {sortedKeys = nil}
		reloadTableData()
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		switch item.action {
		case #selector(LocFileDocTableViewController.copy(_:))?:
			return tableView.selectedRow >= 0
			
		default:
			return false
//			return super.validateUserInterfaceItem(item)
		}
	}
	
	@IBAction func copy(_ sender: AnyObject) {
		guard tableView.selectedRow >= 0 else {NSSound.beep(); return}
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[tableView.selectedRow] else {NSSound.beep(); return}
		
		var val = ""
		var first = true
		for c in tableView.tableColumns {
			guard !Set(arrayLiteral: "ENV", "KEY").contains(c.identifier.rawValue) else {continue}
			
			val += (first ? "" : "\t") + csvLocFile.editorDisplayedValueForKey(key, withLanguage: c.identifier.rawValue)
			first = false
		}
		
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(val, forType: .string)
		pasteboard.setString(val, forType: .tabularText)
	}
	
	/* *****************************************
	   MARK: - Table View Data Source & Delegate
	   ***************************************** */
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		precondition(tableView == self.tableView)
		
		if let sortedKeys = sortedKeys {return sortedKeys.count}
		return 0
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		guard let tableColumn = tableColumn else {return nil}
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return nil}
		
		guard tableColumn.identifier.rawValue != "ENV" else {return key.env}
		guard tableColumn.identifier.rawValue != "KEY" else {return (key.env != "Android" ? key.locKey : key.locKey.dropFirst())}
		return csvLocFile.editorDisplayedValueForKey(key, withLanguage: tableColumn.identifier.rawValue)
	}
	
	func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return}
		guard let tableColumn = tableColumn, !Set(arrayLiteral: "ENV", "KEY").contains(tableColumn.identifier.rawValue) else {return}
		
		guard let strValue = object as? String else {return}
		_ = csvLocFile.setValue(strValue, forKey: key, withLanguage: tableColumn.identifier.rawValue)
		
		DispatchQueue.main.async {
			self.handlerNotifyDocumentModification?()
			
			tableView.beginUpdates()
			self.cachedRowsHeights.removeObject(forKey: key.env + key.filename + key.locKey as NSString)
			tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
			tableView.endUpdates()
		}
	}
	
	func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return}
		
		let color: NSColor
		switch csvLocFile.lineValueForKey(key) {
		case .none: color = NSColor.red
		case .mapping?: color = NSColor.gray
		case .entries?: color = NSColor.black
		}
		(cell as? HighlightColorTextFieldCell)?.nonHighlightedTextColor = color
	}
	
	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		/* Based on https://gist.github.com/billymeltdown/9084884 */
		let minimumHeight = CGFloat(3)
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return minimumHeight}
		
		/* Check the cache to avoid unnecessary recalculation */
		if let cachedRowHeight = cachedRowsHeights.object(forKey: key.env + key.filename + key.locKey as NSString) as? CGFloat {
			return cachedRowHeight
		}
		
		var height = minimumHeight
		for column in tableView.tableColumns {
			guard !Set(arrayLiteral: "ENV", "KEY").contains(column.identifier.rawValue) else {continue}
			
			let str = csvLocFile.editorDisplayedValueForKey(key, withLanguage: column.identifier.rawValue)
			let cell = column.dataCell as! NSCell
			cell.stringValue = str
			let rect = NSMakeRect(0, 0, column.width, CGFloat.greatestFiniteMagnitude)
			height = max(height, cell.cellSize(forBounds: rect).height)
		}
		/* To have height being a multiple of minimum height, use this:
		if (height > minimumHeight) {
			let remainder = fmod(height, minimumHeight);
			height -= remainder;
			if remainder > 0 {height += minimumHeight}
		}*/
		
		/* Add small margin to make things a little more beautiful. */
		height += 2*2
		
		/* Let’s cache the result. */
		cachedRowsHeights.setObject(height as NSNumber, forKey: key.env + key.filename + key.locKey as NSString)
		
		return height
	}
	
	/* This method is preferred over tableView(_:shouldSelectRow:) says the doc.
	 * And anyway it is the only way to prevent selection modification (including
	 * deselection) and allow applying the prevented selection modification after
	 * the prevention.
	 * Note: There is a selectionShouldChange(in:) method which is also called
	 *       when the user deselects stuff, but it does not give the expected new
	 *       selection, so there is no way to apply the selection after having
	 *       prevented it. */
	func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
		guard let handlerCanChangeSelection = handlerCanChangeSelection else {return proposedSelectionIndexes}
		
		guard handlerCanChangeSelection({tableView.selectRowIndexes(proposedSelectionIndexes, byExtendingSelection: false)}) else {
			return IndexSet(integer: tableView.selectedRow)
		}
		return proposedSelectionIndexes
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		notifyTableViewSelectionChange()
	}
	
	func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
		guard let tableColumn = tableColumn, !Set(arrayLiteral: "ENV", "KEY").contains(tableColumn.identifier.rawValue) else {return false}
		
		if row >= 0, let csvLocFile = csvLocFile, let key = sortedKeys?[tableView.selectedRow], csvLocFile.lineValueForKey(key)?.mapping != nil {
			let updateEntryToManualValues = {
				if csvLocFile.convertKeyToHardCoded(key) {
					self.tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<self.tableView.numberOfColumns))
					self.notifyTableViewSelectionChange()
					self.handlerNotifyDocumentModification?()
				}
			}
			
			if AppSettings.shared.showAlertForDiscardingMapping {
				guard let window = view.window else {return false}
				let alert = NSAlert()
				alert.messageText = "Discard Mapping"
				alert.informativeText = "If you manually set a value to a mapped entry, the mapping will be dropped."
				alert.addButton(withTitle: "OK")
				alert.addButton(withTitle: "Cancel")
				alert.showsSuppressionButton = true
				alert.beginSheetModal(for: window) { response in
					switch response {
					case .alertFirstButtonReturn:
						updateEntryToManualValues()
						if let tableColumnIndex = self.tableView.tableColumns.index(of: tableColumn) {
							self.tableView.editColumn(tableColumnIndex, row: row, with: nil, select: true)
						}
						
						/* Let's check if the user asked not to be bothered by this
						 * alert anymore. */
						if (alert.suppressionButton?.state ?? .off) == .on {
							AppSettings.shared.showAlertForDiscardingMapping = false
						}
						
					case .alertSecondButtonReturn:
						(/*nop (cancel)*/)
						
					default:
						NSLog("%@", "Unknown button response \(response)")
					}
				}
				return false
			} else {
				updateEntryToManualValues()
				return true
			}
		}
		
		return true
	}
	
	/* If we were view-based... but we're not (cell-based is still faster). */
//	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//		guard let tableColumn = tableColumn else {return nil}
//		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return nil}
//		
//		let identifier = "LocEntryCell"
//		
//		let result: NSTextField
//		if let r = tableView.make(withIdentifier: identifier, owner: self) as? NSTextField {result = r}
//		else {
//			result = NSTextField(frame: NSZeroRect)
//			result.isBordered = false
//			result.drawsBackground = false
//			result.identifier = identifier
//		}
//		
//		result.stringValue = csvLocFile.editorDisplayedValueForKey(key, withLanguage: tableColumn.identifier)
//		return result
//	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var tableColumnsCreated = false
	
	private var csvLocFile: LocFile? {
		return representedObject as? LocFile
	}
	
	private var sortedKeys: [LocFile.LineKey]?
	private let cachedRowsHeights = NSCache<NSString, NSNumber>()
	
	private func createTableViewColumnsIfNeeded(reloadData: Bool) {
		guard !tableColumnsCreated else {return}
		guard let tableView = tableView else {return}
		
		for tc in tableView.tableColumns {
			tableView.removeTableColumn(tc)
		}
		
		guard let csvLocFile = csvLocFile else {return}
		
		for l in ["ENV", "KEY"] + csvLocFile.languages {
			let tc = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: l))
			tc.title = l
			
			tc.resizingMask = .userResizingMask
			switch l {
			case "ENV": tc.width = 66
			case "KEY": tc.width = 142
			default:    tc.width = 350
			}
			
			let tfc = HighlightColorTextFieldCell(textCell: "TODOLOC")
			tfc.hightlightColor = NSColor.white
			tfc.isEditable = true
			tfc.wraps = true
			tc.dataCell = tfc
			
			tableView.addTableColumn(tc)
		}
		
		tableColumnsCreated = true
		if reloadData {reloadTableData()}
	}
	
	private func reloadTableData() {
		tableView.reloadData()
		notifyTableViewSelectionChange()
	}
	
	private func notifyTableViewSelectionChange() {
		guard tableView.selectedRow >= 0, let csvLocFile = csvLocFile, let key = sortedKeys?[tableView.selectedRow], let value = csvLocFile.lineValueForKey(key) else {
			handlerSetEntryViewSelection?(nil)
			return
		}
		handlerSetEntryViewSelection?((key, value))
	}
	
}

class HighlightColorTextFieldCell : NSTextFieldCell {
	
	var hightlightColor: NSColor? {
		didSet {
			updateTextColor()
		}
	}
	
	var nonHighlightedTextColor: NSColor? {
		didSet {
			updateTextColor()
		}
	}
	
	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			updateTextColor()
		}
	}
	
	private func updateTextColor() {
		switch backgroundStyle {
		case .dark, .raised:   textColor = hightlightColor
		case .light, .lowered: textColor = nonHighlightedTextColor
		}
	}
	
	override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
		let newTextObj = super.setUpFieldEditorAttributes(textObj)
		newTextObj.textColor = NSColor.black
		textColor = NSColor.black /* Not sure why the line above is not enough (and actually seems to do nothing...) */
		return newTextObj
	}
	
}
