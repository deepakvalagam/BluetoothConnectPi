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
                        self.detailsLabel.text = "Writing to Rpi... Waiting for response"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: {
                            self.peripheral.readValue(for: self.readingCharacteristic)
                        })
                            
                    } else{
                        print("Password is not long enough")
                        self.detailsLabel.text = "Password is not long enough"
                    }
                    })
            } else{
                print("Bluetooth Error")
                self.detailsLabel.text = "Bluetooth Error"
            }
        }else{
            print("SSID is empty")
            self.detailsLabel.text = "SSID is empty"
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
            self.detailsLabel.text = "BT looking for RaspberryPi"
            //let CBCentralManagerScanOptionAllowDuplicatesKey: String = "true"
            centralManager.scanForPeripherals(withServices: [deviceUUID] , options:[CBCentralManagerScanOptionAllowDuplicatesKey : true])
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
        centralManager.stopScan()
        if peripheral == self.peripheral {
            print("BT Connected to RaspberryPi")
            self.detailsLabel.text = "BT Connected to RaspberryPi"
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
                print(characteristic.uuid)
                if characteristic.properties.contains(.writeWithoutResponse){
                    print(characteristic.properties)
                    if(characteristic.uuid == CBUUID.init(string: "ffffffff-ffff-ffff-ffff-fffffffffff4")){
                        self.writingCharacteristic = characteristic
                    }
                    
                }else if characteristic.properties.contains(.read){
                    print(characteristic.properties)
                    if(characteristic.uuid == CBUUID.init(string: "ffffffff-ffff-ffff-ffff-fffffffffff2")){
                        self.readingCharacteristic = characteristic
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                            self.peripheral.readValue(for: self.readingCharacteristic)
                        })
                    }
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
            self.detailsLabel.text = "RPi is connected to Wifi \nSSID : "+SSID+"\nIP:"+IP
            //self.centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager,didDisconnectPeripheral peripheral: CBPeripheral,error: Error?){
        print("Disconnected ",error ?? "NO ERROR")
        print("Central scanning");
        self.detailsLabel.text = "RPi disconnected. Scanning..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.centralManager.scanForPeripherals(withServices: [self.deviceUUID] , options:[CBCentralManagerScanOptionAllowDuplicatesKey : true])
        })
        
        
    }
    
}
