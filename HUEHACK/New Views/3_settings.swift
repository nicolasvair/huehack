//
//  3_settings.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//

import SwiftUI

struct __settings: View {

    @AppStorage("hueBridgeIP") private var bridgeIP = ""
    @AppStorage("usernameKey") private var storedUsername = ""
    @State private var showResetAlert = false
    @State private var indexGlobalOnOffDisplay = 0
    @State private var indexTimerDisplay = 0

    var body: some View {
        List {
            Section("Bridge") {
                LabeledContent("IP", value: bridgeIP.isEmpty ? "—" : bridgeIP)

                HStack {
                    Text("Username")
                    Spacer()
                    Text(maskedUsername)
                        .foregroundStyle(.secondary)
                        .font(.caption.monospaced())
                }
            }

            Section("Capteurs virtuels") {
                LabeledContent("GLOBAL ONOFF", value: indexGlobalOnOffDisplay == 0 ? "—" : "\(indexGlobalOnOffDisplay)")
                LabeledContent("TIMER", value: indexTimerDisplay == 0 ? "—" : "\(indexTimerDisplay)")
            }

            Section {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Réinitialiser la configuration", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Paramètres")
        .onAppear {
            indexGlobalOnOffDisplay = AppConfig.shared.indexGlobalOnOff
            indexTimerDisplay = AppConfig.shared.indexTimer
        }
        .alert("Réinitialiser ?", isPresented: $showResetAlert) {
            Button("Réinitialiser", role: .destructive) {
                bridgeIP = ""
                storedUsername = ""
                AppConfig.shared.indexGlobalOnOff = 0
                AppConfig.shared.indexTimer = 0
                indexGlobalOnOffDisplay = 0
                indexTimerDisplay = 0
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("L'app retournera à l'écran d'accueil. Les règles sur le bridge ne seront pas supprimées.")
        }
    }

    private var maskedUsername: String {
        guard storedUsername.count > 8 else { return storedUsername.isEmpty ? "—" : storedUsername }
        return String(storedUsername.prefix(4)) + "••••••••" + String(storedUsername.suffix(4))
    }
}

#Preview {
    NavigationStack { __settings() }
}
