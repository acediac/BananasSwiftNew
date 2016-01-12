//
//  AAPLCoconut.swift
//  BananasSwift
//
//  Created by Andrew on 3/05/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//
/*

Abstract:

This class manages the coconuts thrown by monkeys in the game. It configures and vends instances for use by the AAPLMonkeyCharacter class, which uses them both for simple animation (the monkey retrieving a coconut from the tree) and physics simulation (the monkey throwing a coconut at the player).

*/

import Foundation
import SceneKit

class AAPLCoconut: SCNNode {
    
    static private var _coconutProtoObject: SCNNode?
    static var coconutProtoObject: SCNNode {

        if (self._coconutProtoObject == nil) {
            let coconutDaeName = AAPLGameSimulation.pathForArtResource("characters/monkey/coconut.dae")
            self._coconutProtoObject =
                AAPLGameSimulation.loadNodeWithName("Coconut", fromSceneNamed: coconutDaeName)!
        }
        // create and return clone of proto object
        let coconut = self._coconutProtoObject!.clone() 
        coconut.name = "coconut"
        return coconut
    }
    
    static private var _coconutThrowProtoObject: AAPLCoconut?
    static var coconutThrowProtoObject: AAPLCoconut {
        
        if (self._coconutThrowProtoObject == nil) {
            let coconutDaeName = AAPLGameSimulation.pathForArtResource("characters/monkey/coconut_no_translation.dae")
            let throwProtoObject: AAPLCoconut = AAPLCoconut()
            if let node = AAPLGameSimulation.loadNodeWithName("coconut", fromSceneNamed: coconutDaeName) {
                throwProtoObject.addChildNode(node)
                throwProtoObject.enumerateChildNodesUsingBlock({
                    (child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    if let _geometry = child.geometry {
                        for m: SCNMaterial in _geometry.materials {
                            m.lightingModelName = SCNLightingModelConstant
                        }
                    }
                })
            }
            self._coconutThrowProtoObject = throwProtoObject
        }
        // create and return clone of proto object
        let coconut = self._coconutThrowProtoObject!.clone() 
        coconut.name = "coconut_throw"
        return coconut
    }
    
    static let coconutPhysicsShape = SCNPhysicsShape(geometry: SCNSphere(radius: 25), options: nil)
    
}