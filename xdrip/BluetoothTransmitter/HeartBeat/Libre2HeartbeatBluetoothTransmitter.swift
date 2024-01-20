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

/**
 Libre2HeartBeatBluetoothTransmitter is not a real CGMTransmitter but used as workaround to make clear in bluetoothperipheral manager that libreview is used as CGM
 */
class Libre2HeartBeatBluetoothTransmitter: BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    //private let CBUUID_Service_Libre2: String = "10CC" //"089810CC-EF89-11E9-81B4-2A2AE2DBCCE4"
    // private let CBUUID_Service_Libre2: String = "FDE3" (Libre 2)
    private let CBUUID_Service_Libre2: String = "1A7E4024-E3ED-4464-8B7E-751E03D0DC5F" // omnipod
    
    //private let CBUUID_Advertisement_Libre2: String? = nil
    private let CBUUID_Advertisement_Libre2: String? = "00004024-0000-1000-8000-00805f9b34fb" // omnipod

    /// receive characteristic - this is the characteristic for the one minute reading
    //private let CBUUID_ReceiveCharacteristic_Libre2: String = "0898177A-EF89-11E9-81B4-2A2AE2DBCCE4"
    // private let CBUUID_ReceiveCharacteristic_Libre2: String = "F002" (Libre 2)
    private let CBUUID_ReceiveCharacteristic_Libre2: String = "1A7E2442-E3ED-4464-8B7E-751E03D0DC5F" // omnipod
    
    /// write characteristic - we will not write, but the parent class needs a write characteristic, use the same as the one used for Libre 2
    private let CBUUID_WriteCharacteristic_Libre2: String = "F001"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHeartBeatOmnipod)
    
    /// is the transmitter oop web enabled or not, to be able to calibrate values received from Libre View
    private var webOOPEnabled: Bool
    
    /// when was the last heartbeat
    private var lastHeartBeatTimeStamp: Date

    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: should be the name of the libre 2 transmitter as seen in the iOS settings, doesn't need to be the full name, 3-5 characters should be ok
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    ///     - webOOPEnabled : enabled or not, if nil then default false
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, webOOPEnabled: Bool?) {

        // if it's a new device being scanned for, then use name ABBOTT. It will connect to anything that starts with name ABBOTT
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "BOARD")
        
        // if address not nil, then it's about connecting to a device that was already connected to before. We don't know the exact device name, so better to set it to nil. It will be assigned the real value during connection process
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: nil)
        }
        
        // initialize webOOPEnabled to false for heartbeat transmitter
        self.webOOPEnabled = false

        // initially last heartbeat was never (ie 1 1 1970)
        self.lastHeartBeatTimeStamp = Date(timeIntervalSince1970: 0)

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_Libre2, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Libre2)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre2, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre2, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: CBCentralManager overriden functions
    
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        super.centralManager(central, didConnect: peripheral)
        
        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(lastHeartBeatTimeStamp) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            
            bluetoothTransmitterDelegate?.heartBeat()
            
            lastHeartBeatTimeStamp = Date()
            
        }

    }
    

    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        //super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        // trace the received value and uuid
        if let value = characteristic.value {
            trace("in peripheralDidUpdateValueFor, characteristic = %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: characteristic.uuid), value.hexEncodedString())
        }

        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(lastHeartBeatTimeStamp) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            
            bluetoothTransmitterDelegate?.heartBeat()
            
            lastHeartBeatTimeStamp = Date()
            
        }
        
    }
    
    /*override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        trace("didDiscoverCharacteristicsFor for peripheral with name %{public}@, for service with uuid %{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre2, type: .info, deviceName ?? "'unknown'", String(describing:service.uuid))
        
        if let error = error {
            trace("    didDiscoverCharacteristicsFor error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                
                trace("    calling setnotifyvalue for characteristic: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: characteristic.uuid))
                
                peripheral.setNotifyValue(true, for: characteristic)
                
            }
        } else {
            trace("    Did discover characteristics, but no characteristics listed. There must be some error.", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
        }
    }*/
    

        
    // MARK: - conform to CGMTransmitter
    
    func cgmTransmitterType() -> CGMTransmitterType {
        
        // although uses for Libre2, should be ok to use Libre 2
        return .Libre2
        
    }
    
    func getCBUUID_Service() -> String {
        
        return CBUUID_Service_Libre2
        
    }
    
    func getCBUUID_Receive() -> String {
        
        return CBUUID_ReceiveCharacteristic_Libre2
        
    }

    func isWebOOPEnabled() -> Bool {
        return webOOPEnabled
    }
    

    func isNonFixedSlopeEnabled() -> Bool {
        return false
    }
    
    func maxSensorAgeInDays() -> Double? {
        
        return LibreSensorType.libre2.maxSensorAgeInDays()
        
    }
    
    /// set webOOPEnabled value
    func setWebOOPEnabled(enabled: Bool) {
        
        // for Libre2Heart beat transmitter we need to keep webOOPEnabled false
        webOOPEnabled = false
        
    }
    
    func overruleIsWebOOPEnabled() -> Bool {
        
        return true
        
    }
}
