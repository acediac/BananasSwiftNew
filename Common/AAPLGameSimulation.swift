             //
//  AAPLGameSimulation.swift
//  BananasSwift
//
//  Created by Andrew on 16/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/*
Abstract:

This class manages the global state of the game. It handles SCNSceneRendererDelegate methods for participating in the update/render loop, polls for input (directly for game controllers and via AAPLSceneView for key/touch input), and delegates game logic to the AAPLGameLevel object.

*/

import Foundation
import SceneKit
import GameController
import SpriteKit

protocol AAPLGameUIState: NSObjectProtocol {
    var score: Int {get}
    var coinsCollected: Int {get}
    var bananasCollected: Int {get}
    var secondsRemaining: NSTimeInterval {get}
    var scoreLabelLocation: CGPoint {get set}
}

enum AAPLGameState {
    case
    PreGame,
    InGame,
    Paused,
    PostGame,
    Count
}

class AAPLGameSimulation: SCNScene, SCNSceneRendererDelegate {
    
    // Singleton of the simulation
    static let sim: AAPLGameSimulation = AAPLGameSimulation()
    
    
    //var _walkSpeed: CGFloat
    var _previousUpdateTime: NSTimeInterval = 0
    // var _previousPhysicsUpdateTime: NSTimeInterval
    var _deltaTime: NSTimeInterval = 0
    
    
    var desaturationTechnique: SCNTechnique!
    
    
    var gameLevel: AAPLGameLevel!
    var gameUIScene: AAPLInGameScene!
    
    var gameState: AAPLGameState  {
        // get { return self.gameState }
        
        willSet {
            // Ignore redundant state changes
            if (self.gameState == newValue) { return }
            
            // Change UI system according to gameState
            self.gameUIScene.gameState = newValue
            
            // Only reset the level from a non paused mode
            if (newValue == .InGame && self.gameState != .Paused) {
                self.gameLevel.resetLevel()
            }

        }
        didSet {
            // Ignore redundant state changes
            if (self.gameState == oldValue) { return }
            
            
            // Based on the new game state, set the saturation value
            // that the techniques will use to render the scenekit view
            switch (self.gameState) {
            case .PostGame:
                self.setPostGameFilters()
            case .Paused:
                AAPLGameSimulation.sim.playSound("deposit.caf")
                self.setPauseFilters()
            case .PreGame:
                self.setPregameFilters()
            default:
                AAPLGameSimulation.sim.playSound("ack.caf")
                self.setIngameFilters()
            }
        }
    }
    
    var controller: GCController? {
        //get { return self.controller }
        
        didSet {
            if let _controller = self.controller {
                _controller.controllerPausedHandler =  {
                    
                    (controller:GCController) -> Void in
                    let currentState: AAPLGameState = AAPLGameSimulation.sim.gameState
                    
                    if (currentState == .Paused) {
                        AAPLGameSimulation.sim.gameState = .InGame
                    } else if (currentState == .InGame) {
                        AAPLGameSimulation.sim.gameState = .Paused
                    }
                }
            }
        }
    }
    
    
    override init() {
        self.gameState = AAPLGameState.Paused
        self.gameLevel = AAPLGameLevel()
        super.init()
        
        
        // Register ourself as listener to physics callbacks
        if let levelNode: SCNNode = gameLevel.createLevel() {
            self.rootNode.addChildNode(levelNode)
        }
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.gravity = SCNVector3Make(0, -800, 0)
        self.setupTechniques()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /*! Our main input pump for the app
    */
    func renderer(aRenderer: SCNSceneRenderer, updateAtTime time: NSTimeInterval) {
        if (_previousUpdateTime == 0.0) {
            _previousUpdateTime = time
        }
        _deltaTime = time - _previousUpdateTime
        _previousUpdateTime = time
        
        let aView: AAPLSceneView = aRenderer as! AAPLSceneView
        
        var pressingLeft = false
        var pressingRight = false
        var pressingJump = false
        
        if let _controller = self.controller {
            let gamePad: GCGamepad = _controller.gamepad!
            let extGamePad: GCExtendedGamepad = _controller.extendedGamepad!
            
            if (gamePad.dpad.left.pressed == true || extGamePad.leftThumbstick.left.pressed == true) {
                pressingLeft = true
            }
            
            if (gamePad.dpad.right.pressed == true || extGamePad.leftThumbstick.right.pressed == true) {
                pressingRight = true
            }
            
            if (gamePad.buttonA.pressed == true ||
                gamePad.buttonB.pressed == true ||
                gamePad.buttonX.pressed == true ||
                gamePad.buttonY.pressed == true ||
                gamePad.leftShoulder.pressed == true ||
                gamePad.rightShoulder.pressed == true) {
                    pressingJump = true
            }
        }
        if aView.keysPressed.contains(aView.AAPLLeftKey) {
            pressingLeft = true
        }
        if aView.keysPressed.contains(aView.AAPLRightKey) {
            pressingRight = true
        }
        if aView.keysPressed.contains(aView.AAPLJumpKey) {
            pressingJump = true
        }
        if (self.gameState == AAPLGameState.InGame && self.gameLevel.hitByLavaReset == false) {
            if pressingLeft {
                self.gameLevel.playerCharacter?.walkDirection = WalkDirection.Left
            } else if pressingRight {
                self.gameLevel.playerCharacter?.walkDirection = WalkDirection.Right
            }
            
            if (pressingLeft || pressingRight) {
                // Run if not running
                self.gameLevel.playerCharacter?.inRunAnimation = true
            } else {
                // Stop running if running
                self.gameLevel.playerCharacter?.inRunAnimation = false
            }
            
            if pressingJump {
                self.gameLevel.playerCharacter?.performJumpAndStop(false)
            } else {
                self.gameLevel.playerCharacter?.performJumpAndStop(true)
            }
        } else if (self.gameState == AAPLGameState.PreGame || self.gameState == AAPLGameState.PostGame) {
            if pressingJump {
                self.gameState = AAPLGameState.InGame
            }
        }
        
    }
    
    /*! Our main simulation pump for the app
    */
    func renderer(aRenderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: NSTimeInterval) {
        self.gameLevel.update(_deltaTime, aRenderer: aRenderer)
    }
    
    func setupTechniques () {
        // The scene can be desaturated as a full screen effect
        let url: NSURL = NSBundle.mainBundle().URLForResource("art.scnassets/techniques/desaturation", withExtension: "plist")!
        
        let contentsOfUrlAsDictionary = NSDictionary(contentsOfURL: url) as! [String : AnyObject]
        
        self.desaturationTechnique = SCNTechnique(dictionary: contentsOfUrlAsDictionary)!
        self.desaturationTechnique.setValue(0.0, forKey: "Saturation")
        
        
    }
    
    // MARK: Game Filters
    
    func setPostGameFilters() {
        SCNTransaction.begin()
        self.desaturationTechnique.setValue(0.0, forKey: "Saturation")
        SCNTransaction.setAnimationDuration(1.0)
        
        SCNTransaction.commit()
        AAPLAppDelegate.sharedAppDelegate.scnView.technique = self.desaturationTechnique
    }
    
    func setPauseFilters() {
        SCNTransaction.begin()
        self.desaturationTechnique.setValue(1.0, forKey: "Saturation")
        SCNTransaction.setAnimationDuration(1.0)
        self.desaturationTechnique.setValue(0.0, forKey: "Saturation")
        
        SCNTransaction.commit()
        
        AAPLAppDelegate.sharedAppDelegate.scnView.technique = self.desaturationTechnique
    }
    
    func setPregameFilters() {
        SCNTransaction.begin()
        self.desaturationTechnique.setValue(1.0, forKey: "Saturation")
        SCNTransaction.setAnimationDuration(1.0)
        self.desaturationTechnique.setValue(0.0, forKey: "Saturation")
        
        SCNTransaction.commit()
        
        AAPLAppDelegate.sharedAppDelegate.scnView.technique = self.desaturationTechnique
    }
    
    func setIngameFilters() {
        SCNTransaction.begin()
        self.desaturationTechnique.setValue(0.0, forKey: "Saturation")
        SCNTransaction.setAnimationDuration(1.0)
        self.desaturationTechnique.setValue(1.0, forKey: "Saturation")
        
        SCNTransaction.commit()
        
        AAPLAppDelegate.sharedAppDelegate.scnView.technique = self.desaturationTechnique
    }
    

    

    // MARK: Sound and music
    
    func playSound(soundFileName: String?) {
        if (soundFileName != nil) {
            let path = String(format: "Sounds/%@", soundFileName!)
            self.gameUIScene.runAction(SKAction.playSoundFileNamed(path, waitForCompletion: false))
        }
    }
    
    func playMusic(soundFileName: String?) {
        if let soundFileName = soundFileName where
            self.gameUIScene.actionForKey(soundFileName) != nil {
                let path = String(format: "Sounds/%@", soundFileName)
                let repeatAction = SKAction.repeatActionForever(SKAction.playSoundFileNamed(path, waitForCompletion: true))
                self.gameUIScene.runAction(repeatAction, withKey: soundFileName)
        }
    }
    
// MARK: Resource Loading convenience
    
    static let ArtFolderRoot: String = "art.scnassets"
    
    static func pathForArtResource(resourceName: String) -> String {
        return String(format: "%@/%@", ArtFolderRoot, resourceName)
    }
    
    static func loadNodeWithName(name: String?, fromSceneNamed: String) -> SCNNode? {
        
        // load the scene from the specified file
        let scene = SCNScene(named: fromSceneNamed,
            inDirectory: nil,
            options: [SCNSceneSourceConvertToYUpKey : true,
                SCNSceneSourceAnimationImportPolicyKey: SCNSceneSourceAnimationImportPolicyPlayRepeatedly])
        
        // retrieve the root node
        var node = scene?.rootNode
        if node != nil {
            // Search for the node named "name"
            if name != nil {
                node = node!.childNodeWithName(name!, recursively: true)
            } else {
                // use the first node
                node = node!.childNodes[0]
            }
        }
        return node
    }
    
    static func loadParticleSystemWithName(name: String) -> SCNParticleSystem? {
        var path = String(format: "level/effects/%@.scnp", name)
        path = self.pathForArtResource(path)
        path = NSBundle.mainBundle().pathForResource(path, ofType: nil)!
        if let newSystem = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? SCNParticleSystem {
            if let _particleImage = newSystem.particleImage as? NSURL,
                _particleImagePath = _particleImage.path {
                path = String(format: "level/effects/%@", (_particleImagePath as NSString).lastPathComponent)
                path = self.pathForArtResource(path)
                let url = NSURL(string: path.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)
                newSystem.particleImage = url
            }
            return newSystem
        }
        NSLog("failed to load particle system \(name)")
        return nil
    }
}

extension AAPLGameSimulation {
    

    
    // Game controller handling
    func controllerDidConnect(note: NSNotification) {
        let controller: GCController = note.object as! GCController
        self.controller = controller
    }

    func controllerDidDisconnect(note: NSNotification) {
        self.controller = nil
        
        let currentState: AAPLGameState = AAPLGameSimulation.sim.gameState
        
        // Pause the game if we are in game and controller was disconnected
        if (currentState == .InGame) {
            AAPLGameSimulation.sim.gameState = .Paused
        }
    }
    

}

extension AAPLGameSimulation: SCNPhysicsContactDelegate {
    // MARK: Collision handling
    func physicsWorld(world: SCNPhysicsWorld, didBeginContact contact: SCNPhysicsContact) {
        if (self.gameState == .InGame) {
            // Player to banana, large banana or coconut
            if (contact.nodeA == self.gameLevel.playerCharacter?.collideSphere) {
                self.playerCollideWithContact(contact.nodeB, contactPoint: contact.contactPoint)
                return
            } else if (contact.nodeB == self.gameLevel.playerCharacter?.collideSphere) {
                self.playerCollideWithContact(contact.nodeA, contactPoint: contact.contactPoint)
                return
            }
            
            // Coconut to anything but the player
            if contact.nodeB.physicsBody?.categoryBitMask == GameCollisionCategory.Coconut {
                self.handleCollideForCoconut(contact.nodeB)
            } else if (contact.nodeA.physicsBody?.categoryBitMask == GameCollisionCategory.Coconut) {
                self.handleCollideForCoconut(contact.nodeA)
            }
        }
    }
    
    func playerCollideWithContact(node: SCNNode, contactPoint:SCNVector3) {
        if let _bananas = self.gameLevel.bananas where _bananas.contains(node) {
            self.gameLevel.collectBanana(node)
        } else if let _largeBananas = self.gameLevel.largeBananas where _largeBananas.contains(node) {
            self.gameLevel.collectLargeBanana(node)
        } else if (node.physicsBody?.categoryBitMask == GameCollisionCategory.Coconut) {
            self.gameLevel.collideWithCoconut(node, contactPoint: contactPoint)
        } else if (node.physicsBody?.categoryBitMask == GameCollisionCategory.Lava) {
            self.gameLevel.collideWithLava()
        }
    }
    
    func handleCollideForCoconut(coconut: SCNNode) {
        // Remove coconut from the world after it has time to fall offscreen
        coconut.runAction(SCNAction.waitForDuration(3.0), completionHandler: {
            () -> Void in
            coconut.removeFromParentNode()
            self.gameLevel.coconuts?.remove(coconut)
        })
    }
    
}
