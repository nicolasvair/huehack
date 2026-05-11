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
    @AppStorage("hueOnboardingComplete") private var onboardingComplete = true

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
                Button("Relancer l'onboarding", role: .destructive) {
                    onboardingComplete = false
                }
            } footer: {
                Text("Réinitialise le flux de démarrage. La configuration sur le bridge reste intacte.")
                    .font(.caption)
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
