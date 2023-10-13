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
    
    /// it's the bluetoothPeripheral as M5Stack
   /* private var libre2HeartBeat: Libre2HeartBeat? {
        get {
            return bluetoothPeripheral as? Libre2HeartBeat
        }
    }*/

    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
 //   private var bluetoothPeripheral: BluetoothPeripheral?

    /// reference to bluetoothPeripheralManager
  //  private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?

}

// MARK: - conform to BluetoothPeripheralViewModel

extension Libre2HeartBeatBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
      // there's nothing to configure
        
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
            
            cell.accessoryView = UISwitch(isOn: libre2HeartBeat.useLibreViewAsCGM, action: { (isOn:Bool) in
                
                libre2HeartBeat.useLibreViewAsCGM = isOn
                
            })
            
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
