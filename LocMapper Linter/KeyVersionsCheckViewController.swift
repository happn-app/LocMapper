/*
 * KeyVersionsCheckViewController.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 13/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import AppKit

import LocMapper



private struct NotFinishedError : Error {}

class KeyVersionsCheckViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var tableView: NSTableView!
	
	var filesDescriptions: [InputFileDescription]!
	
	override func viewDidAppear() {
		super.viewDidAppear()
		
		guard reports == nil else {return}
		reports = []
		
		assert(simplifiedUntaggedKeysReferencedInMappingsByFile == nil)
		simplifiedUntaggedKeysReferencedInMappingsByFile = [:]
		
		/* Let's setup the table view columns */
		for column in tableView.tableColumns {
			tableView.removeTableColumn(column)
		}
		let nib = tableView.registeredNibsByIdentifier!.values.first!
		let w = (tableView.bounds.width) / CGFloat(filesDescriptions.count + 1) - 3
		let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("__REF"))
		c.title = "Latest Version in RefLoc"
		c.width = w
		tableView.addTableColumn(c)
		tableView.register(nib, forIdentifier: c.identifier)
		for file in filesDescriptions {
			let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(file.stringHash))
			c.title = file.nickname ?? file.url.lastPathComponent
			c.width = w
			tableView.addTableColumn(c)
			tableView.register(nib, forIdentifier: c.identifier)
		}
		
		progressIndicator.startAnimation(nil)
		getStdRefLoc()
	}
	
	/* *******************************************
      MARK: - Table View Data Source and Delegate
	   ******************************************* */
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return reports?.count ?? 0
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn = tableColumn else {return nil}
		guard let r = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) else {return nil}
		
//		let red = NSColor.red.blended(withFraction: 0.13, of: .black)
		let green = NSColor.green.blended(withFraction: 0.50, of: .black)
		let orange = NSColor.orange.blended(withFraction: 0.09, of: .black)
		
		if let textField = r.viewWithTag(1) as? NSTextField {
			switch tableColumn.identifier.rawValue {
			case "__REF":
				switch reports[row] {
				case .versionReport(latestRefLocKey: let l, mappedKeys: _):
					(textField.cell as? ColorFixedTextFieldCell)?.expectedTextColor = .textColor
					textField.stringValue = l
				}
				
			default:
				switch reports[row] {
				case .versionReport(latestRefLocKey: let l, mappedKeys: let mapped):
					if let key = mapped[tableColumn.identifier.rawValue] {
						(textField.cell as? ColorFixedTextFieldCell)?.expectedTextColor = (key == l ? green : orange)
						textField.stringValue = key
					} else {
						(textField.cell as? ColorFixedTextFieldCell)?.expectedTextColor = .gray
						textField.stringValue = "<UNMAPPED>"
					}
				}
			}
		}
		return r
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private enum Report {
		
		case versionReport(latestRefLocKey: String, mappedKeys: [String /* stringHash of a InputFileDescription */: String])
		
	}
	
	private var reports: [Report]!
	
	private let queue = OperationQueue()
	private var simplifiedGroupedOctothorpedUntaggedRefLocKeys: [String: [String]]!
	
	private var simplifiedUntaggedKeysReferencedInMappingsByFile: [InputFileDescription: Set<String>]!
	
	private func getStdRefLoc() {
		queue.addOperation{
			assert(self.simplifiedGroupedOctothorpedUntaggedRefLocKeys == nil)
			do {
				let stdRefLoc = try StdRefLocFile(token: PreferencesViewController.accessToken, projectId: PreferencesViewController.projectId, lokaliseToReflocLanguageName: PreferencesViewController.languagesNameMappings, excludedTags: PreferencesViewController.excludedTags, logPrefix: nil)
				let xibRefLoc = try XibRefLocFile(stdRefLoc: stdRefLoc)
				let stdRefLocFile = LocFile(csvSeparator: ","); stdRefLocFile.mergeRefLocsWithStdRefLocFile(stdRefLoc, mergeStyle: .replace)
				let xibRefLocFile = LocFile(csvSeparator: ","); xibRefLocFile.mergeRefLocsWithXibRefLocFile(xibRefLoc, mergeStyle: .replace)
				
				var simplifiedStdGroupedOctothorpedUntaggedRefLocKeys = [String: [String]]()
				for (k, v) in stdRefLocFile.groupedOctothorpedUntaggedRefLocKeys {
					simplifiedStdGroupedOctothorpedUntaggedRefLocKeys[k.locKey] = v.map{ $0.locKey }
				}
				var simplifiedXibGroupedOctothorpedUntaggedRefLocKeys = [String: [String]]()
				for (k, v) in xibRefLocFile.groupedOctothorpedUntaggedRefLocKeys {
					simplifiedXibGroupedOctothorpedUntaggedRefLocKeys[k.locKey] = v.map{ $0.locKey }
				}
				
				guard simplifiedStdGroupedOctothorpedUntaggedRefLocKeys == simplifiedXibGroupedOctothorpedUntaggedRefLocKeys else {
					DispatchQueue.main.async{
						self.showErrorAndBail(NSError(domain: "com.happn.LocMapper-Linter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected diff between simplified std and xib grouped octothorped untagged RefLoc keys. This should not happen; I can’t go on. Please see someone who knows what this means for help."]))
					}
					return
				}
				
				self.simplifiedGroupedOctothorpedUntaggedRefLocKeys = simplifiedXibGroupedOctothorpedUntaggedRefLocKeys
				self.prepareFiles()
			} catch {
				DispatchQueue.main.async{
					self.showErrorAndBail(error)
				}
			}
		}
	}
	
	private func prepareFiles() {
		var latestError: Error?
		let operations = filesDescriptions.map{ (fileDescription: InputFileDescription) in
			return BlockOperation{
				do {
					let locFile = try LocFile(fromPath: fileDescription.url.path, withCSVSeparator: ",")
					let simplifiedReferencedKeys = Set(locFile.untaggedKeysReferencedInMappings.map{
						$0.locKey
					})
					
					/* We change locFiles on the main thread to avoid concurrency problems. */
					DispatchQueue.main.sync{ self.simplifiedUntaggedKeysReferencedInMappingsByFile[fileDescription] = simplifiedReferencedKeys }
				} catch {
					latestError = error
				}
			}
		}
		let endOperation = BlockOperation{
			if let error = latestError {DispatchQueue.main.async{ self.showErrorAndBail(error) }}
			else                       {self.computeResults()}
		}
		operations.forEach{ endOperation.addDependency($0) }
		
		queue.addOperations(operations + [endOperation], waitUntilFinished: false)
	}
	
	private func computeResults() {
		queue.addOperation{
			var reports = [Report]()
			let simplifiedGroupedOctothorpedUntaggedRefLocKeysWithMoreThanOneVersion = self.simplifiedGroupedOctothorpedUntaggedRefLocKeys.filter{
				return $0.value.count > 1
			}
			for (_, versions) in simplifiedGroupedOctothorpedUntaggedRefLocKeysWithMoreThanOneVersion {
				let latestVersion = versions.last!
				var mapped = [String: String]()
				/* Let's find which key is mapped (if any) for each input files */
				for file in self.filesDescriptions {
					let referencedKeys = self.simplifiedUntaggedKeysReferencedInMappingsByFile[file]!
					for version in versions.reversed() {
						if referencedKeys.contains(version) {
							mapped[file.stringHash] = version
						}
					}
				}
				reports.append(.versionReport(latestRefLocKey: latestVersion, mappedKeys: mapped))
			}
			reports.sort{
				switch ($0, $1) {
				case (.versionReport(latestRefLocKey: let k1, mappedKeys: _), .versionReport(latestRefLocKey: let k2, mappedKeys: _)):
					return k1 < k2
				}
			}
			
			DispatchQueue.main.async{
				self.reports = reports
				self.tableView.reloadData()
				self.progressIndicator.stopAnimation(nil)
			}
		}
	}
	
	private func showErrorAndBail(_ error: Error) {
		assert(Thread.isMainThread)
		self.progressIndicator.stopAnimation(nil)
		guard let w = view.window else {return}
		
		let alert = NSAlert(error: error)
		alert.beginSheetModal(for: w, completionHandler: { _ in
			w.close()
		})
	}
	
}
