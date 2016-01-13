
//
//  AAPLGameLevel.swift
//  BananasSwift
//
//  Created by Andrew on 22/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/*
Abstract:

This class manages most of the game logic, including setting up the scene and keeping score.

*/

import Foundation
import SceneKit
import SpriteKit

struct AAPLCategoryBitMasks {
    static let ShadowReceiverCategory = 0x0000_0002
}

// Bitmasks for Physics categories
struct GameCollisionCategory {
    static let Ground    = 0x00000002
    static let Banana    = 0x00000004
    static let Player    = 0x00000008
    static let Lava      = 0x00000010
    static let Coin      = 0x00000020
    static let Coconut   = 0x00000040
    static let NoCollide = 0x00000080
}

struct NodeCategory {
    static let Torch = 0x00000002
    static let Lava  = 0x00000004
    static let Lava2 = 0x00000008
}


let BANANA_SCALE_LARGE: CGFloat = 0.5 * 10/4
let BANANA_SCALE: CGFloat = 0.5

class AAPLGameLevel : NSObject, AAPLGameUIState {
    
    var playerCharacter: AAPLPlayerCharacter?
    var monkeyCharacter: AAPLMonkeyCharacter?
    var camera: SCNNode?
    var bananas: Set<SCNNode>?
    var largeBananas: Set<SCNNode>?
    var coconuts: Set<SCNNode>?
    var hitByLavaReset: Bool = false
    
    var timeAlongPath: CGFloat = 0
    
    // AAPLGameUIState protocol
    var score: Int = 0
    var coinsCollected: Int = 0
    var bananasCollected: Int = 0
    var secondsRemaining: NSTimeInterval = 120
    var scoreLabelLocation: CGPoint = CGPoint()
    
    var rootNode: SCNNode!
    var sunLight: SCNNode!

    var pathPositions: [SCNVector3] = []
    var bananaCollectable: SCNNode?
    var largeBananaCollectable: SCNNode?
//    var monkeyProtoObject: AAPLSkinnedCharacter
//    var coconutProtoObject: SCNNode?
//    var palmTreeProtoObject: SCNNode?
    var monkeys: [AAPLMonkeyCharacter]?
    var _bananaIdleAction: SCNAction?
    var bananaIdleAction: SCNAction {
        get {
            if (self._bananaIdleAction == nil) {
                let rotateAction = SCNAction.rotateByX(0, y: CGFloat(M_PI_2), z: 0, duration: 1.0)
                rotateAction.timingMode = SCNActionTimingMode.EaseInEaseOut
                let reversed = rotateAction.reversedAction()
                self._bananaIdleAction = SCNAction.sequence([rotateAction, reversed])
            }
            return self._bananaIdleAction!
        }
    }
    
    var _hoverAction: SCNAction!
    var hoverAction: SCNAction! {
        get {
            if (self._hoverAction == nil) {
                let floatAction: SCNAction = SCNAction.moveByX(0, y: 10.0, z: 0, duration: 1.0)
                let floatAction2: SCNAction = floatAction.reversedAction()
                floatAction.timingMode = SCNActionTimingMode.EaseInEaseOut
                floatAction2.timingMode  = SCNActionTimingMode.EaseInEaseOut
                self._hoverAction = SCNAction.sequence([floatAction, floatAction2])
            }
            return self._hoverAction
        }
    }
    
    private var _lightOffsetFromCharacter: SCNVector3 = SCNVector3()
    private var _screenSpaceplayerPosition: SCNVector3 = SCNVector3()
    private var _worldSpaceLabelScorePosition: SCNVector3 = SCNVector3()
    
    override init() {
        self.rootNode = nil
        super.init()
    }
    
    func isHighEnd() -> Bool {
        // TODO: return true on OSX, iPad Air, iPhone 5s+
        return true;
    }
    
    
    // MARK: Pathing functions
    
    func setupPathColliders() {
        
        // Collect all the nodes that start with path_ under the dummy_front object
        // Set those objects as Physics category groun and create a static concave mesh collider
        // This simulation will use these as the ground to walk on
        
        if let front = self.rootNode?.childNodeWithName("dummy_front", recursively: true) {
            front.enumerateChildNodesUsingBlock({
                (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                if let _cname = child.name where _cname.hasPrefix("path_") {
                    // the geometry is attached to the first child node of the node named path_*
                    if let path: SCNNode = child.childNodes.first {
                        path.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static,
                            shape: SCNPhysicsShape(geometry: path.geometry!, options: [SCNPhysicsShapeTypeKey : SCNPhysicsShapeTypeConcavePolyhedron]))
                        
                        path.physicsBody!.categoryBitMask = GameCollisionCategory.Ground
                    }
                }
                
            })
        }
    }
    
    func collectSortedPathNodes() -> [SCNNode] {
        
        // Gather all the children under the dummy_master
        // Sort left to right, in the world
        // ASSUME: rootNode exists with name "dummy_master"
        let pathNodes: SCNNode = self.rootNode!.childNodeWithName("dummy_master", recursively: true)!
        
        let sortedNodes: [SCNNode] = pathNodes.childNodes.sort(
            { (obj1: AnyObject, obj2: AnyObject) -> Bool in
                let dummy1: SCNNode = obj1 as! SCNNode
                let dummy2: SCNNode = obj2 as! SCNNode
                if (dummy1.position.x < dummy2.position.x) {
                    return true // obj1 is ordered before obj2
                }
                return false
            }
        ) 
        
        return sortedNodes
    }
    
    func convertPathNodesIntoPathPositions() {
        // Walk the path, sampling every little bit, creating a path to follow
        // We use this path to move along left to right and right to left
        
        var sortedNodes = [SCNNode]()
        sortedNodes = self.collectSortedPathNodes()
        
        self.pathPositions = [SCNVector3]()
      
        self.pathPositions.append(SCNVector3Make(0,0,0))
        
        for d in sortedNodes {
            if let _name = d.name
            where _name.hasPrefix("dummy_path") {
                self.pathPositions.append(d.position)
            }
        }
        
        self.pathPositions.append(SCNVector3Make(0,0,0))
    }
    
    func resamplePathPositions() {
        // Calc the phantom end control point
        
        var controlPointA: SCNVector3 = self.pathPositions[self.pathPositions.count - 2]
        var controlPointB: SCNVector3 = self.pathPositions[self.pathPositions.count - 3]
        var controlPoint: SCNVector3 = SCNVector3()
        
        controlPoint.x = controlPointA.x + (controlPointA.x - controlPointB.x)
        controlPoint.y = controlPointA.y + (controlPointA.y - controlPointB.y)
        controlPoint.z = controlPointA.z + (controlPointA.z - controlPointB.z)
        
        self.pathPositions[self.pathPositions.count - 1] = controlPoint
        
        // Calc the phantom begin control point
        controlPointA = self.pathPositions[1]
        controlPointB = self.pathPositions[2]
        
        controlPoint.x = controlPointA.x + (controlPointA.x - controlPointB.x)
        controlPoint.y = controlPointA.y + (controlPointA.y - controlPointB.y)
        controlPoint.z = controlPointA.z + (controlPointA.z - controlPointB.z)
        self.pathPositions[0] = controlPoint
        
        var newPath = [SCNVector3]()
        var lastPosition: SCNVector3 = SCNVector3()
        let minDistanceBetweenPoints: CGFloat = 10.0
        let steps: Int = 10000
        for i in 0 ..< steps {
            let t: CGFloat = CGFloat(i) / CGFloat(steps)
            let currentPosition: SCNVector3 = self.locationAlongPath(t)
            if (i == 0) {
                newPath.append(currentPosition)
                lastPosition = currentPosition
            } else {
                let dist: CGFloat = CGFloat(GLKVector3Distance(SCNVector3ToGLKVector3(currentPosition),
                    SCNVector3ToGLKVector3(lastPosition)))
                if (dist > minDistanceBetweenPoints) {
                    newPath.append(currentPosition)
                    lastPosition = currentPosition
                }
            }
        }
        
        // Last Step - Return path postition array for our pathing system to query
        self.pathPositions = newPath
        
    }
    
    func calculatePathPositions() {
        self.setupPathColliders()
        self.convertPathNodesIntoPathPositions()
        self.resamplePathPositions()
    }
    
    /*! Given a relative percent along the path, return back the world location vector
    */
    func locationAlongPath(percent: CGFloat) -> SCNVector3 {

        if (self.pathPositions.count <= 3) {
            return SCNVector3Make(0,0,0)
        }
        

        let numSections: Int = self.pathPositions.count - 3
        var dist = CGFloat(percent) * CGFloat(numSections)
        // If dist is negative, casting to UInt will wrap it around to a huge number, and we will select the end of the section instead

        let distFloor = dist < 0 ? UInt.max : UInt(floor(dist))
        let currentPointIndex = Int(min(distFloor, UInt(numSections - 1)))
        dist -= CGFloat(currentPointIndex)
        let a: GLKVector3 = SCNVector3ToGLKVector3(self.pathPositions[currentPointIndex])
        let b: GLKVector3 = SCNVector3ToGLKVector3(self.pathPositions[currentPointIndex + 1])
        let c: GLKVector3 = SCNVector3ToGLKVector3(self.pathPositions[currentPointIndex + 2])
        let d: GLKVector3 = SCNVector3ToGLKVector3(self.pathPositions[currentPointIndex + 3])

        var location:SCNVector3 = SCNVector3()
        
        
        location.x = catmullRomValue(CGFloat(a.x), b: CGFloat(b.x), c: CGFloat(c.x), d: CGFloat(d.x), dist: dist)
        location.y = catmullRomValue(CGFloat(a.y), b: CGFloat(b.y), c: CGFloat(c.y), d: CGFloat(d.y), dist: dist)
        location.z = catmullRomValue(CGFloat(a.z), b: CGFloat(b.z), c: CGFloat(c.z), d: CGFloat(d.z), dist: dist)
        return location
    }
    

    
    /*! Direction player facing given the current walking direction
    */
    func getDirectionFromPosition(currentPosition: SCNVector3) -> SCNVector4 {
        let target:SCNVector3 = self.locationAlongPath(self.timeAlongPath - 0.05)
        
        let lookat: GLKMatrix4 = GLKMatrix4MakeLookAt(Float(currentPosition.x), Float(currentPosition.y), Float(currentPosition.z), Float(target.x), Float(target.y), Float(target.z), 0.0, 1.0, 0.0)
        let q: GLKQuaternion = GLKQuaternionMakeWithMatrix4(lookat)
        var angle: CGFloat = CGFloat(GLKQuaternionAngle(q))
        if (self.playerCharacter!.walkDirection == .Left) {
            angle -= CGFloat(M_PI)
        }
        return SCNVector4Make(0, 1, 0, angle)
    }
    
    /* Helper method for getting main player's direction
    */
    func getPlayerDirectionFromCurrentPosition() -> SCNVector4 {
        return self.getDirectionFromPosition(self.playerCharacter!.position)
    }
    
    
    /*! Create an action that pulses the opacity of a node
    */
    func pulseAction() -> SCNAction {
        let duration: NSTimeInterval = 8.0 / 6.0
        let pulseAction: SCNAction = SCNAction.repeatActionForever(
            SCNAction.sequence([SCNAction.fadeOpacityTo(0.3, duration: duration),
                                SCNAction.fadeOpacityTo(0.5, duration: duration),
                                SCNAction.fadeOpacityTo(1.0, duration: duration),
                                SCNAction.fadeOpacityTo(0.7, duration: duration),
                                SCNAction.fadeOpacityTo(0.4, duration: duration),
                                SCNAction.fadeOpacityTo(0.8, duration: duration)]))
        return pulseAction
    }
    
    /*! Create a simple point light
    */
    func torchLight() -> SCNLight {
        let light: SCNLight = SCNLight()
        light.type = SCNLightTypeOmni
        light.color = SKColor.orangeColor()
        light.attenuationStartDistance = 350
        light.attenuationEndDistance = 400
        light.attenuationFalloffExponent = 1
        return light
    }
    

    func animateDynamicNodes() {
        var dynamicNodesWithVertColorAnimation: [SCNNode] = []
        self.rootNode.enumerateChildNodesUsingBlock {
            (child: SCNNode!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            if let _pnode = child.parentNode,
                _name = _pnode.name
                where _name.hasPrefix("vine") {
                    if  child.geometry != nil
//                        where _geometry.geometrySourcesForSemantic(SCNGeometrySourceSemanticColor) != nil 
                    {
                             dynamicNodesWithVertColorAnimation.append(child)
                    }
            }
        }
        
        
        // Animate the dynamic node
        let shaderCode: String =
        "uniform float timeOffset;\n" +
        "#pragma body\n" +
        "float speed = 20.05;\n" +
        "_geometry.position.xyz += (speed * sin(u_time + timeOffset) * _geometry.color.rgb);\n"
        
        for dynamicNode: SCNNode in dynamicNodesWithVertColorAnimation {
            dynamicNode.geometry?.shaderModifiers = [SCNShaderModifierEntryPointGeometry : shaderCode]
            let explodeAnimation: CABasicAnimation = CABasicAnimation(keyPath: "timeOffset")
            explodeAnimation.duration = 2.0
            explodeAnimation.repeatCount = FLT_MAX
            explodeAnimation.autoreverses = true
            explodeAnimation.toValue = AAPLRandomPercent()
            explodeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            dynamicNode.geometry?.addAnimation(explodeAnimation, forKey: "sway")
        }
    }
    
    func collideWithLava() {
        if (hitByLavaReset == true) { return }
        
        self.playerCharacter?.inRunAnimation = false
        
        AAPLGameSimulation.sim.playSound("ack.caf")
        
        //Blink for a second
        let blinkOffAction = SCNAction.fadeOutWithDuration(0.15)
        let blinkOnAction = SCNAction.fadeInWithDuration(0.15)
        let cycle = SCNAction.sequence([blinkOffAction, blinkOnAction])
        let repeatCycle = SCNAction.repeatAction(cycle, count: 7)
        
        self.hitByLavaReset = true
        
        self.playerCharacter?.runAction(repeatCycle, completionHandler: {
            () -> Void in
            self.timeAlongPath = 0
            self.playerCharacter?.position = self.locationAlongPath(self.timeAlongPath)
            self.playerCharacter?.rotation = self.getPlayerDirectionFromCurrentPosition()
            self.hitByLavaReset = false
        })
    }
    
    func moveCharacterAlongPathWith(deltaTime: NSTimeInterval, currentState: AAPLGameState) {
        if self.playerCharacter?.isRunning == true {
            if currentState == .InGame {
                var currWalkSpeed = self.playerCharacter!.walkSpeed
                if self.playerCharacter!.isJumping == true {
                    currWalkSpeed += self.playerCharacter!.jumpBoost
                }
                
                self.timeAlongPath += CGFloat(CGFloat(deltaTime) * currWalkSpeed * (self.playerCharacter?.walkDirection == .Right ? 1 : -1))
                
                // limit how far the player can go in the left and right directions
                if (self.timeAlongPath < 0.0) {
                    self.timeAlongPath = 0.0
                } else if (self.timeAlongPath > 1.0) {
                    self.timeAlongPath = 1.0
                }
                
                let newPosition = self.locationAlongPath(self.timeAlongPath)
                self.playerCharacter!.position = SCNVector3Make(newPosition.x,
                    self.playerCharacter!.position.y,
                    newPosition.z)
                if (self.timeAlongPath >= 1.0) {
                    self.doGameOver()
                }
            } else {
                self.playerCharacter?.inRunAnimation = false
            }
        }
    }
    
    func updateSunLightPosition() {
        var lightPos = _lightOffsetFromCharacter
        if let charPos = self.playerCharacter?.position {
            lightPos.x += charPos.x
            lightPos.y += charPos.y
            lightPos.z += charPos.z
            self.sunLight.position = lightPos
        }
    }
    
    // MARK: Creation
    
    /*! Create a torch node that has a particle effect and point light attached
    */
    func createTorchNode() -> SCNNode {
        
        // Trying to create static var in func
        // The alternative is to have a static var at the class level
        struct torch {
            static var template: SCNNode!
        }
        
        if (torch.template == nil) {
            torch.template = SCNNode()
            let geometry: SCNGeometry = SCNBox(width: 20, height: 100, length: 20, chamferRadius: 0)
            geometry.firstMaterial!.diffuse.contents = SKColor.brownColor()
            torch.template.geometry = geometry
            
            let particleEmitter: SCNNode = SCNNode()
            particleEmitter.position = SCNVector3Make(0, 50, 0)
            
            let fire: SCNParticleSystem = SCNParticleSystem(named: "torch.scnp",
                inDirectory: "art.scnassets/level/effects")!
            
            particleEmitter.addParticleSystem(fire)
            particleEmitter.light = self.torchLight()
            torch.template.addChildNode(particleEmitter)
        }
        return torch.template.clone() 
    }
    
    
    /* Helper Method for loading Swinging Torch
    */
    func createSwingingTorch() {
        // Load the dae from disk
        if let torchSwing = AAPLGameSimulation.loadNodeWithName("dummy_master",
            fromSceneNamed: AAPLGameSimulation.pathForArtResource("level/torch.dae")) {
                // Attach to origin
                self.rootNode?.addChildNode(torchSwing)
        }
    }
    
    /* Create Lava Animation
    */
    func createLavaAnimation() {
        // Find lava nodes in the scene
        if let lavaNodes : [SCNNode] = self.rootNode?.childNodesPassingTest({
            (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Bool in
            if let _cname = child.name where _cname.hasPrefix("lava_0") {
                return true
            }
            return false
        }) {
        
        // Add concave collider to each lava mesh
        for lava: SCNNode in lavaNodes {
            let childrenWithGeometry: [SCNNode] = lava.childNodesPassingTest({
                (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Bool in
                if (child.geometry != nil) {
                    stop.memory = true
                    return true
                }
                return false
            }) 
            
            let lavaGeometry: SCNNode = childrenWithGeometry[0]
            
            lavaGeometry.physicsBody = SCNPhysicsBody(type: .Static,
                shape: SCNPhysicsShape(geometry: lavaGeometry.geometry!, options: [SCNPhysicsShapeTypeKey : SCNPhysicsShapeTypeConcavePolyhedron]))
            lavaGeometry.physicsBody?.categoryBitMask = GameCollisionCategory.Lava
            lavaGeometry.categoryBitMask = NodeCategory.Lava
            
            // UV animate the lava texture in the vertex shader
            let shaderCode =
            "uniform float speed;\n" +
                "#pragma body\n" +
            "_geometry.texcoords[0] += vec2(sin(_geometry.position.z+0.1 + u_time * 0.1) * 0.1, -1.0 * 0.05 * u_time);\n"
            lavaGeometry.geometry?.shaderModifiers = [SCNShaderModifierEntryPointGeometry : shaderCode]
        }
        }
    }

    /*! Helper Method for creating a large banana
    Create model, Add particle system, Add persistent SKAction, Add / Setup collision
    */
    func createLargeBanana() -> SCNNode? {
        
        if (self.largeBananaCollectable == nil) {
            if let _lbanana = AAPLGameSimulation.loadNodeWithName("banana",
                fromSceneNamed: AAPLGameSimulation.pathForArtResource("level/banana.dae")) {
                    _lbanana.scale = SCNVector3Make(BANANA_SCALE_LARGE, BANANA_SCALE_LARGE, BANANA_SCALE_LARGE)
                    
                    let sphereGeometry = SCNSphere(radius: 100)
                    let physicsShape = SCNPhysicsShape(geometry: sphereGeometry, options: nil)
                    _lbanana.physicsBody = SCNPhysicsBody(type: .Kinematic, shape: physicsShape)
                    
                    // only collide with player and ground
                    _lbanana.physicsBody?.collisionBitMask = GameCollisionCategory.Player | GameCollisionCategory.Ground
                    
                    // Declare self in the coin category
                    _lbanana.physicsBody?.categoryBitMask = GameCollisionCategory.Coin
                    
                    // Rotate forever
                    let rotateCoin = SCNAction.rotateByX(0, y: 8, z: 0, duration: 2.0)
                    let `repeat` = SCNAction.repeatActionForever(rotateCoin)
                    
                    _lbanana.rotation = SCNVector4Make(0.0, 1.0, 0.0, CGFloat(M_PI_2))
                    _lbanana.runAction(`repeat`)
                    
                    self.largeBananaCollectable = _lbanana
            }
        }
        
        let node = self.largeBananaCollectable?.clone()
        
        if let newSystem = AAPLGameSimulation.loadParticleSystemWithName("sparkle") {
            node?.addParticleSystem(newSystem)
        }
        
        return node
        
    }
    
    /*! Helper Method for creating a small banana
    */
    func createBanana() -> SCNNode? {
        
        // Create model
        if (self.bananaCollectable == nil) {
            
            if let _banana = AAPLGameSimulation.loadNodeWithName("banana",
                fromSceneNamed: AAPLGameSimulation.pathForArtResource("level/banana.dae")) {
                    
                    
                    _banana.scale = SCNVector3Make(BANANA_SCALE, BANANA_SCALE, BANANA_SCALE)
                    
                    let sphereGeometry = SCNSphere(radius: 40)
                    let physicsShape = SCNPhysicsShape(geometry: sphereGeometry, options: nil)
                    
                    _banana.physicsBody = SCNPhysicsBody(type: .Kinematic, shape: physicsShape)
                    
                    // only collide with player and ground
                    _banana.physicsBody!.collisionBitMask = GameCollisionCategory.Player | GameCollisionCategory.Ground
                    
                    // Declare self in the banana category
                    _banana.physicsBody!.categoryBitMask = GameCollisionCategory.Banana
                    
                    
                    // Rotate and Hover forever
                    _banana.rotation = SCNVector4Make(0.5, 1.0, 0.5, CGFloat(-M_PI_2))
                    let idleHoverGroupAction = SCNAction.group([self.bananaIdleAction, self.hoverAction])
                    let repeatForeverAction = SCNAction.repeatActionForever(idleHoverGroupAction)
                    _banana.runAction(repeatForeverAction)
                    self.bananaCollectable = _banana
            }
        }
        return self.bananaCollectable?.clone()
    }
    
    // CreateLevel
    func createLevel() -> SCNNode? {
        //
        // Load the level dae from disk
        // Setup and construct the level. ( Should really be done offline in an editor ).
       self.rootNode = SCNNode()
        
        
        // load level dae and add root children to the scene
        let scene: SCNScene? = SCNScene(named: "level.dae",
            inDirectory: AAPLGameSimulation.pathForArtResource("level/"),
            options: [SCNSceneSourceConvertToYUpKey : true])
        
        
        if let childNodes = scene?.rootNode.childNodes {
            for node: SCNNode in childNodes {
                self.rootNode.addChildNode(node)
            }
        }
        
        // retrieve main camera
        self.camera = self.rootNode.childNodeWithName("camera_game", recursively: true)
        
        // create our path that the player character will follow
        self.calculatePathPositions()
        
        // sun/Moon light
        self.sunLight = self.rootNode.childNodeWithName("FDirect001", recursively: true)
        self.sunLight.eulerAngles = SCNVector3Make(CGFloat(7.1 * M_PI_4), CGFloat(M_PI_4), 0)
        self.sunLight.light?.shadowSampleCount = 1
        _lightOffsetFromCharacter = SCNVector3Make(1500, 2000, 1000)
        
        // workaround directional light deserialization issue
        self.sunLight.light?.zNear = 100
        self.sunLight.light?.zFar = 5000
        self.sunLight.light?.orthographicScale = 1000
        
        if (self.isHighEnd() == false) {
            // use blob shadows on low end devices
            self.sunLight.light?.shadowMode = SCNShadowMode.Modulated
            self.sunLight.light?.categoryBitMask = 0x2
            self.sunLight.light?.orthographicScale = 60
            self.sunLight.eulerAngles = SCNVector3Make(CGFloat(M_PI_2), 0, 0)
            _lightOffsetFromCharacter = SCNVector3Make(0, 2000, 0)
            
            self.sunLight.light?.gobo!.contents = "Images/techniques/blobShadow.jpg"
            self.sunLight.light?.gobo!.intensity = 0.5
            
            let middle: SCNNode = self.rootNode.childNodeWithName("dummy_front", recursively: true)!
            middle.enumerateChildNodesUsingBlock({
                (child:SCNNode, stop:UnsafeMutablePointer<ObjCBool>) -> Void in
                child.categoryBitMask = 0x2
            })
        }
        
        // Torches
        let torchPos: [CGFloat] = [0, -1, 0.092467, -1, -1, 0.5, 0.7920, 0.953830]
        
        for i in 0 ..< 8 {
            if (torchPos[i] == -1) { continue }
            var location: SCNVector3 = self.locationAlongPath(torchPos[i])
            location.y += 50
            location.z += 150
            
            let node: SCNNode = self.createTorchNode()
            node.position = location
            self.rootNode.addChildNode(node)
        }
        
        // After load, we add nodes that are dynamic / animated / not static
        self.createLavaAnimation()
        self.createSwingingTorch()
        self.animateDynamicNodes()
        
        // Create player character
        if let characterRoot = AAPLGameSimulation.loadNodeWithName(nil,
            fromSceneNamed: "art.scnassets/characters/explorer/explorer_skinned.dae") {
                self.playerCharacter = AAPLPlayerCharacter(characterNode: characterRoot)
                self.timeAlongPath = 0
                self.playerCharacter!.position = self.locationAlongPath(self.timeAlongPath)
                self.playerCharacter!.rotation = self.getPlayerDirectionFromCurrentPosition()
                self.rootNode.addChildNode(self.playerCharacter!)
        }
        
        // Optimize lighting and shadows
        // only the character should cast shadows
        self.rootNode.enumerateChildNodesUsingBlock( {
            (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            child.castsShadow = false
        })
        
        self.playerCharacter?.enumerateChildNodesUsingBlock( {
            (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            child.castsShadow = true
        })
        
        // Add some monkeys to the scene
        self.addMonkeyAtPosition(SCNVector3Make(0, -30, -400), rotation: 0)
        self.addMonkeyAtPosition(SCNVector3Make(3211, 146, -400), rotation: CGFloat(-M_PI_4))
        self.addMonkeyAtPosition(SCNVector3Make(5200, 330, 600), rotation: 0)
        
        // Volcano
        var oldVolcano = self.rootNode.childNodeWithName("volcano", recursively: true)
        let volcanoDaeName = AAPLGameSimulation.pathForArtResource("level/volcano_effects.dae")
        let newVolcano = AAPLGameSimulation.loadNodeWithName("dummy_master", fromSceneNamed: volcanoDaeName)
        
        if (newVolcano != nil) {
            oldVolcano?.addChildNode(newVolcano!)
            oldVolcano?.geometry = nil
            oldVolcano = newVolcano!.childNodeWithName("volcano", recursively: true)
        }
        oldVolcano = oldVolcano?.childNodes[0]
        
        // Animate our dynamic volcano node
        let shaderCode =
        "uniform float speed;\n" +
        "_geometry.color = vec4(a_color.r, a_color.r, a_color.r, a_color.r);\n" +
        "_geometry.texcoords[0] += (vec2(0.0, 1.0) * 0.05 * u_time);\n"
        
        let fragmentShadeCode =
        "#pragma transparent\n"
        
        // dim background
        let back = self.rootNode.childNodeWithName("dummy_rear", recursively: true)
        back?.enumerateChildNodesUsingBlock({
            (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            child.castsShadow = false
            if let _geometry = child.geometry {
                for material in _geometry.materials {
                    material.lightingModelName = SCNLightingModelConstant
                    material.multiply.contents = SKColor(white: 0.3, alpha: 1.0)
                    material.multiply.intensity = 1
                }
            }
        })

        // remove lighting from middle plane
        let middle = self.rootNode.childNodeWithName("dummy_middle", recursively: true)
        middle?.enumerateChildNodesUsingBlock({
            (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            if let _geometry = child.geometry {
                for material in _geometry.materials {
                    material.lightingModelName = SCNLightingModelConstant
                }
            }
        })
        
        if (newVolcano != nil) {
            newVolcano!.enumerateChildNodesUsingBlock({
                (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                if let _geometry = child.geometry where child != oldVolcano  {
                    _geometry.firstMaterial?.lightingModelName = SCNLightingModelConstant
                    _geometry.firstMaterial?.multiply.contents = SKColor.whiteColor()
                    _geometry.shaderModifiers = [SCNShaderModifierEntryPointGeometry : shaderCode,
                        SCNShaderModifierEntryPointFragment : fragmentShadeCode]
                }
            })
            
        }
        
        if (self.isHighEnd() == false) {
            self.rootNode.enumerateChildNodesUsingBlock({
                (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                if let _geometry = child.geometry {
                    for m in _geometry.materials {
                        m.lightingModelName = SCNLightingModelConstant
                    }
                }
            })
            
            self.playerCharacter?.enumerateChildNodesUsingBlock({
                (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                if let _geometry = child.geometry {
                    for m in _geometry.materials {
                        m.lightingModelName = SCNLightingModelLambert
                    }
                }
            })
        }
        
        self.coconuts = []
        
        return self.rootNode!
    }
    
    /*! Reset the game simulation for the start of the game or restart after you have completed the level.
    */
    func resetLevel() {
        score = 0
        secondsRemaining = 120
        coinsCollected = 0
        bananasCollected = 0
        
        timeAlongPath = 0
        self.playerCharacter?.position = self.locationAlongPath(timeAlongPath)
        self.playerCharacter?.rotation = self.getPlayerDirectionFromCurrentPosition()
        self.hitByLavaReset = false
        
        // Remove dynamic objects from the level
        SCNTransaction.begin()
        
        if let _coconuts = self.coconuts {
            for b in _coconuts {
                b.removeFromParentNode()
            }
        }
        
        if let _bananas = self.bananas {
            for b in _bananas {
                b.removeFromParentNode()
            }
        }
        
        if let _largeBananas = self.largeBananas {
            for b in _largeBananas {
                b.removeFromParentNode()
            }
        }
        
        SCNTransaction.commit()
        
        // Add dynamic objects to the level, like bananas and large bananas
        self.coconuts = []
        self.bananas = []
        for i in 0 ..< 10 {
            if let banana = self.createBanana() {
                self.rootNode.addChildNode(banana)
                var location = self.locationAlongPath(CGFloat((Float(i)+1.0)/20.0 - 0.01))
                location.y += 50
                banana.position = location
                
                self.bananas!.insert(banana)
            }
        }
        
        self.largeBananas = []
        for _ in 0 ..< 6 {
            if let largeBanana = self.createLargeBanana() {
                self.rootNode.addChildNode(largeBanana)
                var location = self.locationAlongPath(AAPLRandomPercent())
                location.y += 50
                largeBanana.position = location
                self.largeBananas!.insert(largeBanana)
            }
        }
        
        AAPLGameSimulation.sim.playMusic("music.caf")
        AAPLGameSimulation.sim.playMusic("night.caf")

    }
    
    /*! Given a world position and rotation, load the monkey dae and place it in the world
    */
    func addMonkeyAtPosition(worldPos: SCNVector3, rotation: CGFloat) {
        if self.monkeys == nil {
            self.monkeys = []
        }
        
        let palmTree = self.createMonkeyPalmTree()
        palmTree.position = worldPos
        palmTree.rotation = SCNVector4Make(0, 1, 0, rotation)
        self.rootNode.addChildNode(palmTree)
        
        
        if let monkey = palmTree.childNodeWithName("monkey", recursively: true) as? AAPLMonkeyCharacter {
            self.monkeys!.append(monkey)
        }
    }
    
    /*! Load the palm tree that the monkey is attached to
    */
    func createMonkeyPalmTree() -> SCNNode {
        // Trying to create static var in func
        // The alternative is to have a static var at the class level
        struct tree {
            static var palmTreeProtoObject: SCNNode!
        }
        
        if (tree.palmTreeProtoObject == nil) {
            let palmTreeDae = AAPLGameSimulation.pathForArtResource("characters/monkey/monkey_palm_tree.dae")
            tree.palmTreeProtoObject = AAPLGameSimulation.loadNodeWithName("PalmTree",
                fromSceneNamed: palmTreeDae)
        }
        
        let palmTree = tree.palmTreeProtoObject.clone() 
        if let monkeyNode = AAPLGameSimulation.loadNodeWithName(nil,
            fromSceneNamed: "art.scnassets/characters/monkey/monkey_skinned.dae") {
                let monkey = AAPLMonkeyCharacter(characterRootNode: monkeyNode)
                monkey.createAnimations()
                
                palmTree.addChildNode(monkey)
        }
        return palmTree
    }
    
    /*! Change the game state to the postgame
    */
    func doGameOver() {
        self.playerCharacter?.inRunAnimation = false
        AAPLGameSimulation.sim.gameState = AAPLGameState.PostGame
    }

    /*! Main game logic
    */
    func update(deltaTime: NSTimeInterval, aRenderer: SCNSceneRenderer) {
        // Based on gamestate:
        // ingame: Move character if running
        // ingame: prevent movement of character past level bounds
        // ingame: perform logic for player char
        // any: move directional light with any player movement
        // ingame: update the coconuts kinematically
        // ingame: perform logic for each monkey
        // ingame: because our camera could have moved, update the transforms to fly
        //          collected bananas from the player (world space) to score (screen space)
        
        let appDelegate = AAPLAppDelegate.sharedAppDelegate
        let currentState = AAPLGameSimulation.sim.gameState
        
        // Move character along path if walking
        self.moveCharacterAlongPathWith(deltaTime, currentState: currentState)
        
        // Based on the time along path, rotate the character to face correct direction
        self.playerCharacter?.rotation = self.getPlayerDirectionFromCurrentPosition()
        if (currentState == .InGame) {
            self.playerCharacter?.update(deltaTime)
        }
        
        // move the light
        self.updateSunLightPosition()
        
        if (currentState == .PreGame ||
            currentState == .PostGame ||
            currentState == .Paused)
        { return }
        
        // update Monkeys
        if let _monkeys = self.monkeys as [AAPLMonkeyCharacter]? {
            for monkey in _monkeys {
                monkey.update(deltaTime)
            }
        }
        
        // Update timer and check for Game Over
        secondsRemaining -= deltaTime
        if (secondsRemaining < 0.0) {
            self.doGameOver()
        }
        
        // update the player's SP position
        if (self.playerCharacter != nil) {
            let playerPosition = AAPLMatrix4GetPosition(self.playerCharacter!.worldTransform)
            _screenSpaceplayerPosition = appDelegate.scnView.projectPoint(playerPosition)
        
        
            // update the SP position of the score label
            let pt = self.scoreLabelLocation
            _worldSpaceLabelScorePosition = appDelegate.scnView.unprojectPoint(
                SCNVector3Make(pt.x, pt.y, _screenSpaceplayerPosition.z))
        }
    }
    
    func collectBanana(banana: SCNNode) {
        // Flyoff the banana to the screen space position score label
        // Don't increment score until the banana hits the score label
        
        // ignore collisions
        banana.physicsBody = nil
        self.bananasCollected++
        
        let variance = 60
        let apexY: CGFloat = (_worldSpaceLabelScorePosition.y * 0.8) + CGFloat((Int(rand()) % variance)  - (variance / 2))
        _worldSpaceLabelScorePosition.z = banana.position.z
        let apex = SCNVector3Make(
            banana.position.x + 10.0 + CGFloat((Int(rand()) % variance)  - (variance / 2)),
            apexY,
            banana.position.z)
        
        let startFlyOff = SCNAction.moveTo(apex, duration: 0.25)
        startFlyOff.timingMode = SCNActionTimingMode.EaseOut
        
        let duration: CGFloat = 0.25
        let endFlyOff: SCNAction = SCNAction.customActionWithDuration(NSTimeInterval(duration), actionBlock: {
            (node: SCNNode, elapsedTime: CGFloat) -> Void in
            let t = elapsedTime / duration
            let v = SCNVector3Make(
                apex.x + ((self._worldSpaceLabelScorePosition.x - apex.x) * t),
                apex.y + ((self._worldSpaceLabelScorePosition.y - apex.y) * t),
                apex.z + ((self._worldSpaceLabelScorePosition.z - apex.x) * t))
            node.position = v
        })
        
        endFlyOff.timingMode = SCNActionTimingMode.EaseInEaseOut
        let flyoffSequence: SCNAction = SCNAction.sequence([startFlyOff, endFlyOff])
        
        banana.runAction(flyoffSequence, completionHandler: {
            () -> Void in
            self.bananas?.remove(banana)
            banana.removeFromParentNode()
            // Add to score
            self.score++
            AAPLGameSimulation.sim.playSound("deposit.caf")
            if (self.bananas?.count == 0) {
                // Game Over
                self.doGameOver()
            }
        })
        
    }
    
    func collectLargeBanana(largeBanana: SCNNode) {
        // When a player hits a large banana, explode it into smaller bananas
        // We explode into a predefined pattern: square, diamond, letterA, letterB
        
        // ignore collisions
        largeBanana.physicsBody = nil
        self.coinsCollected++
        
        self.largeBananas?.remove(largeBanana)
        largeBanana.removeAllParticleSystems()
        largeBanana.removeFromParentNode()
        
        // Add to score
        self.score += 100
        let square = [  1, 1, 1, 1, 1,
                        1, 1, 1, 1, 1,
                        1, 1, 1, 1, 1,
                        1, 1, 1, 1, 1,
                        1, 1, 1, 1, 1 ]

        let diamond = [ 0, 0, 1, 0, 0,
                        0, 1, 1, 1, 0,
                        1, 1, 1, 1, 1,
                        0, 1, 1, 1, 0,
                        0, 0, 1, 0, 0 ]

        let letterA = [ 1, 0, 0, 1, 0,
                        1, 0, 0, 1, 0,
                        1, 1, 1, 1, 0,
                        1, 0, 0, 1, 0,
                        0, 1, 1, 0, 0 ]
        
        let letterB = [ 1, 1, 0, 0, 0,
                        1, 0, 1, 0, 0,
                        1, 1, 0, 0, 0,
                        1, 0, 1, 0, 0,
                        1, 1, 0, 0, 0 ]
        
        let choices = [square, diamond, letterA, letterB]
        
        let vertSpacing: CGFloat = 40
        let spacing: CGFloat = 0.0075
        let choice = choices[Int(rand()) % choices.count]
        for y in 0 ..< 5 {
            for x in 0 ..< 5 {
                let place = choice[y*5 + x]
                if place != 1 { continue }
                
                if let _banana = self.createBanana() {
                
                    self.rootNode.addChildNode(_banana)
                    _banana.position = largeBanana.position
                    _banana.physicsBody?.categoryBitMask = GameCollisionCategory.NoCollide
                    _banana.physicsBody?.collisionBitMask = GameCollisionCategory.Ground
                    
                    var endPoint = self.locationAlongPath(self.timeAlongPath + (spacing * CGFloat(x+1)))
                    endPoint.y += vertSpacing * CGFloat(y + 1)
                    let flyoff = SCNAction.moveTo(endPoint, duration: Double(AAPLRandomPercent()) * 0.25)
                    flyoff.timingMode = SCNActionTimingMode.EaseInEaseOut
                    
                    // Prevent collision until the banana gets to the final resting spot
                    _banana.runAction(flyoff, completionHandler: {
                        () -> Void in
                        _banana.physicsBody?.categoryBitMask = GameCollisionCategory.Banana
                        _banana.physicsBody?.collisionBitMask = GameCollisionCategory.Ground | GameCollisionCategory.Player
                        AAPLGameSimulation.sim.playSound("deposit.caf")
                    })
                    self.bananas?.insert(_banana)
                }
            }
        }
    }
    
    func collideWithCoconut(coconut: SCNNode, contactPoint:SCNVector3) {
        // No more collisions, let it bounce away and fade out
        
        coconut.physicsBody?.collisionBitMask = 0

        coconut.runAction(  SCNAction.sequence([SCNAction.waitForDuration(1.0),
                            SCNAction.fadeOutWithDuration(1.0),
                            SCNAction.removeFromParentNode()])) {
            self.coconuts?.remove(coconut)
        }
        
        // Decrement Score
        var amountToDrop: Int = self.score / 10
        switch amountToDrop {
        case amountToDrop where amountToDrop < 1:
            amountToDrop = 1
        case amountToDrop where amountToDrop > 10:
            amountToDrop = 10
        case amountToDrop where amountToDrop > self.score:
            amountToDrop = self.score
        default:
            break
        }
        self.score -= amountToDrop
        
        // Throw Bananas
        let spacing = 40
        for x in 0 ..< amountToDrop {
            if let _banana = self.createBanana() {
            
            
                self.rootNode.addChildNode(_banana)
                _banana.position = contactPoint
                _banana.physicsBody?.categoryBitMask = GameCollisionCategory.NoCollide
                _banana.physicsBody?.collisionBitMask = GameCollisionCategory.Ground
                
                var endPoint = SCNVector3Make(0, 0, 0)
                endPoint.x -= CGFloat((spacing * x) + spacing)
                let flyoff = SCNAction.moveTo(endPoint, duration: Double(AAPLRandomPercent()) * 0.75)
                flyoff.timingMode = SCNActionTimingMode.EaseInEaseOut
                
                // Prevent collision until the banana gets to the final resting spot
                _banana.runAction(flyoff, completionHandler: {
                    () -> Void in
                    _banana.physicsBody?.categoryBitMask = GameCollisionCategory.Banana
                    _banana.physicsBody?.collisionBitMask = GameCollisionCategory.Ground | GameCollisionCategory.Player
                })
                self.bananas?.insert(_banana)
            }
        }
        
    }
    
}