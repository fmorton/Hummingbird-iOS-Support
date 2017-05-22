//
//  FlutterUtilities.swift
//  BirdBlox
//
//  Created by birdbrain on 4/3/17.
//  Copyright © 2017 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation

let SET = getUnicode("s")
let LED = getUnicode("l")
let SERVO = getUnicode("s")
let COMMA = getUnicode(",")
let READ = getUnicode("r")
let END: UInt8 = 0x0D

public func getFlutterServoCommand(_ port: UInt8, angle: UInt8) ->Data {
    let uniPort: UInt8 = getUnicode(port)
    let bounded_angle = bound(angle, min: 0, max: 180)
    let bytes = UnsafePointer<UInt8>([SET, SERVO, uniPort, COMMA, bounded_angle, END])
    return Data(bytes: bytes, count: 6)
}

public func getFlutterLedCommand(_ port: UInt8, r: UInt8, g: UInt8, b: UInt8) -> Data {
    let uniPort = getUnicode(port)
    let bounded_r = bound(r, min: 0, max: 100)
    let bounded_g = bound(g, min: 0, max: 100)
    let bounded_b = bound(b, min: 0, max: 100)
    let bytes = UnsafePointer<UInt8>([SET, LED, uniPort, COMMA, bounded_r, COMMA, bounded_g, COMMA, bounded_b, END])
    return Data(bytes: bytes, count: 10)
}

public func getFlutterRead() -> Data {
    let letter: UInt8 = getUnicode("r")
    let end: UInt8 = 0x0D
    return Data(bytes: UnsafePointer<UInt8>([letter, end] as [UInt8]), count: 2)
}

public func getFlutterResponseChar() -> UInt8 {
    return READ
}