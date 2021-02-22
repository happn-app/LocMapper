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
	
	@IBOutlet var progressIndicatorFirstLoad: NSProgressIndicator!
	@IBOutlet var progressIndicatorReload: NSProgressIndicator!
	@IBOutlet var tableView: NSTableView!
	
	/* The following 4 vars are not bound directly from UI to User Defaults
	 * because we can have multiple KeyVersionsCheckViewController instantiated
	 * and we don’t want to have the filters change for all controllers at the
	 * same time. We do however save the value in the User Defaults to have a
	 * default value which will be the latest filters chosen by the user. */
	
	@objc dynamic var showMappedLatest = UserDefaults.standard.bool(forKey: "HPN Default Show Mapped Latest") {
		didSet {
			UserDefaults.standard.set(showMappedLatest, forKey: "HPN Default Show Mapped Latest")
			self.reloadOrQueueReload()
		}
	}
	
	@objc dynamic var showUnmapped = UserDefaults.standard.bool(forKey: "HPN Default Show Unmapped") {
		didSet {
			UserDefaults.standard.set(showUnmapped, forKey: "HPN Default Show Unmapped")
			self.reloadOrQueueReload()
		}
	}
	
	@objc dynamic var showNotLatestVersion = UserDefaults.standard.bool(forKey: "HPN Default Show Not Latest Version") {
		didSet {
			UserDefaults.standard.set(showNotLatestVersion, forKey: "HPN Default Show Not Latest Version")
			self.reloadOrQueueReload()
		}
	}
	
	@objc dynamic var alsoShowOneVersionKeys = UserDefaults.standard.bool(forKey: "HPN Default Also Show One Version Keys") {
		didSet {
			UserDefaults.standard.set(alsoShowOneVersionKeys, forKey: "HPN Default Also Show One Version Keys")
			self.reloadOrQueueReload()
		}
	}
	
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
		
		progressIndicatorFirstLoad.startAnimation(nil)
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
	
	private enum LoadingState {
		
		case firstLoad
		case reload
		case notLoading
		
		var isLoading: Bool {
			return self != .notLoading
		}
		
	}
	
	private enum Report {
		
		case versionReport(latestRefLocKey: String, mappedKeys: [String /* stringHash of a InputFileDescription */: String])
		
	}
	
	private var needsReload = false
	private var loadingState = LoadingState.firstLoad
	
	private var reports: [Report]!
	
	private let queue = OperationQueue()
	private var simplifiedGroupedOctothorpedUntaggedRefLocKeys: [String: [String]]!
	
	private var simplifiedUntaggedKeysReferencedInMappingsByFile: [InputFileDescription: Set<String>]!
	
	private func getStdRefLoc() {
		queue.addOperation{
			assert(self.simplifiedGroupedOctothorpedUntaggedRefLocKeys == nil)
			do {
				/* We use iOS key type. AFAIK iOS and android keys are the same and
				 * this should not change. */
				let stdRefLoc = try StdRefLocFile(token: PreferencesViewController.accessToken, projectId: PreferencesViewController.projectId, lokaliseToReflocLanguageName: PreferencesViewController.languagesNameMappings, keyType: "ios", excludedTags: PreferencesViewController.excludedTags, logPrefix: nil)
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
			for (_, versions) in self.simplifiedGroupedOctothorpedUntaggedRefLocKeys {
				/* First filter on version count */
				guard self.alsoShowOneVersionKeys || versions.count > 1 else {
					continue
				}
				
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
				/* Let’s apply the remaining filters */
				let shouldAppend = (
					(self.showUnmapped && mapped.count < self.filesDescriptions.count) ||
					(self.showNotLatestVersion && Set(mapped.values).subtracting([latestVersion]).count > 0) ||
					(self.showMappedLatest && mapped.count == self.filesDescriptions.count && Set(mapped.values) == Set(arrayLiteral: latestVersion))
				)
				if shouldAppend {
					reports.append(.versionReport(latestRefLocKey: latestVersion, mappedKeys: mapped))
				}
			}
			reports.sort{
				switch ($0, $1) {
				case (.versionReport(latestRefLocKey: let k1, mappedKeys: _), .versionReport(latestRefLocKey: let k2, mappedKeys: _)):
					return k1 < k2
				}
			}
			
			DispatchQueue.main.async{
				assert(self.loadingState.isLoading)
				self.loadingState = .notLoading
				
				self.reports = reports
				self.tableView.reloadData()
				self.progressIndicatorFirstLoad.stopAnimation(nil)
				
				if self.needsReload {
					self.reloadOrQueueReload()
				} else {
					self.progressIndicatorReload.stopAnimation(nil)
				}
			}
		}
	}
	
	private func showErrorAndBail(_ error: Error) {
		assert(Thread.isMainThread)
		progressIndicatorFirstLoad.stopAnimation(nil)
		guard let w = view.window else {return}
		
		let alert = NSAlert(error: error)
		alert.beginSheetModal(for: w, completionHandler: { _ in
			w.close()
		})
	}
	
	private func reloadOrQueueReload() {
		assert(Thread.isMainThread)
		progressIndicatorReload.startAnimation(nil)
		if loadingState.isLoading {
			needsReload = true
		} else {
			loadingState = .reload
			needsReload = false
			computeResults()
		}
	}
	
}
