//
//  HUEHACKApp.swift
//  HUEHACK
//

import SwiftUI

@main
struct HUEHACKApp: App {
    let persistenceController = PersistenceController.shared

    @AppStorage("hueOnboardingComplete") private var onboardingComplete = false
    @AppStorage("hueBridgeIP") private var bridgeIP = ""
    @AppStorage("usernameKey") private var storedUsername = ""

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if onboardingComplete || (!bridgeIP.isEmpty && !storedUsername.isEmpty) {
                    __rooms()
                        .navigationTitle("HUEHACK")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink {
                                    __settings()
                                        .navigationTitle("Réglages")
                                } label: {
                                    Image(systemName: "gear")
                                }
                            }
                        }
                        .onAppear {
                            if !onboardingComplete { onboardingComplete = true }
                        }
                } else {
                    _a_welcome()
                        .navigationTitle("Bienvenue")
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
