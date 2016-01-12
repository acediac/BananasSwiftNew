//
//  AAPLSceneView.swift
//  BananasSwift
//
//  Created by Andrew on 16/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.

/*
Abstract:

The view displaying the game scene. Handles keyboard (OS X) and touch (iOS) input for controlling the game, and forwards other click/touch events to the SpriteKit overlay UI.
*/
//

import Foundation
import SceneKit

class AAPLSceneView : SCNView {
    var keysPressed: Set<String> = []
    
    let AAPLLeftKey = "AAPLLeftKey"
    let AAPLRightKey = "AAPLRightKey"
    let AAPLJumpKey = "AAPLJumpKey"
    let AAPLRunKey = "AAPLRunKey"

// KeysPressed is our set of current inputs
    func updateKey(key: String, isPressed: Bool) {
        if (isPressed) {
            self.keysPressed.insert(key)
        } else {
            self.keysPressed.remove(key)
        }
    }
    
    override func keyDown(theEvent: NSEvent) {
        if (theEvent.modifierFlags.intersect(.ShiftKeyMask) != []) {
            self.updateKey(AAPLRunKey, isPressed: true)
        }
        
        switch(theEvent.keyCode) {
        case 0x31: // space bar
            self.updateKey(AAPLJumpKey, isPressed: true)
        case 0x7c: // right arrow
            self.updateKey(AAPLRightKey, isPressed: true)
        case 0x7b: // left arrow
            self.updateKey(AAPLLeftKey, isPressed: true)
        default:
            break
        }
        
        //    self.interpretKeyEvents([theEvent])
        super.keyDown(theEvent)
    }
    
    override func keyUp(theEvent: NSEvent) {
        if (theEvent.modifierFlags.intersect(.ShiftKeyMask) != []) {
            self.updateKey(AAPLRunKey, isPressed: false)
        }
        switch(theEvent.keyCode) {
        case 0x31: // space bar
            self.updateKey(AAPLJumpKey, isPressed: false)
        case 0x7c: // right arrow
            self.updateKey(AAPLRightKey, isPressed: false)
        case 0x7b: // left arrow
            self.updateKey(AAPLLeftKey, isPressed: false)
        default:
            break
        }
        super.keyUp(theEvent)
    }
    
    override func mouseUp(theEvent: NSEvent) {
        let skScene: AAPLInGameScene = self.overlaySKScene as! AAPLInGameScene
        let p: CGPoint = skScene.convertPointFromView(theEvent.locationInWindow)
        skScene.touchUpAtPoint(p)
        super.mouseUp(theEvent)
    }
    
}
