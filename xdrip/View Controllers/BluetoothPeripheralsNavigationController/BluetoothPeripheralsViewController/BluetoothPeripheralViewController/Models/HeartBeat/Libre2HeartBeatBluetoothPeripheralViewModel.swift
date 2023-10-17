//
//  Libre2HeartBeatBluetoothPeripheralViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 05/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

class Libre2HeartBeatBluetoothPeripheralViewModel {
    
    /// settings specific for Libre heartbeat
    private enum Settings: Int, CaseIterable {
        
        /// in case LibreView as used to download readings
        case useLibreViewAsCGM = 0
        
    }
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?

}

// MARK: - conform to BluetoothPeripheralViewModel

extension Libre2HeartBeatBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.Libre3HeartBeatType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        
        // there's no section specific for this type of transmitter, this function will not be called
        return ""
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a Libre2HeartBeat
        guard let libre2HeartBeat = bluetoothPeripheral as? Libre2HeartBeat else {
            fatalError("Libre2HeartBeatBluetoothPeripheralViewModel update, bluetoothPeripheral is not Libre2HeartBeat")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("Libre2HeartBeatBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .useLibreViewAsCGM:
            
            cell.textLabel?.text = "use Libre View as CGM?"
            
            cell.detailTextLabel?.text = nil // it's a UISwitch,  no detailed text
            
            let uISwitch = UISwitch(isOn: libre2HeartBeat.useLibreViewAsCGM, action: { (isOn:Bool) in
                
                libre2HeartBeat.useLibreViewAsCGM = isOn

                if let libre2HeartBeatTransmitter = self.bluetoothPeripheralManager?.getBluetoothTransmitter(for: libre2HeartBeat, createANewOneIfNecesssary: false) {
                    
                    // disconnect and connect, this will force a call to diconnectto in bluetoothperipheralmanager
                    // needed to set the address of cgmtransmitteraddress
                    libre2HeartBeatTransmitter.disconnect()
                    libre2HeartBeatTransmitter.connect()
                    
                }
                
            })
            
            // if this this heartbeat transmitter is the actual cgm transmitter, or if there's no cgm transmitter configured yet, then it's allowed to set this heartbeat transmitter as cgm transmitter, ie uiswitch should be enabled
            if let cgmTransmitter = bluetoothPeripheralManager?.getCGMTransmitter() {
                if let heartbeat = cgmTransmitter as? Libre2HeartBeatBluetoothTransmitter {
                    if heartbeat.deviceAddress == bluetoothPeripheral.blePeripheral.address {
                        uISwitch.isEnabled = true
                    } else {
                        uISwitch.isEnabled = false
                    }
                } else {
                    // there's a cgm transmitter but it's not a heartbeat, so it's certainly not this transmitter
                    // not allowed to enable this heartbeat transmitter as cgm transmitter
                    uISwitch.isEnabled = false
                }
            } else {
                // there's no cgm transmitter yet, it's allowed to enable this HeartBeat transmitter as cgm transmitter
                uISwitch.isEnabled = true
            }
            
            cell.accessoryView = uISwitch
            
        }
        
    }
    
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // there's no section specific for this type of transmitter, so user won't click anything, this function will not be called
        return .nothing
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        
        // should only be called with section number 1
        if section == 1 {
            return 1
        } else {
            return 0
        }
        
    }
    
    func numberOfSections() -> Int {
        
        // one specific section
        return 1
        
    }
    
}
