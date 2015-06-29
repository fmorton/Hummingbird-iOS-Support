//
//  BluetoothService.swift
//  HummingbirdLibrary
//
//  Created by birdbrain on 5/27/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth
/**the uuid of the uart service of the BLE device*/
let BLEServiceUUID      = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
/**The uuid if the TX characteristic which is used for sending messages to the hummingbird*/
let BLEServiceUUIDTX    = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
/**The uuid if the RX characteristic which is used for getting messages from the hummingbird*/
let BLEServiceUUIDRX    = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
let BLEServiceChangedStatusNotification = "kBLEServiceChangedStatusNotification"

/**
    :Class: BluetoothService

    :Description: This class is used to manage a bluetooth LE device. It allows for sending and
    receiving messages to and from the device
*/
class BluetoothService: NSObject, CBPeripheralDelegate{
    var peripheralBLE: CBPeripheral?
    var txCharacteristic: CBCharacteristic?
    var rxCharacteristic: CBCharacteristic?
    var receivedData: NSData
    init(initWithPeripheral peripheral : CBPeripheral){
        receivedData = NSData(bytes: [0,0,0,0,0] as [UInt8],length: 5)
        super.init()
        self.peripheralBLE = peripheral
        self.peripheralBLE?.delegate = self
    }
    
    deinit{
        self.reset()
    }
    /**
        This function begins the search for services (it searches for all services but it only needs the uart service)
    */
    func startDiscoveringServices(){
        dbg_print("discovering services for: " + peripheralBLE!.description)
        //self.peripheralBLE?.discoverServices([BLEServiceUUID])
        peripheralBLE?.discoverServices(nil)
        dbg_print("done discovering")
    }
    
    /**
        This resets our BLE device
    */
    func reset(){
        if peripheralBLE != nil{
            peripheralBLE = nil
        }
        self.sendBTServiceNotification(false)
    }
    /**
        :Additional Information: When a services are discovered, we find the uart service and begin looking for characteristics
    */
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        dbg_print("discovered services")
        let neededUUIDs: [CBUUID] = [BLEServiceUUIDRX,BLEServiceUUIDTX]
        
        if (peripheral != peripheralBLE){
            dbg_print("not right peripheral")
            return
        }
        if(error != nil){
            dbg_print("error in discover service")
            return
        }
        dbg_print("parsing through services")
        if let services = peripheral.services{
            for service in services {
                if(service.UUID == BLEServiceUUID){
                    dbg_print("discovering characteristics")
                    peripheral.discoverCharacteristics(neededUUIDs, forService: service as! CBService)
                }
            }
        }
    }
    /**
    :Additional Information: When a characteristics are discovered, we find the tx and rx characteristic
    */
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if (peripheral != peripheralBLE){
            return
        }
        if(error != nil){
            return
        }
        var wasTXSet = false
        var wasRXSet = false
        if let characteristics = service.characteristics{
            for characteristic in characteristics {
                let CBchar = characteristic as! CBCharacteristic
                dbg_print("Found characteristic of uuid" + CBchar.UUID.UUIDString)
                if(characteristic.UUID == BLEServiceUUIDTX){
                    self.txCharacteristic = (characteristic as! CBCharacteristic)
                    peripheral.setNotifyValue(true, forCharacteristic: characteristic as! CBCharacteristic)
                    wasTXSet = true
                }
                else if(characteristic.UUID == BLEServiceUUIDRX){
                    self.rxCharacteristic = (characteristic as! CBCharacteristic)
                    peripheral.setNotifyValue(true, forCharacteristic: characteristic as! CBCharacteristic)
                    wasRXSet = true
                }
                if(wasTXSet && wasRXSet){
                    dbg_print("tx and rx characteristics were set")
                    self.sendBTServiceNotification(true)
                }
            }
        }
    }
    var lastMessageSent:NSData = NSData()
    
    /**
        :Additional Information: used to keep track of rx
    */
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if(characteristic.UUID != BLEServiceUUIDRX){
            return
        }
        if(characteristic.value!.length % 5 != 0){
            return
        }
        let dataString = NSString(format: "rx value: %@", characteristic.value!)
        dbg_print(dataString)
        
        var temp: [UInt8] = [0,0,0,0]
        characteristic.value!.getBytes(&temp,length: 4)
        var oldData: [UInt8] = [0,0,0,0]
        receivedData.getBytes(&oldData, length: 4)
        //if (temp[0] == 0x47 && temp[1] == 0x33 && (temp[2] != 0x47 || temp[3] != 0x33)){//sensor data
            oldData[0] = temp[0]
            oldData[1] = temp[1]
            oldData[2] = temp[2]
            oldData[3] = temp[3]
        //}
        objc_sync_enter(self)
        receivedData = NSData(bytes: oldData, length: 4)
        objc_sync_exit(self)
        dbg_print(NSString(format: "stored data: %@", receivedData))
    }
    
    /**
        This sets the TX characteristic to a certain value
    
        :param: message The value to set TX to
    */
    func setTX(message : NSData){
        //dbg_print("setTX called")
        if (self.txCharacteristic == nil){
            dbg_print("tx is not avaliable")
            return
        }
        if(message.isEqualToData (lastMessageSent) && !(message.isEqualToData(getPollSensorsCommand()))){
            dbg_print("ignoring repeat message")
            return
        }
        dbg_print(NSString(format: "sending message %@", message))
        peripheralBLE?.writeValue(message, forCharacteristic: self.txCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
        lastMessageSent = message
        dbg_print("sent message")
    }
    /**
        Gets the latest value of RX
        
        :returns: NSData The latest value for RX
    */
    func getValues() -> NSData{
        objc_sync_enter(self)
        let ret = NSData(data: receivedData)
        objc_sync_exit(self)
        return ret
    }
    /**
        Sends a notification to indicate a device is connected ot disconnected
    */
    func sendBTServiceNotification(isConnected: Bool){
        let connectionDetails = ["isConnected" : isConnected]
        NSNotificationCenter.defaultCenter().postNotificationName(BLEServiceChangedStatusNotification, object: self, userInfo: connectionDetails)
    }
    
    
}