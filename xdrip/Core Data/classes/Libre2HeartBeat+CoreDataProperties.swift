//
//  Libre2HeartBeat+CoreDataProperties.swift
//  
//
//  Created by Johan Degraeve on 06/08/2023.
//
//

import Foundation
import CoreData


extension Libre2HeartBeat {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Libre2HeartBeat> {
        return NSFetchRequest<Libre2HeartBeat>(entityName: "Libre2HeartBeat")
    }

    @NSManaged public var blePeripheral: BLEPeripheral

    /// if true then LibreView is used to retrieve readings and considered as CGM. Because there's now bluetooth peripheral configured as CGM, we use these setting, which will then allow to set a cgm transmitter in the bluetooth peripheral manager
    @NSManaged public var useLibreViewAsCGM: Bool

}
