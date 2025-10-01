//
//  ContentView.swift
//  BLEConnect
//
//  Created by Vikram Kumar on 14/09/25.
//
import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject var ble = BLEManager()

    var body: some View {
        NavigationView {
            VStack {
                if let connected = ble.connectedPeripheral {
                    NavigationLink(destination: DeviceDetailView(ble: ble, deviceName: connected.name ?? "ESP32")) {
                        Text("Open Device Dashboard")
                            .font(.headline)
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(12)
                    }
                } else {
                    List(ble.devices, id: \.identifier) { peripheral in
                        HStack {
                            Text(peripheral.name ?? "Unknown")
                            Spacer()
                            Button("Connect") {
                                ble.connect(to: peripheral)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("BLE Devices")
        }
    }
}
