//
//  AAPLInGameScene.swift
//  BananasSwift
//
//  Created by Andrew on 19/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/*
Abstract:

A Sprite Kit scene that provides the 2D overlay UI for the game, and displays different child nodes for title, pause, and post-game screens.

*/

import Foundation
import SpriteKit

class AAPLInGameScene: SKScene {
    

    
    var scoreLabelValue: SKLabelNode!
    var scoreLabelValueShadow: SKLabelNode!
    var gameState: AAPLGameState = .Paused {
        willSet {
            if (self.menuNode != nil) { self.menuNode.removeFromParent() }
            if (self.pauseNode != nil) {self.pauseNode.removeFromParent() }
            if (self.postGameNode != nil) { self.postGameNode.removeFromParent() }
            
            switch (newValue) {
            case .PreGame:
                self.menuNode = AAPLMainMenu(frameSize: self.frame.size)
                self.addChild(self.menuNode)
            case .InGame:
                self.hideInGameUI(false)
            case .Paused:
                self.pauseNode = AAPLPauseMenu(frameSize: self.frame.size)
            case .PostGame:
                self.postGameNode = AAPLPostGameMenu(frameSize: self.frame.size, gameStateDelegate: self.gameStateDelegate)
                self.addChild(self.postGameNode)
                self.hideInGameUI(true)
            default:
                break
            }
        }
    }

    
    
    var gameStateDelegate: AAPLGameUIState!
    
    var timeLabelValue: SKLabelNode!
    var timeLabelValueShadow: SKLabelNode!
    var scoreLabel: SKLabelNode!
    var scoreLabelShadow: SKLabelNode!
    var timeLabel: SKLabelNode!
    var timeLabelShadow: SKLabelNode!
    
    var menuNode: AAPLMainMenu!
    var pauseNode: AAPLPauseMenu!
    var postGameNode: AAPLPostGameMenu!
    
    class func labelWithText(text: String, textSize:CGFloat) -> SKLabelNode {
        let fontName: String = "Optima-ExtraBlack"
        let myLabel: SKLabelNode = SKLabelNode(fontNamed: fontName)
        myLabel.text = text
        myLabel.fontSize = textSize
        myLabel.fontColor = SKColor.yellowColor()
        return myLabel
    }
    
    class func dropShadowOnLabel(frontLabel: SKLabelNode) -> SKLabelNode {
        let myLabelBackground: SKLabelNode = frontLabel.copy() as! SKLabelNode
        myLabelBackground.userInteractionEnabled = false
        myLabelBackground.fontColor = SKColor.blackColor()
        myLabelBackground.position = CGPointMake(2 + frontLabel.position.x,
            -2 + frontLabel.position.y)
        myLabelBackground.zPosition = frontLabel.zPosition - 1
        frontLabel.parent?.addChild(myLabelBackground)
        return myLabelBackground
    }
    
    override init(size:CGSize) {
        super.init(size: size)
        self.backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.3, alpha: 1)
        self.timeLabel = AAPLInGameScene.labelWithText("Time", textSize: 24)
        self.addChild(self.timeLabel)
        
        var af:CGRect = self.timeLabel.calculateAccumulatedFrame()
        self.timeLabel.position = CGPointMake(self.frame.size.width - af.size.width,
            self.frame.size.height - af.size.height)
        self.timeLabelValue = AAPLInGameScene.labelWithText("102:00", textSize: 20)
        self.addChild(self.timeLabelValue)
        
        let timeLabelValueSize: CGRect = self.timeLabelValue.calculateAccumulatedFrame()
        self.timeLabelValue.position = CGPointMake(self.frame.size.width - af.size.width - timeLabelValueSize.size.width - 10,
            self.frame.size.height - af.size.height)
        
        self.scoreLabel = AAPLInGameScene.labelWithText("Score", textSize: 24)
        self.addChild(self.scoreLabel)
        af = self.scoreLabel.calculateAccumulatedFrame()
        self.scoreLabel.position = CGPointMake(af.size.width * 0.5,
            self.frame.size.height - af.size.height)
        
        self.scoreLabelValue = AAPLInGameScene.labelWithText("0", textSize: 24)
        self.addChild(self.scoreLabelValue)
        self.scoreLabelValue.position = CGPointMake(af.size.width * 0.75 + timeLabelValueSize.size.width,
            self.frame.size.height - af.size.height)
        
        // Add drop shadows to each label above
        self.timeLabelValueShadow = AAPLInGameScene.dropShadowOnLabel(self.timeLabelValue)
        self.scoreLabelShadow = AAPLInGameScene.dropShadowOnLabel(self.scoreLabel)
        self.timeLabelShadow = AAPLInGameScene.dropShadowOnLabel(self.timeLabel)
        self.scoreLabelValueShadow = AAPLInGameScene.dropShadowOnLabel(self.scoreLabelValue)
        
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func touchUpAtPoint(location: CGPoint) {
        switch(self.gameState) {
        case .Paused:
            self.pauseNode.touchUpAtPoint(location)
        case .PostGame:
            self.postGameNode.touchUpAtPoint(location)
        case .PreGame:
            self.menuNode.touchUpAtPoint(location)
        case .InGame:
            let touchedNode: SKNode = self.scene!.nodeAtPoint(location)
            if (touchedNode == self.timeLabelValue) {
                AAPLGameSimulation.sim.gameState = .Paused
            }
        default:
            break
        }
    }
    
    
    func hideInGameUI(hide:Bool) {
        self.scoreLabelValue.hidden = hide
        self.scoreLabelValueShadow.hidden = hide
        self.timeLabelValue.hidden = hide
        self.timeLabelValueShadow.hidden = hide
        self.scoreLabel.hidden = hide
        self.scoreLabelShadow.hidden = hide
        self.timeLabel.hidden = hide
        self.timeLabelShadow.hidden = hide
    }
    
    override func update(currentTime:NSTimeInterval) {
        // Update the score and time labels with the correct data
        self.gameStateDelegate.scoreLabelLocation = self.scoreLabelValue.position
        
        scoreLabelValue.text = String(format: "%ld", self.gameStateDelegate.score)
        scoreLabelValueShadow.text = scoreLabelValue.text
        
        if (self.gameStateDelegate.secondsRemaining > 60) {
            let minutes: Int = Int(round(self.gameStateDelegate.secondsRemaining / 60))
            let seconds: Int = Int(round(self.gameStateDelegate.secondsRemaining % 60))
            timeLabelValue.text = String(format:"%ld:%02ld", minutes, seconds)
            timeLabelValueShadow.text = timeLabelValue.text
        } else {
            let seconds: Int = Int(round(self.gameStateDelegate.secondsRemaining % 60))
            timeLabelValue.text = String(format:"0:%02ld", seconds)
            timeLabelValueShadow.text = timeLabelValue.text
        }
        
    }
}