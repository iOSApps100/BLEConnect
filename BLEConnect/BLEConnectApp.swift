//
//  BLEConnectApp.swift
//  BLEConnect
//
//  Created by Vikram Kumar on 14/09/25.
//

import SwiftUI

@main
struct BLEConnectApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(BLEManager())
        }
    }
}
