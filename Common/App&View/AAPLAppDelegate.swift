//
//  AAPLAppDelegate.swift
//  BananasSwift
//
//  Created by Andrew on 16/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
/*
Abstract:

The shared implementation of the application delegate for both iOS and OS X versions of the game. This class handles initial setup of the game, including loading assets and checking for game controllers, before passing control to AAPLGameSimulation to start the game.
*/
//

import Foundation
import AppKit
import SpriteKit
import SceneKit
import GameController


class AAPLAppDelegate: NSObject, NSApplicationDelegate {
    
    class var sharedAppDelegate: AAPLAppDelegate {
        // If running in OSX, this will be an NSApplicationDelegate
        // If running in iOS, this will be a UIApplicationDelegate
        // Force the downcast as we are pretty sure it will be the right subclass
        return NSApplication.sharedApplication().delegate as! AAPLAppDelegate
    }

    @IBOutlet weak var scnView: AAPLSceneView!
    // var skScene: AAPLInGameScene
    
    override init() {
        // Rule 1: Designated Init must initialize all properties introduced before delegating up to superclass init
        self.scnView = AAPLSceneView()
        super.init()
        // Rule 2: Designated Init must delegate up to superclass init before assigning value to inherited property
    }
    
    func togglePaused () {
        let currentState:AAPLGameState = AAPLGameSimulation.sim.gameState
        if (currentState == .Paused) {
            AAPLGameSimulation.sim.gameState = .InGame
        } else if (currentState == .InGame) {
            AAPLGameSimulation.sim.gameState = .Paused
        }
    }
    
    func commonApplicationDidFinishLaunchingWithCompletionHandler(completionHandler: (Void -> Void)?) {
        #if DEBUG
        // Debugging and Stats
        // Built-in statistics panel
            NSLog("Debug enabled")
        self.scnView.showsStatistics = true
        #endif
        
        self.scnView.backgroundColor = SKColor.blackColor()
        
        let progress: NSProgress = NSProgress(totalUnitCount: 10)
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            progress.becomeCurrentWithPendingUnitCount(2)
            let ui: AAPLInGameScene = AAPLInGameScene(size: self.scnView.bounds.size)
            dispatch_async(dispatch_get_main_queue(), {
                self.scnView.overlaySKScene = ui
            })
            progress.resignCurrent()
            progress.becomeCurrentWithPendingUnitCount(3)
            
            let gameSim: AAPLGameSimulation = AAPLGameSimulation.sim
            gameSim.gameUIScene = ui
            progress.resignCurrent()
            progress.becomeCurrentWithPendingUnitCount(3)
            
            SCNTransaction.flush()
            
            //Preload
            self.scnView.prepareObject(gameSim, shouldAbortBlock: nil)
            progress.resignCurrent()
            progress.becomeCurrentWithPendingUnitCount(1)

            // Game Play Specific Code
            gameSim.gameUIScene.gameStateDelegate = gameSim.gameLevel
            gameSim.gameLevel.resetLevel()
            gameSim.gameState = .PreGame
            
            progress.resignCurrent()
            progress.becomeCurrentWithPendingUnitCount(1)
            
            
            // GameController hook up
            self.listenForGameControllerWithSim(gameSim)
            
            dispatch_async(dispatch_get_main_queue(), {
                self.scnView.scene = gameSim
                self.scnView.delegate = gameSim
                if (completionHandler != nil) { completionHandler!() }
            })
            
            progress.resignCurrent()
        })
        
    }
    
    func listenForGameControllerWithSim(gameSim: AAPLGameSimulation) {
        
        // GameController hook up
        NSNotificationCenter.defaultCenter().addObserverForName(GCControllerDidConnectNotification,
            object: nil,
            queue: NSOperationQueue.mainQueue()) {
                (note: NSNotification) in gameSim.controllerDidConnect(note)
        }

        
        NSNotificationCenter.defaultCenter().addObserverForName(GCControllerDidDisconnectNotification,
            object: nil,
            queue: NSOperationQueue.mainQueue()) {
                (note: NSNotification) in gameSim.controllerDidDisconnect(note)
        }
        
        GCController.startWirelessControllerDiscoveryWithCompletionHandler(nil)
        
    }
    
}