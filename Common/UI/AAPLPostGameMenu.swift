 //
//  AAPLPostGameMenu.swift
//  BananasSwift
//
//  Created by Andrew on 20/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/* 
Abstract:

A Sprite Kit node that provides the post-game screen for the game, displayed by the AAPLInGameScene class.

*/
import Foundation
import SpriteKit
import CoreGraphics

class AAPLPostGameMenu: SKNode {
    var myLabel: SKLabelNode!
    var bananaText: SKLabelNode!
    var bananaScore: SKLabelNode!
    var coinText: SKLabelNode!
    var coinScore: SKLabelNode!
    var totalText: SKLabelNode!
    var totalScore: SKLabelNode!
    
    var gameStateDelegate: AAPLGameUIState!
    
    init(frameSize: CGSize, gameStateDelegate:AAPLGameUIState) {
        super.init()
        
        self.gameStateDelegate = gameStateDelegate
        
        let menuHeight: CGFloat = frameSize.height * 0.8
        let background: SKSpriteNode = SKSpriteNode(color: SKColor.blackColor(),
            size: CGSizeMake(frameSize.width * 0.8, menuHeight))
        
        background.zPosition = -1
        background.alpha = 0.5
        background.position = CGPointMake(0, -0.2 * menuHeight)
        self.addChild(background)
        
        self.myLabel = AAPLInGameScene.labelWithText("Final Score", textSize: 65)
        self.myLabel.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame))
        self.position = CGPointMake(frameSize.width * 0.5, frameSize.height * 0.5)
        self.userInteractionEnabled = true
        self.myLabel.userInteractionEnabled = true
        self.addChild(self.myLabel)
        AAPLInGameScene.dropShadowOnLabel(self.myLabel)
        
        var bananaLocation: CGPoint      = CGPointMake(frameSize.width * -0.4, CGRectGetMidY(self.frame) * -0.4)
        var coinLocation: CGPoint        = CGPointMake(frameSize.width * -0.4, CGRectGetMidY(self.frame) * -0.6)
        var totalLocation: CGPoint       = CGPointMake(frameSize.width * -0.4, CGRectGetMidY(self.frame) * -0.8)
        var bananaScoreLocation: CGPoint = CGPointMake(frameSize.width * +0.4, CGRectGetMidY(self.frame) * -0.4)
        var coinScoreLocation: CGPoint   = CGPointMake(frameSize.width * +0.4, CGRectGetMidY(self.frame) * -0.6)
        var totalScoreLocation: CGPoint  = CGPointMake(frameSize.width * +0.4, CGRectGetMidY(self.frame) * -0.8)
        
        self.bananaText = self.myLabel.copy() as! SKLabelNode
        self.bananaText.text = "Bananas"
        self.bananaText.fontSize = 0.1 * menuHeight
        self.bananaText.setScale(0.8)
        bananaLocation.x += (CGRectGetWidth(self.bananaText.calculateAccumulatedFrame()) * 0.5) + (frameSize.width * 0.1)
        self.bananaText.position = CGPointMake(bananaLocation.x, -2000)
        self.addChild(self.bananaText)
        
        self.bananaScore = self.bananaText.copy() as! SKLabelNode
        self.bananaScore.text = "000"
        bananaScoreLocation.x -= (CGRectGetWidth(self.bananaScore.calculateAccumulatedFrame()) * 0.5) + (frameSize.width * 0.1)
        self.bananaScore.position = CGPointMake(bananaScoreLocation.x, -2000)
        self.addChild(self.bananaScore)

        self.coinText = self.bananaText.copy() as! SKLabelNode
        self.coinText.text = "Large Bananas"
        coinLocation.x += (CGRectGetWidth(self.coinText.calculateAccumulatedFrame()) * 0.5) + (frameSize.width * 0.1)
        self.coinText.position = CGPointMake(coinLocation.x, -2000)
        self.addChild(self.coinText)
        AAPLInGameScene.dropShadowOnLabel(self.coinText)
        
        self.coinScore = self.coinText.copy() as! SKLabelNode
        self.coinScore.text = "000"
        coinScoreLocation.x -= (CGRectGetWidth(self.coinScore.calculateAccumulatedFrame()) * 0.5) + (frameSize.width * 0.1)
        self.coinScore.position = CGPointMake(coinScoreLocation.x, -2000)
        self.addChild(self.coinScore)

        self.totalText = self.bananaText.copy() as! SKLabelNode
        self.totalText.text = "Total"
        totalLocation.x += (CGRectGetWidth(self.totalText.calculateAccumulatedFrame()) * 0.5) + (frameSize.width * 0.1)
        self.totalText.position = CGPointMake(totalLocation.x, -2000)
        self.addChild(self.totalText)
        AAPLInGameScene.dropShadowOnLabel(self.totalText)
        
        self.totalScore = self.totalText.copy() as! SKLabelNode
        self.totalScore.text = "000"
        totalScoreLocation.x -= (CGRectGetWidth(self.totalScore.calculateAccumulatedFrame()) * 0.5) + (frameSize.width * 0.1)
        self.totalScore.position = CGPointMake(totalScoreLocation.x, -2000)
        self.addChild(self.totalScore)
        
        let flyup: SKAction = SKAction.moveTo(CGPointMake(frameSize.width * 0.5,
            frameSize.height - 100),
            duration: 0.25)
        flyup.timingMode = SKActionTimingMode.EaseInEaseOut
        
        let flyupBananas: SKAction = SKAction.moveTo(bananaLocation, duration: 0.25)
        let flyupBananasScore: SKAction = SKAction.moveTo(bananaScoreLocation, duration: 0.25)
        flyupBananas.timingMode = SKActionTimingMode.EaseInEaseOut
        flyupBananasScore.timingMode = SKActionTimingMode.EaseInEaseOut
        
        let flyupCoins: SKAction = SKAction.moveTo(coinLocation, duration: 0.25)
        let flyupCoinsScore: SKAction = SKAction.moveTo(coinScoreLocation, duration: 0.25)
        flyupCoins.timingMode = SKActionTimingMode.EaseInEaseOut
        flyupCoinsScore.timingMode = SKActionTimingMode.EaseInEaseOut
       
        let flyupTotal: SKAction = SKAction.moveTo(totalLocation, duration: 0.25)
        let flyupTotalScore: SKAction = SKAction.moveTo(totalScoreLocation, duration: 0.25)
        flyupTotal.timingMode = SKActionTimingMode.EaseInEaseOut
        flyupTotalScore.timingMode = SKActionTimingMode.EaseInEaseOut

        let bananasCollected: Int = self.gameStateDelegate.bananasCollected
        let coinsCollected: Int = self.gameStateDelegate.coinsCollected
        let totalCollected: Int = bananasCollected + (coinsCollected * 100)
        
        let countUpBananas: SKAction = SKAction.customActionWithDuration(NSTimeInterval(bananasCollected / 100)) {
            (node: SKNode, elapsedTime: CGFloat) in
            if (bananasCollected > 0) {
                let label: SKLabelNode = node as! SKLabelNode
                let total: Int = Int(round((Float(elapsedTime) / (Float(bananasCollected) / 100)) * Float(bananasCollected)))
                label.text = String(format:"%ld", total)
                if (total % 10 == 0) {
                    AAPLGameSimulation.sim.playSound("deposit.caf")
                }
            }
        }
        
        let countUpCoins: SKAction = SKAction.customActionWithDuration(NSTimeInterval(coinsCollected / 100)) {
            (node: SKNode, elapsedTime: CGFloat) in
            if (coinsCollected > 0) {
                let label: SKLabelNode = node as! SKLabelNode
                let total: Int = Int(round((Float(elapsedTime) / (Float(coinsCollected) / 100)) * Float(coinsCollected)))
                label.text = String(format:"%ld", total)
                if (total % 10 == 0) {
                    AAPLGameSimulation.sim.playSound("deposit.caf")
                }
            }
        }
        
        let countUpTotal: SKAction = SKAction.customActionWithDuration(NSTimeInterval(totalCollected / 100)) {
            (node: SKNode, elapsedTime: CGFloat) in
            if (totalCollected > 0) {
                let label: SKLabelNode = node as! SKLabelNode
                let total: Int = Int(round((Float(elapsedTime) / (Float(totalCollected) / 100)) * Float(totalCollected)))
                label.text = String(format:"%ld", total)
                if (total % 10 == 0) {
                    AAPLGameSimulation.sim.playSound("deposit.caf")
                }
            }
        }
        
        // Play actions in sequence: Fly up, count up, repeat with next line
        self.runAction(flyup) {
            // fly up the bananas collected
            self.bananaText!.runAction(flyupBananas)
            self.bananaScore!.runAction(flyupBananasScore) {
                // Count
                self.bananaScore!.runAction(countUpBananas) {
                    self.bananaScore!.text = String(format:"%ld", bananasCollected)
                    self.coinText!.runAction(flyupCoins)
                    self.coinScore!.runAction(flyupCoinsScore) {
                        // count
                        self.coinScore!.runAction(countUpCoins) {
                            self.coinScore!.text = String(format:"%ld", coinsCollected)
                            self.totalText!.runAction(flyupTotal)
                            self.totalScore!.runAction(flyupTotalScore) {
                                self.totalScore!.runAction(countUpTotal) {
                                    self.totalScore!.text = String(format:"%ld", totalCollected)
                                }
                            }
                        }
                    }
                    
                }
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func touchUpAtPoint(location:CGPoint) {
        if let touchedNode = self.scene?.nodeAtPoint(location) {
            self.hidden = true
            AAPLGameSimulation.sim.gameState = .InGame
        }
        
    }
}

