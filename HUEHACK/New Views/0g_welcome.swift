//
//  0g_welcome.swift
//  HUEHACK
//
//  Last onboarding step: offer to link the freshly configured rooms together.
//  Linked rooms share one schedule — updating any of them updates them all.
//

import SwiftUI

struct _g_welcome: View {

    /// Rooms that just received the default config in 0f.
    var configuredRooms: [String] = []

    @AppStorage("hueOnboardingComplete") private var onboardingComplete = false

    @State private var groups = [String: RoomResponse]()
    @State private var linkedIndices = Set<String>()
    @State private var isLoading = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lier les pièces entre elles ?")
                        .font(.title3.bold())
                    Text("Les pièces liées partagent le même planning : mettre l'une à jour met les autres à jour. Décoche celles qui doivent rester indépendantes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if configuredRooms.isEmpty {
                    Text("Aucune pièce configurée.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(configuredRooms, id: \.self) { idx in
                            Button {
                                if linkedIndices.contains(idx) {
                                    linkedIndices.remove(idx)
                                } else {
                                    linkedIndices.insert(idx)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: linkedIndices.contains(idx) ? "link.circle.fill" : "circle")
                                        .foregroundStyle(linkedIndices.contains(idx) ? .blue : .secondary)
                                    Text(groups[idx]?.name ?? idx)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { finish() } label: {
                        Button_With_Icon(text: "done !", icon: "checkmark.circle", color: .fondClair)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // All rooms share the same default config at this point, so linking
            // them all is the sensible starting point.
            linkedIndices = Set(configuredRooms)
            if demoMode {
                groups = demoGroups
                return
            }
            isLoading = true
            sendGETGroups(ip: ip, which: nil) { response in
                groups = response
                isLoading = false
            }
        }
    }

    private var summary: String {
        switch linkedIndices.count {
        case 0, 1: return "Aucun lien créé — chaque pièce garde son propre planning."
        default:   return "\(linkedIndices.count) pièces liées. Modifiable à tout moment depuis l'icône 🔗 d'une pièce."
        }
    }

    private func finish() {
        let toLink = sortedIndices(linkedIndices)
        if let first = toLink.first {
            for other in toLink.dropFirst() {
                linkRooms(first, other)
            }
        }
        // Button action → main thread. Flipping the flag swaps the app root to
        // __rooms(), dropping the whole welcome stack.
        withAnimation { onboardingComplete = true }
    }
}

#Preview {
    NavigationStack { _g_welcome(configuredRooms: ["1", "2", "3"]) }
}
