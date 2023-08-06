//
//  Libre2HeartBeat+BluetoothPeripheral.swift
//  xdrip
//
//  Created by Johan Degraeve on 06/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import os
import CoreBluetooth
import AVFoundation

class Libre2HeartBeatBluetoothTransmitter: BluetoothTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    private let CBUUID_Service_Libre2: String = "10CC" //"089810CC-EF89-11E9-81B4-2A2AE2DBCCE4"
    
    /// receive characteristic - this is the characteristic for the one minute reading
    private let CBUUID_ReceiveCharacteristic_Libre2: String = "0898177A-EF89-11E9-81B4-2A2AE2DBCCE4" //"0898177A-EF89-11E9-81B4-2A2AE2DBCCE4"
    
    /// write characteristic - we will not write, but the parent class needs a write characteristic, use the same as the one used for Libre 2
    private let CBUUID_WriteCharacteristic_Libre2: String = "F001"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHeartBeatLibre2)
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: should be the name of the libre 2 transmitter as seen in the iOS settings, doesn't need to be the full name, 3-5 characters should be ok
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {

        // if it's a new device being scanned for, then use name ABBOTT. It will connect to anything that starts with name ABBOTT
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: transmitterID)
        
        // if address not nil, then it's about connecting to a device that was already connected to before. We don't know the exact device name, so better to set it to nil. It will be assigned the real value during connection process
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: nil)
        }
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Libre2)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre2, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre2, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - MARK: CBCentralManager overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        // this is the trigger for calling the heartbeat
        bluetoothTransmitterDelegate?.heartBeat()

    }
        
}
