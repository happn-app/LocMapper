/*
 * KeyVersionsCheckViewController.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 13/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import AppKit

import AsyncOperationResult
import LocMapper



private struct NotFinishedError : Error {}

class KeyVersionsCheckViewController : NSViewController {
	
	@IBOutlet var tableView: NSTableView!
	
	var filesDescriptions: [InputFileDescription]!
	
	override func viewDidAppear() {
		super.viewDidAppear()
		
		guard locFiles == nil else {return}
		locFiles = [:]
		
		getStdRefLoc()
	}
	
	private let queue = OperationQueue()
	private var stdRefLoc: StdRefLocFile!
	private var xibRefLoc: XibRefLocFile!
	
	private var locFiles: [InputFileDescription: LocFile]!
	
	private func getStdRefLoc() {
		queue.addOperation{
			assert(self.stdRefLoc == nil && self.xibRefLoc == nil)
			do {
				self.stdRefLoc = try StdRefLocFile(token: PreferencesViewController.accessToken, projectId: PreferencesViewController.projectId, lokaliseToReflocLanguageName: PreferencesViewController.languagesNameMappings, excludedTags: PreferencesViewController.excludedTags, logPrefix: nil)
				self.xibRefLoc = try XibRefLocFile(stdRefLoc: self.stdRefLoc)
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
					
					switch fileDescription.refLocType {
					case .stdRefLoc: locFile.mergeRefLocsWithStdRefLocFile(self.stdRefLoc, mergeStyle: .replace)
					case .xibRefLoc: locFile.mergeRefLocsWithXibRefLocFile(self.xibRefLoc, mergeStyle: .replace)
					}
					
					/* This fills the cache for future use. */
					_ = locFile.groupedOctothorpedUntaggedRefLocKeys
					_ = locFile.untaggedKeysReferencedInMappings
					
					DispatchQueue.main.sync{ self.locFiles[fileDescription] = locFile }
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
		let groupedOctothorpedUntaggedRefLocKeysWithMoreThanOneVersion = locFiles.mapValues{
			$0.groupedOctothorpedUntaggedRefLocKeys.filter{ $0.value.count > 1 }
		}
	}
	
	private func showErrorAndBail(_ error: Error) {
		assert(Thread.isMainThread)
		guard let w = view.window else {return}
		
		let alert = NSAlert(error: error)
		alert.beginSheetModal(for: w, completionHandler: { _ in
			w.close()
		})
	}
	
}
