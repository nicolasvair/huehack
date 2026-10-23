//
//  0e_welcome.swift
//  HUEHACK
//

import SwiftUI

struct _e_welcome: View {

    /// Rooms picked in 0d — carried through to the solar config step.
    var selectedRooms: [String] = []

    @State private var installStatus: InstallStatus = .idle
    @State private var message = ""

    enum InstallStatus { case idle, inProgress, success, failure }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Installation sur le bridge")
                    .font(.title2.bold())

                Text("HUEHACK crée deux capteurs virtuels sur le bridge pour piloter l'éclairage toutes les 10 secondes.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        installStatus = .inProgress
                        installHUEHACKSensors { ok, msg in
                            message = msg
                            installStatus = ok ? .success : .failure
                        }
                    } label: {
                        Button_With_Icon(
                            text: "Installer HUEHACK",
                            icon: "square.and.arrow.up",
                            color: .fondClair
                        )
                    }
                    .disabled(installStatus == .inProgress || installStatus == .success)

                    if installStatus == .inProgress { ProgressView() }
                    else if installStatus == .success { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    else if installStatus == .failure { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                }
                .frame(height: 44)

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(installStatus == .failure ? .red : .green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    NavigationLink {
                        _f_welcome(selectedRooms: selectedRooms)
                            .navigationTitle("Configuration solaire")
                    } label: {
                        Button_With_Icon(text: "next", icon: "arrowshape.right.circle", color: .fondClair)
                    }
                    .disabled(installStatus != .success && !demoMode)
                    .opacity(installStatus == .success || demoMode ? 1 : 0.35)
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack { _e_welcome() }
}
