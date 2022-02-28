/*
 * LoadingDocViewController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class LoadingDocViewController : NSViewController {
	
	@IBOutlet var activityIndicator: NSProgressIndicator!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		activityIndicator.startAnimation(nil)
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
}
