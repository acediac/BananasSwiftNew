//
//  AAPLMainMenu.swift
//  BananasSwift
//
//  Created by Andrew on 20/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/*
Abstract:

A Sprite Kit node that provides the title screen for the game, displayed by the AAPLInGameScene class.

*/
import Foundation
import SpriteKit

class AAPLMainMenu: SKNode {
    var gameLogo: SKSpriteNode
//    var myLabelBackground: SKLabelNode
    
    init(frameSize:CGSize) {
        self.gameLogo = SKSpriteNode(imageNamed:"art.scnassets/level/interface/logo_bananas.png")

        super.init()
        
        self.position = CGPointMake(frameSize.width * 0.5, frameSize.height * 0.15)
        self.userInteractionEnabled = true
        
        
        // resize logo to fit the screen
        var size: CGSize = self.gameLogo.size
        let factor: CGFloat = frameSize.width / size.width
        size.width *= factor
        size.height *= factor
        self.gameLogo.size = size
        
        self.gameLogo.anchorPoint = CGPointMake(1, 0)
        self.gameLogo.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame))
        self.addChild(self.gameLogo)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func touchUpAtPoint(location: CGPoint) {
        self.hidden = true
        AAPLGameSimulation.sim.gameState = .InGame
    }
}