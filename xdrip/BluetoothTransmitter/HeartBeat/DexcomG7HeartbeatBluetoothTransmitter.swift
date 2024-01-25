//
//  DexcomG7HeartbeatBluetoothTransmitter.swift
//

import Foundation
import os
import CoreBluetooth
import AVFoundation

/**
 DexcomG7HeartbeatBluetoothTransmitter is not a real CGMTransmitter but used as workaround to make clear in bluetoothperipheral manager that libreview is used as CGM
 */
class DexcomG7HeartbeatBluetoothTransmitter: BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    private let CBUUID_Service_G7: String = "F8083532-849E-531C-C594-30F1F86A4EA5"
    
    private let CBUUID_Advertisement_G7: String? = "FEBC"

    /// receive characteristic - this is the characteristic for the one minute reading
    private let CBUUID_ReceiveCharacteristic_G7: String = "F8083535-849E-531C-C594-30F1F86A4EA5" // authentication characteristic
    
    private let CBUUID_WriteCharacteristic_G7: String = "F8083535-849E-531C-C594-30F1F86A4EA5"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHeartBeatG7BluetoothTransmitter)
    
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
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: transmitterID)
        
        // if address not nil, then it's about connecting to a device that was already connected to before. We don't know the exact device name, so better to set it to nil. It will be assigned the real value during connection process
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: nil)
        }
        
        // initialize webOOPEnabled to false for heartbeat transmitter
        self.webOOPEnabled = false

        // initially last heartbeat was never (ie 1 1 1970)
        self.lastHeartBeatTimeStamp = Date(timeIntervalSince1970: 0)

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G7, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G7)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_G7, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_G7, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: CBCentralManager overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        //super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        // trace the received value and uuid
        if let value = characteristic.value {
            trace("in peripheralDidUpdateValueFor, characteristic = %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryHeartBeatG7BluetoothTransmitter, type: .info, String(describing: characteristic.uuid), value.hexEncodedString())
        }

        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(lastHeartBeatTimeStamp) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            
            // sleep for a second to allow Loop to read the readings and store them in shared user defaults
            Thread.sleep(forTimeInterval: 1)

            self.bluetoothTransmitterDelegate?.heartBeat()

            lastHeartBeatTimeStamp = Date()

        }
        
    }
            
    // MARK: - conform to CGMTransmitter
    
    func cgmTransmitterType() -> CGMTransmitterType {
        
        return .Libre2
        
    }
    
    func getCBUUID_Service() -> String {
        
        return CBUUID_Service_G7
        
    }
    
    func getCBUUID_Receive() -> String {
        
        return CBUUID_ReceiveCharacteristic_G7
        
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
