/*
 * KeyVersionsCheckViewController.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 13/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import AppKit



class KeyVersionsCheckViewController : NSViewController {
	
	var filesDescriptions: [InputFileDescription]!
	
	override func viewDidAppear() {
		super.viewDidAppear()
		
		print(filesDescriptions)
	}
	
}
