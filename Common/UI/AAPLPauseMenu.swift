//
//  AAPLPauseMenu.swift
//  BananasSwift
//
//  Created by Andrew on 20/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/*
Abstract:

A Sprite Kit node that provides the pause screen for the game, displayed by the AAPLInGameScene class.

*/

import Foundation
import SpriteKit

class AAPLPauseMenu: SKNode {
    var myLabel: SKLabelNode
    
    init(frameSize:CGSize) {
        self.myLabel = AAPLInGameScene.labelWithText("Resume", textSize: 65)
        super.init()

        self.myLabel.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame))
        self.position = CGPointMake(frameSize.width * 0.5, frameSize.height * 0.5)
        self.addChild(self.myLabel)
        AAPLInGameScene.dropShadowOnLabel(self.myLabel)

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func touchUpAtPoint(location: CGPoint) {
        let touchedNode: SKNode? = self.scene?.nodeAtPoint(location)
        
        if (touchedNode == self.myLabel) {
            self.hidden = true
            AAPLGameSimulation.sim.gameState = .InGame
        }
    }
}