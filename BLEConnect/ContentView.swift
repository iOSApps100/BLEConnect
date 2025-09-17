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
    @State private var selectedPeripheralID: UUID?

    var body: some View {
        NavigationView {
            List {
                Section {
                    if !ble.isBluetoothOn {
                        HStack {
                            Image(systemName: "bolt.slash.fill")
                            Text("Bluetooth is off")
                            Spacer()
                            Button("Retry") { ble.startScan() }
                        }
                    } else if ble.devices.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Scanning…")
                            Spacer()
                        }
                    } else {
                        ForEach(ble.devices, id: \.identifier) { peripheral in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Unknown")
                                        .font(.headline)
                                    Text(peripheral.identifier.uuidString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: {
                                    // start connection and navigate
                                    ble.connect(to: peripheral)
                                    selectedPeripheralID = peripheral.identifier
                                }) {
                                    if ble.connectingPeripheralID == peripheral.identifier {
                                        ProgressView()
                                            .frame(width: 80)
                                    } else {
                                        Text("Connect")
                                            .frame(minWidth: 80)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(ble.connectingPeripheralID == peripheral.identifier)
                            }
                            .padding(.vertical, 8)
                            // hidden NavigationLink that triggers when selectedPeripheralID is set
                            .background(
                                NavigationLink(destination: DeviceDetailView(peripheral: peripheral).environmentObject(ble),
                                               tag: peripheral.identifier,
                                               selection: $selectedPeripheralID) {
                                    EmptyView()
                                }
                                .hidden()
                            )
                        }
                    }
                } header: {
                    Text("Available Devices")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("BLE Demo")
        }
    }
}
