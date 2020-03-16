//
//  ViewController.swift
//  BluetoothConnectPi
//
//  Created by Deepak Valagam on 12/03/20.
//  Copyright © 2020 Deepak Valagam. All rights reserved.
//

import UIKit
import CoreBluetooth


class ViewController: UIViewController {
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    
    @IBOutlet weak var ssidField: UITextField!
    @IBOutlet weak var passkeyField: UITextField!
    @IBOutlet weak var detailsLabel: UILabel!
    
    var writingCharacteristic : CBCharacteristic!
    var readingCharacteristic : CBCharacteristic!
    let deviceUUID = CBUUID.init(string: "ffffffff-ffff-ffff-ffff-fffffffffff0")
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        ssidField.delegate = self
        passkeyField.delegate = self
        
    }

    @IBAction func sendPressed(_ sender: UIButton) {
        var input = ssidField.text
        if(input != ""){
            print("SSID ",input!)
            var data = Data(input!.utf8)
            if((peripheral) != nil && (writingCharacteristic != nil)){
                self.peripheral.writeValue(data, for: self.writingCharacteristic, type: .withoutResponse)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    input = self.passkeyField.text ?? "Empty"
                    if(input!.count >= 8){
                        data = Data(input!.utf8)
                        self.peripheral.writeValue(data, for: self.writingCharacteristic, type: .withoutResponse)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
                            self.peripheral.readValue(for: self.readingCharacteristic)
                        })
                            
                    } else{
                        print("Password is not long enough")
                    }
                    })
            } else{
                print("Bluetooth Error")
            }
        }else{
            print("SSID is empty")
        }
        
        
    }
    
}

extension ViewController:UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print(textField.text ?? "Empty")
        textField.resignFirstResponder()
        return true
    }
}

//BT management

extension ViewController: CBPeripheralDelegate, CBCentralManagerDelegate{
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central state update")
        if central.state != .poweredOn {
            print("Central is not powered on")
        } else {
            print("Central scanning");
            centralManager.scanForPeripherals(withServices: [deviceUUID] , options:nil)
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // We've found it so stop scan
        self.centralManager.stopScan()

        // Copy the peripheral instance
        self.peripheral = peripheral
        print(peripheral)
        self.peripheral.delegate = self

        // Connect!
        self.centralManager.connect(self.peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == self.peripheral {
            print("Connected to RaspberryPi")
            peripheral.discoverServices([deviceUUID])
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                print(service)
                peripheral.discoverCharacteristics(nil, for: service)
                
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.properties.contains(.writeWithoutResponse){
                    print(characteristic.properties)
                    self.writingCharacteristic = characteristic
                }else if characteristic.properties.contains(.read){
                    print(characteristic.properties)
                    self.readingCharacteristic = characteristic
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                        self.peripheral.readValue(for: self.readingCharacteristic)
                    })
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let details = String.init(data:characteristic.value ?? Data("EMPTY".utf8), encoding: .utf8)
        print(details ?? "EMPTY")
        if let detail = details{
            let SSID = detail.split(separator: ",")[0]
            let IP = detail.split(separator: ",")[1]
            print("SSID : ",SSID,"\nIP:",IP)
            self.detailsLabel.text = "SSID : "+SSID+"\nIP:"+IP
        }
    }
    
    func centralManager(_ central: CBCentralManager,didDisconnectPeripheral peripheral: CBPeripheral,error: Error?){
        print("Disconnected ",error ?? "NO ERROR")
        print("Central scanning");
        centralManager.scanForPeripherals(withServices: [deviceUUID] , options:nil)
        
    }
    
}
