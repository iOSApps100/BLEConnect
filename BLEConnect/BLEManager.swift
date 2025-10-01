//
//  BLEManager.swift
//  BLEConnect
//
//  Created by Vikram Kumar on 14/09/25.
//

import Foundation
import CoreBluetooth



class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var receivedValue: String = ""
    @Published var connectingPeripheralID: UUID?
    @Published var temperatureHistory: [TemperatureEntry] = []   // 🔥 NEW
    @Published var isBluetoothOn: Bool = false

    private var centralManager: CBCentralManager!
    private var targetCharacteristic: CBCharacteristic?
    
    let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    let characteristicUUID = CBUUID(string: "87654321-4321-6789-4321-0fedcba98765")
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Central state / scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothOn = true
            centralManager.scanForPeripherals(withServices: [serviceUUID])
            print("Bluetooth ON — Scanning…")
        default:
            isBluetoothOn = false
            centralManager.stopScan()
            devices.removeAll()
            print("Bluetooth not available")
        }
    }
    //for Temp Notification. changes
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        if central.state == .poweredOn {
//            print("Bluetooth ON — Scanning…")
//            centralManager.scanForPeripherals(withServices: [serviceUUID])
//        }
//    }

    func startScan() {
        guard isBluetoothOn else { return }
        centralManager.scanForPeripherals(withServices: nil,
                                         options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        centralManager.stopScan()
    }

    // MARK: - Discovery
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        if !devices.contains(peripheral) {
            devices.append(peripheral)
        }    }

    // MARK: - Connect / disconnect
    func connect(to peripheral: CBPeripheral) {
    centralManager.stopScan()
    connectedPeripheral = peripheral
    peripheral.delegate = self
    centralManager.connect(peripheral, options: nil)
}

    func disconnect() {
        guard let p = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectingPeripheralID = nil
        peripheral.discoverServices(nil)
        print("Connected to \(peripheral.name ?? "device")")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if connectingPeripheralID == peripheral.identifier { connectingPeripheralID = nil }
        print("Failed to connect: \(error?.localizedDescription ?? "unknown")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            targetCharacteristic = nil
            receivedValue = ""
        }
        print("Disconnected")
    }

    // MARK: - Peripheral callbacks
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
//        guard let services = peripheral.services else { return }
//        for service in services {
//            peripheral.discoverCharacteristics(nil, for: service)
//        }
//    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

//    func peripheral(_ peripheral: CBPeripheral,
//                    didDiscoverCharacteristicsFor service: CBService,
//                    error: Error?) {
//        guard let characteristics = service.characteristics else { return }
//
//        // Pick a readable/writable/notify characteristic if present.
//        for char in characteristics {
//            if char.properties.contains(.read) {
//                peripheral.readValue(for: char)
//            }
//            if char.properties.contains(.notify) {
//                peripheral.setNotifyValue(true, for: char)
//            }
//            // prefer write with response, fallback to writeWithoutResponse
//            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
//                // choose the first writable characteristic as target
//                if targetCharacteristic == nil {
//                    targetCharacteristic = char
//                }
//            }
//        }
//    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.properties.contains(.read) {
                peripheral.readValue(for: char)
            }
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)   // 🔔 subscribe
            }
            if char.properties.contains(.write) {
                targetCharacteristic = char
            }
        }
    }

//    func peripheral(_ peripheral: CBPeripheral,
//                    didUpdateValueFor characteristic: CBCharacteristic,
//                    error: Error?) {
//        guard let data = characteristic.value else { return }
//        // Try UTF-8 text, fallback to hex string
//        if let text = String(data: data, encoding: .utf8) {
//            DispatchQueue.main.async { self.receivedValue = text }
//            print("Received (utf8): \(text)")
//        } else {
//            let hex = data.map { String(format: "%02x", $0) }.joined()
//            DispatchQueue.main.async { self.receivedValue = hex }
//            print("Received (hex): \(hex)")
//        }
//    }

    func peripheral(_ peripheral: CBPeripheral,
                       didUpdateValueFor characteristic: CBCharacteristic,
                       error: Error?) {
           if let data = characteristic.value,
              let text = String(data: data, encoding: .utf8),
              let tempValue = Double(text) {
               DispatchQueue.main.async {
                   self.receivedValue = text
                   self.temperatureHistory.append(
                       TemperatureEntry(timestamp: Date(), value: tempValue)
                   )
                   print("Received: \(text)")
               }
           }
       }
    
    // MARK: - Write
    func write(_ text: String) {
        guard let peripheral = connectedPeripheral,
              let char = targetCharacteristic else { return }
        if let data = text.data(using: .utf8) {
            peripheral.writeValue(data, for: char, type: .withResponse)
        }
    }
}
/// Simple model for chart data
struct TemperatureEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}
