//
//  0b_welcome.swift
//  HUEHACK
//

import SwiftUI

struct _b_welcome: View {

    @StateObject var discovery = HueBridgeDiscovery()
    @StateObject var pairingManager = BridgePairingManager()

    @AppStorage("hueBridgeIP") private var bridgeIP = ""
    @AppStorage("usernameKey") private var storedUsername = ""
    @State private var manualIP = ""

    /// Paired now, or already paired (onboarding relaunched from settings), or demo.
    private var canContinue: Bool {
        pairingManager.status == .success
            || (!bridgeIP.isEmpty && !storedUsername.isEmpty)
            || demoMode
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                Text("Assure-toi d'être sur le même réseau Wi-Fi que le bridge.")
                    .multilineTextAlignment(.center)
                    .padding()

                // Discovery
                HStack {
                    Button {
                        discovery.startDiscovery()
                    } label: {
                        Text("Trouver le bridge")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.blue)
                            .cornerRadius(12)
                    }

                    if discovery.status == .searching { ProgressView() }
                    else if discovery.status == .found { BoolToImg(value: true) }
                    else if discovery.status == .failed { BoolToImg(value: false) }
                }
                .frame(height: 44)

                // IP display / manual entry
                if !bridgeIP.isEmpty {
                    Text("IP : \(bridgeIP)")
                        .foregroundStyle(.secondary)
                        .font(.caption.monospaced())
                        .padding(.top, 6)
                } else {
                    HStack {
                        TextField("IP manuelle (192.168.1.x)", text: $manualIP)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Button("OK") {
                            bridgeIP = manualIP
                        }
                        .disabled(manualIP.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                }

                Spacer()

                Text("Appuie sur le bouton du bridge, puis appuie sur Associer.")
                    .multilineTextAlignment(.center)
                    .padding()

                // Pairing
                HStack {
                    Button {
                        pairingManager.pairWithBridge(ip: bridgeIP)
                    } label: {
                        Text("Associer")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(bridgeIP.isEmpty ? .gray : .blue)
                            .cornerRadius(12)
                    }
                    .disabled(bridgeIP.isEmpty)

                    if pairingManager.status == .inProgress { ProgressView() }
                    else if pairingManager.status == .success { BoolToImg(value: true) }
                    else if pairingManager.status == .error { BoolToImg(value: false) }
                }
                .frame(height: 44)

                Text(pairingManager.message)
                    .foregroundColor(pairingManager.status == .error ? .red : .green)
                    .font(.caption)
                    .padding(.top, 4)

                Spacer()
            }

            // Next — only active when paired
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    NavigationLink {
                        _c_welcome()
                            .navigationTitle("Config existante")
                    } label: {
                        Button_With_Icon(text: "next", icon: "arrowshape.right.circle", color: .fondClair)
                    }
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.35)
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack { _b_welcome() }
}
