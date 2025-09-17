//
//  DeviceDetailView.swift
//  BLEConnect
//
//  Created by Vikram Kumar on 17/09/25.
//

import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    let peripheral: CBPeripheral
    @EnvironmentObject var ble: BLEManager
    @Environment(\.dismiss) var dismiss
    @State private var message: String = "Hello from iOS"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 64))
                    .padding(.top, 24)

                Text(peripheral.name ?? "Unknown Device")
                    .font(.title2)
                    .bold()

                if ble.connectedPeripheral?.identifier == peripheral.identifier {
                    Text("Status: Connected")
                        .foregroundColor(.green)
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Received:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ble.receivedValue.isEmpty ? "(no data yet)" : ble.receivedValue)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).strokeBorder())
                    }
                    .padding(.top, 8)

                    TextField("Message to send", text: $message)
                        .textFieldStyle(.roundedBorder)
                        .padding(.top, 12)

                    HStack(spacing: 12) {
                        Button("Send") {
                            ble.write(message)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Disconnect") {
                            ble.disconnect()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)

                } else if ble.connectingPeripheralID == peripheral.identifier {
                    ProgressView()
                    Text("Connecting…")
                        .font(.subheadline)
                } else {
                    Text("Not connected")
                    Button("Connect") {
                        ble.connect(to: peripheral)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(peripheral.name ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
    }
}

