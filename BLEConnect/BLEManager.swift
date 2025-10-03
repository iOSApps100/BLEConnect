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
        /*
         BLE can run when your app is in background (or even screen locked).
         To enable this:
         In Xcode > Signing & Capabilities > Background Modes:
         Enable ✅ Uses Bluetooth LE accessories.
         Your CBCentralManager must be created with a restore identifier:
         */
//        centralManager = CBCentralManager(delegate: self,
//                                           queue: nil,
//                                           options: [CBCentralManagerOptionRestoreIdentifierKey: "MyBLECentral"])

    }

    // MARK: - Central state / scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothOn = true
            centralManager.scanForPeripherals(withServices: [serviceUUID])
            print("Bluetooth ON — Scanning…")
        case .poweredOff:
            print("Bluetooth OFF")
        case .resetting:
            print("Bluetooth resetting…")
        case .unsupported:
            print("BLE unsupported on this device")
        case .unauthorized:
            print("BLE unauthorized (check permissions in Info.plist)")
        case .unknown:
            print("State unknown, waiting…")
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
        }
    }

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

        /*
         When your peripheral disconnects (out of range, power loss, or ESP32 reset), the central (iOS app) should:
         Detect the disconnection.
         Try reconnecting automatically after a small delay.
         
         
         What happens:
         If ESP32 disconnects, your app auto-reconnects without user action.
         On resume, it re-discovers services/characteristics and resumes notifications.
         */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown")")

        // Optional: Notify UI
        DispatchQueue.main.async {
            self.connectedPeripheral = nil
        }

        // Auto-reconnect after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            central.connect(peripheral, options: nil)
        }
    }
    /*
     This ensures:
     If your app is killed/restarted by iOS, it can resume BLE sessions.
     Notifications (like temperature updates) still arrive in background.
     */
    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String : Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            connectedPeripheral = peripherals.first
            connectedPeripheral?.delegate = self
            print("Restored peripheral: \(connectedPeripheral?.name ?? "Unknown")")
        }
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
/*
 What happens when Arduino sends "27"
 Arduino side
 String tempStr = String(27);
 pCharacteristic->setValue(tempStr.c_str());
 pCharacteristic->notify();
 tempStr.c_str() → "27\0" (ASCII characters "2", "7", plus a null terminator).
 Each character is just a byte:
 "2" → ASCII code 0x32 → decimal 50
 "7" → ASCII code 0x37 → decimal 55
 "\0" → ASCII code 0x00 → decimal 0
 What actually travels over BLE
 BLE does not know about strings — it only knows arrays of bytes.
 So "27\0" becomes:
 [0x32, 0x37, 0x00]
 Or in decimal: [50, 55, 0].
 iOS receives this in CoreBluetooth
 if let data = characteristic.value {
     print(data as NSData)
 }
 Output would be something like:
 <323700>
 (hex representation of bytes: 0x32, 0x37, 0x00)
 Decoding on iOS
 When you write:
 String(data: data, encoding: .utf8)
 iOS looks at those bytes:
 0x32 → "2"
 0x37 → "7"
 0x00 → null terminator (ignored in UTF-8 decoding)
 So you get "27" back as a Swift String.
 ✅ So that line means:
 BLE doesn’t send “27” as a number.
 It sends the raw bytes representing the characters "2", "7".
 Your iPhone reconstructs those bytes into the original string.
 👉 In short:
 "27" as text = [0x32, 0x37, 0x00]
 27 as raw integer = [0x1B]

 */
