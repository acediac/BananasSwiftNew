//
//  AppDelegateOSX.swift
//  BananasSwift
//
//  Created by Andrew on 15/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegateOSX: AAPLAppDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        self.window.disableSnapshotRestoration()
        self.commonApplicationDidFinishLaunchingWithCompletionHandler(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
    
    @IBAction func pause(sender: AnyObject) {
        self.togglePaused()
    }
}
