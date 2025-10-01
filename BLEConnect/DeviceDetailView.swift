//
//  DeviceDetailView.swift
//  BLEConnect
//
//  Created by Vikram Kumar on 17/09/25.
//

//import CoreBluetooth
import SwiftUI
import Charts   // iOS 16+

struct DeviceDetailView: View {
    @ObservedObject var ble: BLEManager
    let deviceName: String

    var body: some View {
        VStack {
            Text("Connected to \(deviceName)")
                .font(.headline)
                .padding(.top)

            Text("Latest Temp: \(ble.receivedValue)°C")
                .font(.title2)
                .padding()

            if !ble.temperatureHistory.isEmpty {
                Chart(ble.temperatureHistory) { entry in
                    LineMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Temp", entry.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                }
                .frame(height: 250)
                .padding()
            } else {
                Text("Waiting for data...")
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer()
        }
        .navigationTitle("Temperature Dashboard")
    }
}
