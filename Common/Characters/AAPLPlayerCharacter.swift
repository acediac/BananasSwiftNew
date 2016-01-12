   //
//  AAPLPlayerCharacter.swift
//  BananasSwift
//
//  Created by Andrew on 23/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/* 
Abstract:

This class simulates the player character. It manages the character's animations and simulates movement and jumping.

*/
import Foundation
import SceneKit

enum WalkDirection {
    case Left, Right
}

enum AAPLCharacterAnimation {
    case Die
    case Run
    case Jump
    case JumpFalling
    case JumpLand
    case Idle
    case GetHit
    case Bored
    case RunStart
    case RunStop
    case Count
}



class AAPLPlayerCharacter: AAPLSkinnedCharacter {
    
    // Animation State
    var inRunAnimation: Bool = false {
        //get {return self.inRunAnimation }
        didSet {
            if (self.inRunAnimation == oldValue) {
                return
            }
           // self.inRunAnimation = newValue
            
            // If we are running
            if (self.inRunAnimation == true) {
                walkSpeed = baseWalkSpeed * 2
                if let runKey = AAPLPlayerCharacter.keyForAnimationType(.Run),
                      idleKey = AAPLPlayerCharacter.keyForAnimationType(.Idle),
                      runAnim = self.cachedAnimation(runKey) {
                        self.mainSkeleton.removeAnimationForKey(idleKey, fadeOutDuration: 0.15)
                        self.mainSkeleton.addAnimation(runAnim, forKey: runKey)
                        // add or turn on the flow of dust particles
                        if let _dustWalking = self.dustWalking {
                            if let _particleSystems = self.particleSystems
                                where _particleSystems.contains(_dustWalking)  {
                                    _dustWalking.birthRate = self.dustWalkingBirthRate
                            } else {
                                // No existing particle systems, just add it
                                self.addParticleSystem(_dustWalking)
                            }
                        }
                }
            } else {
                // Fade out run and move to run stop
                if let runKey: String = AAPLPlayerCharacter.keyForAnimationType(.Run),
                    runStopKey: String = AAPLPlayerCharacter.keyForAnimationType(.Idle),
                    runStopAnim = self.cachedAnimation(runStopKey) {
                        runStopAnim.fadeInDuration = 0.15
                        runStopAnim.fadeOutDuration = 0.15
                        self.mainSkeleton.removeAnimationForKey(runKey, fadeOutDuration: 0.15)
                        self.mainSkeleton.addAnimation(runStopAnim, forKey: runStopKey)
                        self.walkSpeed = baseWalkSpeed
                        self.turnOffWalkingDust()
                        isWalking = false
                }
            }
        }

    }
    
    
    var inHitAnimation: Bool = false {
        
        //get { return self.inHitAnimation }
        
        didSet {
//            self.inHitAnimation = newValue
            
            // Play the get hit animation
            if let anim: CAAnimation = self.cachedAnimation(AAPLPlayerCharacter.keyForAnimationType(.GetHit)) {
                anim.repeatCount = 0
                anim.fadeInDuration = 0.15
                anim.fadeOutDuration = 0.15
                self.mainSkeleton.addAnimation(anim, forKey: AAPLPlayerCharacter.keyForAnimationType(.GetHit))
            }
            
            self.inHitAnimation = false
            AAPLGameSimulation.sim.playSound("coconuthit.caf")
        }

    }
    
    var inJumpAnimation: Bool = false {
        
        //get { return self.inJumpAnimation }
        
        didSet {
            if (self.inJumpAnimation == oldValue) {
                return
            }
            
           // self.inJumpAnimation = newValue
            if (self.inJumpAnimation == true) {
                // Launching true means we are in the preflight jump animation
                self.isLaunching = true
                
                if let anim: CAAnimation = self.cachedAnimation(AAPLPlayerCharacter.keyForAnimationType(.Jump)) {
                    self.mainSkeleton.removeAllAnimations()
                    self.mainSkeleton.addAnimation(anim, forKey: AAPLPlayerCharacter.keyForAnimationType(.Jump))
                    self.turnOffWalkingDust()
                }
            } else {
                self.isLaunching = false
            }
        }
    }
    var groundPlaneHeight: CGFloat
    var velocity: GLKVector3
    var baseWalkSpeed: CGFloat
    
    var cameraHelper: SCNNode = SCNNode()
    var changingDirection: Bool
    
    var walkSpeed: CGFloat
    var jumpBoost: CGFloat
    
    var walkDirection: WalkDirection
    var collideSphere: SCNNode = SCNNode()
    
    var isRunning: Bool {
        get {
            return self.isWalking
        }
    }
    var isJumping: Bool
    var isLaunching: Bool
    
    let dustPoof: SCNParticleSystem?
    let dustWalking: SCNParticleSystem?
    
    private var isWalking: Bool
    private var jumpForce: CGFloat
    private var jumpDuration: CGFloat
    private var jumpForceOrig: CGFloat
    private var dustWalkingBirthRate: CGFloat = 0
    
    class func keyForAnimationType(animType: AAPLCharacterAnimation) -> String? {
        switch (animType) {
        case .Bored:
            return "bored-1"
        case .Die:
            return "die-1"
        case .GetHit:
            return "hit-1"
        case .Idle:
            return "idle-1"
        case .Jump:
            return "jump_start-1"
        case .JumpFalling:
            return "jump_falling-1"
        case .JumpLand:
            return "jump_land-1"
        case .Run:
            return "run-1"
        case .RunStart:
            return "run_start-1"
        case .RunStop:
            return "run_stop-1"
        case .Count:
            return nil
        }
    }
    
    init(characterNode: SCNNode) {

        // Setup walking parameters
        self.velocity = GLKVector3Make(0,0,0)
        self.isWalking = false
        self.changingDirection = false
        self.baseWalkSpeed = 0.0167
        self.walkSpeed = self.baseWalkSpeed
        self.isJumping = false
        self.isLaunching = false
        self.jumpBoost = 0.0
        self.groundPlaneHeight = 0.0
        self.walkDirection = .Right
        self.jumpForce = 7.0
        self.jumpForceOrig = 0.0
        self.jumpDuration = 0.0
        
        // Load our dust poof
        self.dustPoof = AAPLGameSimulation.loadParticleSystemWithName("dust")
        self.dustWalking = AAPLGameSimulation.loadParticleSystemWithName("dustWalking")
        if self.dustWalking != nil {
            self.dustWalkingBirthRate = self.dustWalking!.birthRate
        }
        
        super.init(characterRootNode: characterNode)
 
        self.categoryBitMask = NodeCategory.Lava

        // Node to help position the camera and attach to self
        self.addChildNode(self.cameraHelper)
        self.cameraHelper.position = SCNVector3Make(1000, 200, 0)
        
        // Create a capsule used for generic collision
        self.collideSphere.position = SCNVector3Make(0, 80, 0)
        let geo: SCNGeometry = SCNCapsule(capRadius: 90, height: 160)
        let shape2: SCNPhysicsShape = SCNPhysicsShape(geometry: geo, options: nil)
        self.collideSphere.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Kinematic, shape: shape2)
        
        // We only want to collide with bananas, coins, and coconuts.
        // Ground collision is handled elsewhere
        self.collideSphere.physicsBody?.collisionBitMask =
            GameCollisionCategory.Banana |
            GameCollisionCategory.Coin |
            GameCollisionCategory.Coconut |
            GameCollisionCategory.Lava
        
        // Put ourself into the player category so other objects can limit their scope of collision checks
        self.collideSphere.physicsBody?.categoryBitMask = GameCollisionCategory.Player
        self.addChildNode(self.collideSphere)
        
        
        // Load the animations and store via a lookup table
        self.setupIdleAnimation()
        self.setupRunAnimation()
        self.setupJumpAnimation()
        self.setupBoredAnimation()
        self.setupHitAnimation()
        self.playIdle(false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Animation Setup
    
    func setupIdleAnimation() {
        if let idleAnimation: CAAnimation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/idle", key: AAPLPlayerCharacter.keyForAnimationType(.Idle)) {
        
            idleAnimation.repeatCount = FLT_MAX
            idleAnimation.fadeInDuration = 0.15
            idleAnimation.fadeOutDuration = 0.15
        }
    }
    
    func setupRunAnimation() {
        let runKey = AAPLPlayerCharacter.keyForAnimationType(.Run)
        let runStartKey = AAPLPlayerCharacter.keyForAnimationType(.RunStart)
        let runStopKey = AAPLPlayerCharacter.keyForAnimationType(.RunStop)
        
        
        if let runAnim: CAAnimation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/run", key: runKey),
            runStartAnim: CAAnimation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/run_start", key: runStartKey),
            runStopAnim: CAAnimation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/run_stop", key:runStopKey) {
                
                runAnim.repeatCount = FLT_MAX
                runStartAnim.repeatCount = 0
                runStopAnim.repeatCount = 0
                
                runAnim.fadeInDuration = 0.05
                runAnim.fadeOutDuration  = 0.05
                runStartAnim.fadeInDuration = 0.05
                runStartAnim.fadeOutDuration  = 0.05
                runStopAnim.fadeInDuration = 0.05
                runStopAnim.fadeOutDuration  = 0.05
                
                let stepLeftBlock: SCNAnimationEventBlock = {
                    (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward:Bool) -> Void in
                    AAPLGameSimulation.sim.playSound("leftstep.caf")
                }
                let stepRightBlock: SCNAnimationEventBlock = {
                    (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward:Bool) -> Void in
                    AAPLGameSimulation.sim.playSound("rightstep.caf")
                }
                
                let startWalkStateBlock: SCNAnimationEventBlock = {
                    (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward:Bool) -> Void in
                    if (self.inRunAnimation == true) {
                        self.isWalking = true
                    } else {
                        self.mainSkeleton.removeAnimationForKey(runKey!, fadeOutDuration: 0.15)
                    }
                }
                
                let stopWalkStateBlock: SCNAnimationEventBlock = {
                    (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward:Bool) -> Void in
                    self.isWalking = false
                    self.turnOffWalkingDust()
                    if (self.changingDirection == true) {
                        self.inRunAnimation = true
                        self.changingDirection = false
                        self.walkDirection = self.walkDirection == .Left ? .Right : .Left
                    }
                }
                
                runStopAnim.animationEvents = [SCNAnimationEvent(keyTime: 2.0, block: stopWalkStateBlock)]
                runAnim.animationEvents = [SCNAnimationEvent(keyTime: 0.0, block: startWalkStateBlock),
                    SCNAnimationEvent(keyTime: 0.25, block: stepRightBlock),
                    SCNAnimationEvent(keyTime: 0.75, block: stepLeftBlock)]
        }
    }
    
    func setupJumpAnimation() {
        let jumpKey = AAPLPlayerCharacter.keyForAnimationType(.Jump)
        let fallingKey = AAPLPlayerCharacter.keyForAnimationType(.JumpFalling)
        let landKey = AAPLPlayerCharacter.keyForAnimationType(.JumpLand)
        let idleKey = AAPLPlayerCharacter.keyForAnimationType(.Idle)
        
        if let jumpAnimation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/jump_start", key: jumpKey),
            fallAnimation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/jump_falling", key: fallingKey),
            landAnimation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/jump_land", key: landKey) {
                
                
                jumpAnimation.fadeInDuration = 0.15
                jumpAnimation.fadeOutDuration = 0.15
                fallAnimation.fadeInDuration = 0.15
                fallAnimation.fadeOutDuration = 0.15
                landAnimation.fadeInDuration = 0.15
                landAnimation.fadeOutDuration = 0.15
                
                jumpAnimation.repeatCount = 0
                fallAnimation.repeatCount = 0
                landAnimation.repeatCount = 0
                
                jumpForce = 7.0
                jumpForceOrig = 7.0
                jumpDuration = CGFloat(jumpAnimation.duration)
                let leaveGroundBlock: SCNAnimationEventBlock = {
                    (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward:Bool) -> Void in
                    self.velocity = GLKVector3Add(self.velocity, GLKVector3Make(0, Float(self.jumpForce) * 2.1, 0))
                    self.isLaunching = false
                    self.inJumpAnimation = false
                }
                
                let pause: SCNAnimationEventBlock = {
                    (animation: CAAnimation!, animatedObject: AnyObject!, playingBackward:Bool) -> Void in
                    self.mainSkeleton.pauseAnimationForKey(fallingKey!)
                }
                
                jumpAnimation.animationEvents = [SCNAnimationEvent(keyTime: 0.25, block: leaveGroundBlock)]
                fallAnimation.animationEvents = [SCNAnimationEvent(keyTime: 0.5, block: pause)]
                
                // Animation sequence is to Jump -> Fall -> Land -> Idle
                self.chainAnimation(jumpKey!, secondKey: fallingKey!)
                self.chainAnimation(landKey!, secondKey: idleKey!)
        }
    }
    
    func setupBoredAnimation() {
        if let animation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/bored", key: AAPLPlayerCharacter.keyForAnimationType(.Bored)) {
            animation.repeatCount = FLT_MAX
        }
    }
    
    func setupHitAnimation() {
        if let animation = self.loadAndCacheAnimation("art.scnassets/characters/explorer/hit", key: AAPLPlayerCharacter.keyForAnimationType(.GetHit)) {
            animation.repeatCount = FLT_MAX
        }
    }
    
    // MARK: - 
    func playIdle(stop: Bool) {
        self.turnOffWalkingDust()
        if let anim = self.cachedAnimation(AAPLPlayerCharacter.keyForAnimationType(.Idle)) {
            anim.repeatCount = FLT_MAX
            anim.fadeInDuration = 0.1
            anim.fadeOutDuration = 0.1
            
            self.mainSkeleton.addAnimation(anim, forKey: AAPLPlayerCharacter.keyForAnimationType(.Idle))
        }
    }
    
    func playLand() {
        if let fallKey = AAPLPlayerCharacter.keyForAnimationType(.JumpFalling),
            key = AAPLPlayerCharacter.keyForAnimationType(.JumpLand),
            anim = self.cachedAnimation(key) {
                anim.timeOffset = 0.65
                self.mainSkeleton.removeAnimationForKey(fallKey, fadeOutDuration: 0.15)
        
                self.inJumpAnimation = false
                if (isWalking) {
                    // inRunAnimation = false
                    self.inRunAnimation = true
                } else {
                    self.mainSkeleton .addAnimation(anim, forKey: key)
                }
                AAPLGameSimulation.sim.playSound("Land.wav")
        }
    }
    
    override func update(deltaTime:NSTimeInterval) {
        var mtx: GLKMatrix4 = SCNMatrix4ToGLKMatrix4(self.transform)
        
        let gravity: GLKVector3 = GLKVector3Make(0,-90,0)
        let gravitystep: GLKVector3 = GLKVector3MultiplyScalar(gravity, Float(deltaTime))
        
        velocity = GLKVector3Add(velocity, gravitystep)
        
        let minMovement: GLKVector3 = GLKVector3Make(0, -50, 0)
        let maxMovement: GLKVector3 = GLKVector3Make(100, 100, 100)
        velocity = GLKVector3Maximum(velocity, minMovement)
        velocity = GLKVector3Minimum(velocity, maxMovement)
        
        mtx = GLKMatrix4TranslateWithVector3(mtx, velocity)
        groundPlaneHeight = self.getGroundHeight(mtx)
        
        if (CGFloat(mtx.m31) < groundPlaneHeight) {
            if (self.isLaunching == false && velocity.y < 0.0) {
                if (self.isJumping == true) {
                    self.isJumping = false
                    if (self.dustPoof != nil) {
                        self.addParticleSystem(self.dustPoof!)
                        self.dustPoof!.loops = false
                    }
                    self.playLand()
                    jumpBoost = 0.0
                }
            }

            // tie to ground
            // We can no longer set individual elements in the matrix,
            // so we will replace column 3 with new vector that has ty (m31) replaced with groundPlaneHeight
             // mtx.m31 = Float(groundPlaneHeight)
            let newTranslationVector4 = GLKVector4Make(Float(mtx.m30), Float(groundPlaneHeight), Float(mtx.m32), Float(mtx.m33))
            mtx = GLKMatrix4SetColumn(mtx, 3, newTranslationVector4)
           
            velocity = GLKVector3Make(velocity.x, 0.0, velocity.z)

        }
        self.transform = SCNMatrix4FromGLKMatrix4(mtx)
        
        // move the camera
        let camera: SCNNode?  = AAPLGameSimulation.sim.gameLevel.camera!.parentNode
        
        if (camera != nil) {
            // interpolate
            let pos: SCNVector3 = SCNVector3Make(self.position.x + ((self.walkDirection == .Right) ? 250 : -250),
                (self.position.y + 261) - (0.85 * (self.position.y - groundPlaneHeight)),
                (self.position.z + 1500))
            let desiredTransform: SCNMatrix4 = AAPLMatrix4SetPosition(camera!.transform, v: pos)
            camera!.transform = AAPLMatrix4Interpolate(camera!.transform, scnmf: desiredTransform, factor: 0.025)
        }
    }
    
    /*! Given our current location, shoot a ray downward to collide with our ground mesh or lava mesh
    */
    func getGroundHeight(mtx: GLKMatrix4) -> CGFloat {
        let start: SCNVector3 = SCNVector3Make(CGFloat(mtx.m30), CGFloat(mtx.m31 + 1000), CGFloat(mtx.m32))
        let end: SCNVector3 = SCNVector3Make(CGFloat(mtx.m30), CGFloat(mtx.m31 - 3000), CGFloat(mtx.m32))
        
        if let hits: [SCNHitTestResult] = AAPLGameSimulation.sim.physicsWorld.rayTestWithSegmentFromPoint(start,
            toPoint: end,
            options: [SCNPhysicsTestCollisionBitMaskKey : (GameCollisionCategory.Ground | GameCollisionCategory.Lava),
                SCNPhysicsTestSearchModeKey : SCNPhysicsTestSearchModeClosest]) {
                    
                    if (hits.count > 0) {
                        // take the first hit and make that the ground
                        for result: SCNHitTestResult in hits {
                            if (result.node.physicsBody!.categoryBitMask & ~(GameCollisionCategory.Ground | GameCollisionCategory.Lava) != 0) {
                                continue
                            }
                            return result.worldCoordinates.y
                        }
                    }
        }
        // 0 is ground if we didn't hit anything
        return 0
    }
    
    // MARK: -
    
    /*! Jump with variable heights based on how many times this method gets called
    */
    func performJumpAndStop(stop: Bool) {
        jumpForce = 13.0
        if (stop == true) {
            return
        }
        
        jumpBoost += 0.0005
        let maxBoost: CGFloat = self.walkSpeed * 2.0
        if (jumpBoost > maxBoost) {
            jumpBoost = maxBoost
        } else {
            //   velocity.y += 0.55
            velocity = GLKVector3Make(velocity.x, velocity.y + 0.55, velocity.z)
        }
        
        if (isJumping == false) {
            isJumping = true
            isLaunching = true
            inJumpAnimation = true
        }
    }
    
    func turnOffWalkingDust() {
        // Stop the flow ofdust by turning birthrate to 0
        // LEARN: contains is an undocumented Swift global function
        if let _dustWalking = self.dustWalking {
            if let _particleSystems = self.particleSystems
                where _particleSystems.contains(_dustWalking)  {
                    _dustWalking.birthRate = 0
            }
        }
    }
}