//
//  HUEHACKApp.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import SwiftUI

@main
struct HUEHACKApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

private struct RootView: View {
    @AppStorage("hueBridgeIP") private var bridgeIP = ""
    @AppStorage("usernameKey") private var storedUsername = ""

    var body: some View {
        NavigationStack {
            if !bridgeIP.isEmpty && !storedUsername.isEmpty {
                SetHoursView()
            } else {
                _a_welcome()
            }
        }
    }
}
