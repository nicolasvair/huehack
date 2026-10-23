//
//  HUEHACKApp.swift
//  HUEHACK
//

import SwiftUI

@main
struct HUEHACKApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // One-shot migration: installs made before this flag existed skip onboarding.
        // Marked as done so "Relancer l'onboarding" is not undone at the next launch.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hueOnboardingMigrated") {
            defaults.set(true, forKey: "hueOnboardingMigrated")
            if !(defaults.string(forKey: "hueBridgeIP") ?? "").isEmpty,
               !(defaults.string(forKey: "usernameKey") ?? "").isEmpty {
                defaults.set(true, forKey: "hueOnboardingComplete")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

/// Routes on the onboarding flag. Lives in a View rather than in the App so the
/// flag flip (set by the last onboarding step, or by "Relancer l'onboarding")
/// reliably swaps the whole root: App-level state does not always re-render
/// the WindowGroup content.
struct RootView: View {

    @AppStorage("hueOnboardingComplete") private var onboardingComplete = false

    var body: some View {
        Group {
            if onboardingComplete {
                // A stack of its own, so finishing onboarding lands here
                // instead of leaving the welcome screens pushed on top.
                NavigationStack {
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
                }
                .transition(.opacity)
            } else {
                NavigationStack {
                    _a_welcome()
                        .navigationTitle("Bienvenue")
                }
                .transition(.opacity)
            }
        }
    }
}
