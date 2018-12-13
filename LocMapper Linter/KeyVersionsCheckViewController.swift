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



class KeyVersionsCheckViewController : NSViewController {
	
	@IBOutlet var tableView: NSTableView!
	
	var filesDescriptions: [InputFileDescription]!
	
	override func viewDidAppear() {
		super.viewDidAppear()
		
		guard locFiles == nil else {return}
		locFiles = [:]
		
		print(filesDescriptions)
	}
	
	private var locFiles: [InputFileDescription: LocFile]!
	
}


class PrepareFileOperation : Operation {
	
	enum Error : Swift.Error {
		case notFinished
	}
	
	let fileDescription: InputFileDescription
	private(set) var result = AsyncOperationResult<LocFile>.error(Error.notFinished)
	
	init(fileDescription fd: InputFileDescription) {
		fileDescription = fd
		
		super.init()
	}
	
	override func main() {
		do {
			let locFile = try LocFile(fromPath: fileDescription.url.path, withCSVSeparator: ",")
		} catch {
			result = .error(error)
		}
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}
