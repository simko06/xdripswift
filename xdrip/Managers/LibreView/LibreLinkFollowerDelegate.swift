//
//  LibreLinkFollowerDelegate.swift
//  xdrip
//
//  Created by Johan Degraeve on 11/09/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

protocol LibreLinkFollowerDelegate: AnyObject {
    
    /// to pass back follower data
    /// - parameters:
    ///     - followGlucoseDataArray : array of FollowGlucoseData, can be empty array, first entry is the youngest
    func libreLinkFollowerInfoReceived(followGlucoseDataArray:inout [GlucoseData], serialNumber: String?, sensorStart: Date?)

}
