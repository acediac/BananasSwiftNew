//
//  AAPLMathUtils.swift
//  BananasSwift
//
//  Created by Andrew on 25/04/2015.
//  Copyright (c) 2015 Machina Venefici. All rights reserved.
//

import Foundation
import SceneKit



/*

GLKMatrix4 Notes
Consists of elements m00 .. m33
Elements are ordered by [COLUMN, ROW]

m00...m03 are the [0,0] ... [0,3] elements of the matrix (0th column)
m10...m13 are the [1,0] ... [1,3] elements of the matrix
m20...m23 are the [2,0] ... [2,3] elements of the matrix
m30 is the [3,0] element and represents the x coordinate's translation value (tx)
m31 is the [3,0] element and represents the y coordinate's translation value (ty)
m32 is the [3,0] element and represents the z coordinate's translation value (tz)
m33 is the [3,3] element (w component?)

m is the one dimensional array of the matrix's element.
tx, ty, tz are the 12, 13, and 14 indices of m
Or in other words the last (3rd) component (column) of rows 0...2



*/

func AAPLMatrix4GetPosition(matrix: SCNMatrix4) -> SCNVector3 {
    return SCNVector3(x:  matrix.m41, y: matrix.m42, z: matrix.m43)
}

func AAPLMatrix4SetPosition(matrix: SCNMatrix4, v: SCNVector3) -> SCNMatrix4{
    var newMatrix = matrix
    newMatrix.m41 = v.x
    newMatrix.m42 = v.y
    newMatrix.m43 = v.z
    return newMatrix
}

func AAPLRandomPercent() -> CGFloat {
    return CGFloat(Float((rand() % 100)) * 0.01)
}

func AAPLMatrix4Interpolate(scnm0: SCNMatrix4, scnmf: SCNMatrix4, factor: CGFloat) -> SCNMatrix4 {
    let m0: GLKMatrix4 = SCNMatrix4ToGLKMatrix4(scnm0)
    let mf: GLKMatrix4 = SCNMatrix4ToGLKMatrix4(scnmf)
    let p0: GLKVector4 = GLKMatrix4GetColumn(m0, 3)
    let pf: GLKVector4 = GLKMatrix4GetColumn(mf, 3)
    let q0: GLKQuaternion = GLKQuaternionMakeWithMatrix4(m0)
    let qf: GLKQuaternion = GLKQuaternionMakeWithMatrix4(mf)
    
    let pTmp: GLKVector4 = GLKVector4Lerp(p0, pf, Float(factor))
    let qTmp: GLKQuaternion = GLKQuaternionSlerp(q0, qf, Float(factor))
    let rTmp: GLKMatrix4 = GLKMatrix4MakeWithQuaternion(qTmp)
    
    let transform = CATransform3D(
        m11: CGFloat(rTmp.m00), m12: CGFloat(rTmp.m01), m13: CGFloat(rTmp.m02), m14: CGFloat(0.0),
        m21: CGFloat(rTmp.m10), m22: CGFloat(rTmp.m11), m23: CGFloat(rTmp.m12), m24: CGFloat(0.0),
        m31: CGFloat(rTmp.m20), m32: CGFloat(rTmp.m21), m33: CGFloat(rTmp.m22), m34: CGFloat(0.0),
        m41: CGFloat(pTmp.x), m42: CGFloat(pTmp.y), m43: CGFloat(pTmp.z), m44: CGFloat(1.0))
    return transform
}

func catmullRomValue(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, dist: CGFloat) ->  CGFloat {
    return ((((-a + 3.0 * b - 3.0 * c + d) * (dist * dist * dist)) +
        ((2.0 * a - 5.0 * b + 4.0 * c - d) * (dist * dist)) +
        ((-a + c) * dist) +
        (2.0 * b)) * 0.5)
}