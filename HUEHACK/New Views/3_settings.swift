//
//  3_settings.swift
//  HUEHACK
//

import SwiftUI

struct __settings: View {

    @AppStorage("hueBridgeIP") private var bridgeIP = ""
    @AppStorage("usernameKey") private var storedUsername = ""
    @AppStorage("hueIndexGlobalOnOff") private var globalOnOffIndex = 0
    @AppStorage("hueIndexTimer") private var timerIndex = 0
    @AppStorage("hueOnboardingComplete") private var onboardingComplete = false

    @State private var showCleanConfirm = false
    @State private var cleanMessage = ""
    @State private var isCleaning = false

    var body: some View {
        Form {
            Section("Bridge") {
                LabeledContent("Adresse IP") {
                    TextField("192.168.1.x", text: $bridgeIP)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .onChange(of: bridgeIP) { _, v in AppConfig.shared.ip = v }
                }
                LabeledContent("Username") {
                    Text(storedUsername.isEmpty ? "—" : "…" + storedUsername.suffix(8))
                        .foregroundStyle(.secondary)
                        .font(.caption.monospaced())
                }
            }

            Section("Pièces & lumières") {
                NavigationLink("Gérer les pièces") {
                    __roomsManage()
                        .navigationTitle("Pièces")
                }
                NavigationLink("Gérer les lumières") {
                    __lightsManage()
                        .navigationTitle("Lumières")
                }
            }

            Section("Capteurs HUEHACK") {
                LabeledContent("Global on/off") {
                    Text("\(globalOnOffIndex > 0 ? globalOnOffIndex : 171)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Timer") {
                    Text("\(timerIndex > 0 ? timerIndex : 172)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) { showCleanConfirm = true } label: {
                    HStack {
                        Text("Supprimer les règles HUEHACK du bridge")
                        if isCleaning {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isCleaning)
                if !cleanMessage.isEmpty {
                    Text(cleanMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Supprime les règles et les capteurs virtuels HUEHACK, et oublie les réglages locaux (liens, offsets). Le reste du bridge — pièces, lampes, scènes, programmations — n'est pas touché. Relance ensuite l'onboarding pour repartir d'une config par défaut.")
                    .font(.caption)
            }

            Section {
                Button("Relancer l'onboarding", role: .destructive) {
                    // Swaps the app root to the welcome stack (this settings
                    // screen and the rooms stack under it go away).
                    withAnimation { onboardingComplete = false }
                }
            } footer: {
                Text("Réinitialise le flux de démarrage. La configuration sur le bridge reste intacte.")
                    .font(.caption)
            }
        }
        .alert("Supprimer HUEHACK du bridge ?", isPresented: $showCleanConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { cleanHUEHACK() }
        } message: {
            Text("Les règles et capteurs HUEHACK seront supprimés, ainsi que les liens et offsets enregistrés dans l'app. Irréversible.")
        }
    }

    private func cleanHUEHACK() {
        isCleaning = true
        cleanMessage = ""
        fetchBridgeConfig { _, json in
            guard let json else {
                isCleaning = false
                cleanMessage = "Bridge injoignable."
                return
            }
            wipeBridge(scope: .huehackOnly, config: json) { deleted, failed in
                clearLocalHUEHACKState()
                isCleaning = false
                cleanMessage = failed == 0
                    ? "\(deleted) élément(s) supprimé(s)."
                    : "\(deleted) supprimé(s), \(failed) échec(s)."
            }
        }
    }
}

#Preview {
    NavigationStack {
        __settings()
            .navigationTitle("Réglages")
    }
}
