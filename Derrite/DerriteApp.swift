//
//  DerriteApp.swift
//  Derrite
//
//  Created by Laura Money on 7/26/25.
//

import SwiftUI

@main
struct DerriteApp: App {
    init() {
        print("🚀 Derrite: Anonymous Safety Reporting App")
        print("ℹ️  Firebase messaging is disabled by design for maximum privacy")
        print("📱 App will work completely offline with local notifications only")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
