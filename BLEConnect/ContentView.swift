//
//  ContentView.swift
//  BLEConnect
//
//  Created by Vikram Kumar on 14/09/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var ble = BLEManager()

    var body: some View {
        NavigationView {
            VStack {
                if let connected = ble.connectedPeripheral {
                    Text("Connected to \(connected.name ?? "ESP32")")
                        .font(.headline)
                    Text("Received: \(ble.receivedValue)")
                        .padding()

                    Button("Send Hello") {
                        ble.write("Hello from iOS")
                    }
                    .padding()
                } else {
                    List(ble.devices, id: \.identifier) { peripheral in
                        Button(peripheral.name ?? "Unknown") {
                            ble.connect(to: peripheral)
                        }
                    }
                }
            }
            .navigationTitle("BLE Demo")
        }
    }
}
