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
    @Published var isBluetoothOn: Bool = false

    private var centralManager: CBCentralManager!
    private var targetCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Central state / scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothOn = true
            centralManager.scanForPeripherals(withServices: nil,
                                             options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            print("Bluetooth ON — Scanning…")
        default:
            isBluetoothOn = false
            centralManager.stopScan()
            devices.removeAll()
            print("Bluetooth not available")
        }
    }

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
        // Keep unique by identifier (CBPeripheral equality is not reliable for lists)
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            devices.append(peripheral)
        }
    }

    // MARK: - Connect / disconnect
    func connect(to peripheral: CBPeripheral) {
        connectingPeripheralID = peripheral.identifier
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
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }

        // Pick a readable/writable/notify characteristic if present.
        for char in characteristics {
            if char.properties.contains(.read) {
                peripheral.readValue(for: char)
            }
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
            }
            // prefer write with response, fallback to writeWithoutResponse
            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                // choose the first writable characteristic as target
                if targetCharacteristic == nil {
                    targetCharacteristic = char
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        // Try UTF-8 text, fallback to hex string
        if let text = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async { self.receivedValue = text }
            print("Received (utf8): \(text)")
        } else {
            let hex = data.map { String(format: "%02x", $0) }.joined()
            DispatchQueue.main.async { self.receivedValue = hex }
            print("Received (hex): \(hex)")
        }
    }

    // MARK: - Write
    func write(_ text: String) {
        guard let peripheral = connectedPeripheral,
              let char = targetCharacteristic,
              let data = text.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: char, type: .withResponse)
    }
}
