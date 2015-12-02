/*
 * LocEntryViewController.swift
 * happn CSV Editor
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class LocEntryViewController: NSViewController {
	
	@IBOutlet var constraintContextTextHeight: NSLayoutConstraint!
	@IBOutlet var textViewContext: NSTextView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override var representedObject: AnyObject? {
		didSet {
		// Update the view, if already loaded.
		}
	}
	
	override func updateViewConstraints() {
		if let
			textContainer = textViewContext.textContainer,
			layoutManagers = textViewContext.textStorage?.layoutManagers where layoutManagers.count >= 1 {
				if layoutManagers.count > 1 {
					print("*** Warning: Got more than one layout manager for text view \(textViewContext)")
				}
				let layoutManager = layoutManagers[0]
				constraintContextTextHeight.constant = min(layoutManager.usedRectForTextContainer(textContainer).size.height, 150)
		}
		
		super.updateViewConstraints()
	}
	
}
