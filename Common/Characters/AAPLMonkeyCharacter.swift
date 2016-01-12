//
//  AAPLMonkeyCharacter.swift
//  BananasSwift
//
//  Created by Andrew on 3/05/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//

import Foundation
import SceneKit

class AAPLMonkeyCharacter: AAPLSkinnedCharacter {
    
    var rightHand: SCNNode?
    var coconut: SCNNode?
    
    var _isIdle : Bool = false
    var _hasCoconut : Bool = false
    
    func createAnimations() {
        self.name = "monkey"
        self.rightHand = self.childNodeWithName("Bone_R_Hand", recursively: true)
        
        _isIdle = true
        _hasCoconut = false
        
        // load and cache animations
        self.setupTauntAnimation()
        self.setupHangAnimation()
        self.setupGetCoconutAnimation()
        self.setupThrowAnimation()
        
        //-- Sequence: get -> throw
        self.chainAnimation("monkey_get_coconut-1", secondKey: "monkey_throw_coconut-1")
        
        // start the ball rolling with hanging in the tree
        if let hangAnim = self.cachedAnimation("monkey_tree_hang-1") {
            self.mainSkeleton.addAnimation(hangAnim, forKey: "monkey_idle")
        }
    }
    
    func setupTauntAnimation() {
        if let taunt: CAAnimation = self.loadAndCacheAnimation(AAPLGameSimulation.pathForArtResource("characters/monkey/monkey_tree_hang_taunt"), key: "monkey_tree_hang_taunt-1") {
            taunt.repeatCount = 0
        
            let ackBlock: SCNAnimationEventBlock = {
                (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward: Bool) -> Void in
                AAPLGameSimulation.sim.playSound("ack.caf")
            }
            
            taunt.animationEvents = [SCNAnimationEvent(keyTime: 0.0, block: ackBlock),
                                     SCNAnimationEvent(keyTime: 1.0, block: {
                                        (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward:Bool) -> Void in
                                        self._isIdle = true
                                     })]
            
        }
    }
    
    func setupHangAnimation() {
        if let hang = self.loadAndCacheAnimation(AAPLGameSimulation.pathForArtResource("characters/monkey/monkey_tree_hang"), key: "monkey_tree_hang-1") {
            hang.repeatCount = MAXFLOAT
        }
    }
    
    func setupGetCoconutAnimation() {
        let pickupEventBlock: SCNAnimationEventBlock = {
            (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward: Bool) -> Void in
            self.coconut?.removeFromParentNode()
            self.coconut = AAPLCoconut.coconutProtoObject
            self.rightHand?.addChildNode(self.coconut!)
            
            self._hasCoconut = true
            
        }
        
        if let getAnimation = self.loadAndCacheAnimation(AAPLGameSimulation.pathForArtResource("characters/monkey/monkey_get_coconut"), key: "monkey_get_coconut-1") {
            if getAnimation.animationEvents == nil {
                getAnimation.animationEvents = [SCNAnimationEvent(keyTime: 0.4, block: pickupEventBlock)]
            }
            getAnimation.repeatCount = 0
        }
    }
    
    func setupThrowAnimation() {
        if let `throw` = self.loadAndCacheAnimation(AAPLGameSimulation.pathForArtResource("characters/monkey/monkey_throw_coconut"), key: "monkey_throw_coconut-1") {
            `throw`.speed = 1.5
            if (`throw`.animationEvents == nil || `throw`.animationEvents!.count == 0) {
                let throwEventBlock: SCNAnimationEventBlock = {
                    (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward: Bool) -> Void in
                    if (self._hasCoconut) {
                        let worldMtx: SCNMatrix4 = self.coconut!.presentationNode.worldTransform
                        self.coconut?.removeFromParentNode()
                        
                        let node: AAPLCoconut = AAPLCoconut.coconutThrowProtoObject
                        let coconutPhysicsShape: SCNPhysicsShape = AAPLCoconut.coconutPhysicsShape
                        node.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Dynamic, shape: coconutPhysicsShape)
                        node.physicsBody!.restitution = 0.9
                        node.physicsBody!.collisionBitMask = GameCollisionCategory.Player | GameCollisionCategory.Ground
                        node.physicsBody!.categoryBitMask = GameCollisionCategory.Coconut
                        
                        node.transform = worldMtx
                        AAPLGameSimulation.sim.rootNode.addChildNode(node)
                        AAPLGameSimulation.sim.gameLevel.coconuts!.insert(node)
                        node.physicsBody!.applyForce(SCNVector3Make(-200, 500, 300), impulse: true)
                        self._hasCoconut = false
                        self._isIdle = true
                        
                    }
                }
                `throw`.animationEvents = [SCNAnimationEvent(keyTime: 0.35, block: throwEventBlock)]
            }
            `throw`.repeatCount = 0
        }
        
    }
    
    override func update(deltaTime: NSTimeInterval) {
        var distanceToCharacter = FLT_MAX
        let playerCharacter: AAPLPlayerCharacter = AAPLGameSimulation.sim.gameLevel.playerCharacter!
        
        let pos: SCNVector3 = AAPLMatrix4GetPosition(self.presentationNode.worldTransform)
        let myPosition: GLKVector3 = GLKVector3Make(Float(pos.x), Float(pos.y), Float(pos.z))
        
        // If the player is to the left of the monkey, calculate how far away the character is
        if playerCharacter.position.x < CGFloat(myPosition.x) {
            distanceToCharacter = GLKVector3Distance(SCNVector3ToGLKVector3(playerCharacter.position), myPosition)
        }
        
        // If the character is close enough and not moving, throw a coconut
        if (distanceToCharacter < 700) {
            if (_isIdle) {
                if playerCharacter.isRunning == true {
                    self.mainSkeleton.addAnimation(self.cachedAnimation("monkey_get_coconut-1")!, forKey: nil)
                    _isIdle = false
                } else {
                    // taunt the player if they aren't moving
                    if (AAPLRandomPercent() <= 0.001) {
                        _isIdle = false
                        self.mainSkeleton .addAnimation(self.cachedAnimation("monkey_tree_hang_taunt-1")!, forKey: nil)
                    }
                }
            }
        }
    }
}