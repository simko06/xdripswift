//
//  DexcomG7HeartBeatBluetoothPeripheralViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 05/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

class DexcomG7HeartBeatBluetoothPeripheralViewModel {
    
    private enum Settings: Int, CaseIterable {
        
        /// in case LibreView as used to download readings
        case useDexcomG7HeartBeatAsCGM = 0
        
    }
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?

}

// MARK: - conform to BluetoothPeripheralViewModel

extension DexcomG7HeartBeatBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.DexcomG7HeartBeatType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        
        // there's no section specific for this type of transmitter, this function will not be called
        return "Dexcom G7"
        
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a DexcomG7HeartBeat
        guard let dexcomG7HeartBeat = bluetoothPeripheral as? DexcomG7HeartBeat else {
            fatalError("DexcomG7HeartBeatBluetoothPeripheralViewModel update, bluetoothPeripheral is not DexcomG7HeartBeat")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG7HeartBeatBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .useDexcomG7HeartBeatAsCGM:
            
            cell.textLabel?.text = "use Dexcom G7 as CGM?"
            
            cell.detailTextLabel?.text = nil // it's a UISwitch,  no detailed text
            
            let uISwitch = UISwitch(isOn: dexcomG7HeartBeat.useDexcomG7HeartBeatAsCGM, action: { (isOn:Bool) in
                
                dexcomG7HeartBeat.useDexcomG7HeartBeatAsCGM = isOn

                if let dexcomG7HeartBeatTransmitter = self.bluetoothPeripheralManager?.getBluetoothTransmitter(for: dexcomG7HeartBeat, createANewOneIfNecesssary: false) {
                    
                    // disconnect and connect, this will force a call to diconnectto in bluetoothperipheralmanager
                    // needed to set the address of cgmtransmitteraddress
                    dexcomG7HeartBeatTransmitter.disconnect()
                    dexcomG7HeartBeatTransmitter.connect()
                    
                }
                
            })
            
            // if this this heartbeat transmitter is the actual cgm transmitter, or if there's no cgm transmitter configured yet, then it's allowed to set this heartbeat transmitter as cgm transmitter, ie uiswitch should be enabled
            if let cgmTransmitter = bluetoothPeripheralManager?.getCGMTransmitter() {
                if let heartbeat = cgmTransmitter as? DexcomG7HeartbeatBluetoothTransmitter {
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
        
        return Settings.allCases.count
        
    }
    
    func numberOfSections() -> Int {
        
        // one specific section
        return 1
        
    }
    
}
