//  DerriteApp.swift
//  Derrite
//  Created by Laura Money on 7/26/25.

import SwiftUI

@main
struct DerriteApp: App {
    @StateObject private var preferencesManager = PreferencesManager.shared

    init() {
        // Anonymous Safety Reporting App - maximum privacy mode
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferencesManager.isDarkMode ? .dark : .light)
        }
    }
}
