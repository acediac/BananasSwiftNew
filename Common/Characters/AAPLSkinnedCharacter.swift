//
//  AAPLSkinnedCharacter.swift
//  BananasSwift
//
//  Created by Andrew on 24/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/* 
Abstract:

This class manages loading and running skeletal animations for a character in the game.

*/
import Foundation
import SceneKit

class AAPLSkinnedCharacter: SCNNode {
    // Dictionary used to look up the animation by key
    var animationsDict = [ String : CAAnimation ]()
    
    // main skeleton reference for faster look up
    var mainSkeleton: SCNNode!
    
    init(characterRootNode: SCNNode) {

        super.init()
        
        characterRootNode.position = SCNVector3Make(0, 0, 0)
        self.addChildNode(characterRootNode)
        
        // Find the first skeleton
        findAndSetSkeleton()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func findAndSetSkeleton() {
        self.enumerateChildNodesUsingBlock {
            (child: SCNNode!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            if let _skinner = child.skinner {
                self.mainSkeleton = _skinner.skeleton
                stop.memory = true // stop enumerating
            }
        }
        if (self.mainSkeleton == nil) {
            fatalError("Could not find main skeleton")
        }
    }
    
    func cachedAnimation(key:String?) -> CAAnimation? {
        if (key == nil) {return nil}
        return self.animationsDict[key!]
    }
    
    class func loadAnimationNamed(animationName:String, sceneName:String) -> CAAnimation? {
        // Load the DAE using SCNSceneSource in order to be able to retrieve the animation by its identifier
        let url: NSURL? = NSBundle.mainBundle().URLForResource(sceneName, withExtension: "dae")
        if (url == nil) {
            // Resource not found
            return nil
        }
        let sceneSource: SCNSceneSource? = SCNSceneSource(URL: url!, options: [SCNSceneSourceConvertToYUpKey : true])
        let animation: CAAnimation? = sceneSource?.entryWithIdentifier(animationName, withClass: CAAnimation.self)
        
        // Blend animatoins for smoother transitions
        animation?.fadeInDuration = CGFloat(0.3)
        animation?.fadeOutDuration = CGFloat(0.3)
        
        return animation
    }
    
    func loadAndCacheAnimation(daeFile: String, name:String?, key:String?) -> CAAnimation? {
        if (name == nil || key == nil) {return nil}
        if let _anim =  self.dynamicType.loadAnimationNamed(name!, sceneName: daeFile) {
            self.animationsDict[key!] = _anim
            _anim.delegate = self
            return _anim
        }
        return nil
    }
    
    func loadAndCacheAnimation(daeFile: String, key: String?) -> CAAnimation? {
        if (key == nil) { return nil }
        return self.loadAndCacheAnimation(daeFile, name: key, key: key)
    }
    
    func chainAnimation(firstKey:String, secondKey:String) {
        self.chainAnimation(firstKey, secondKey: secondKey, fadeTime: 0.85)
    }
    
    func chainAnimation(firstKey:String, secondKey:String, fadeTime:CGFloat) {

        
        guard   let firstAnim = self.cachedAnimation(firstKey),
                let secondAnim = self.cachedAnimation(secondKey) else {
            return
        }
        
        let chainEventBlock:SCNAnimationEventBlock = {
            (animation:CAAnimation!, animatedObject: AnyObject!, playingBackward: Bool) in
            self.mainSkeleton!.addAnimation(secondAnim, forKey: secondKey)
        }
        
        if (firstAnim.animationEvents == nil || firstAnim.animationEvents!.count == 0) {
            firstAnim.animationEvents = [SCNAnimationEvent(keyTime: fadeTime, block: chainEventBlock)]
        } else {
            firstAnim.animationEvents!.append(SCNAnimationEvent(keyTime: fadeTime, block: chainEventBlock))
        }
        
    }
    
    func update(deltaTime: NSTimeInterval) {
        // To be implemented by subclass
    }
}