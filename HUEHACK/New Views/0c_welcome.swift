//
//  0c_welcome.swift
//  HUEHACK
//
//  Right after pairing: shows what already lives on the bridge and lets the
//  user keep it, clean up HUEHACK's own leftovers, or start from scratch —
//  with a JSON export beforehand.
//

import SwiftUI

struct _c_welcome: View {

    @State private var inventory: BridgeInventory? = nil
    @State private var rawConfig: [String: Any]? = nil
    @State private var backupURL: URL? = nil

    @State private var isLoading = false
    @State private var wipeProgress: (done: Int, total: Int)? = nil
    @State private var message = ""
    @State private var isError = false
    @State private var pendingWipe: WipeScope? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Lecture du bridge…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let inv = inventory {
                        inventoryCard(inv)
                        backupSection
                        choicesSection(inv)
                    } else {
                        Text("Impossible de lire la configuration du bridge.")
                            .foregroundStyle(.secondary)
                        Button("Réessayer") { loadConfig() }
                    }

                    if let progress = wipeProgress {
                        ProgressView(value: Double(progress.done), total: Double(max(1, progress.total))) {
                            Text("Suppression \(progress.done)/\(progress.total)")
                                .font(.caption)
                        }
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(isError ? .red : .green)
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    NavigationLink {
                        _d_welcome()
                            .navigationTitle("Pièces")
                    } label: {
                        Button_With_Icon(text: "next", icon: "arrowshape.right.circle", color: .fondClair)
                    }
                    .disabled(isLoading || wipeProgress != nil)
                    .opacity(isLoading || wipeProgress != nil ? 0.35 : 1)
                }
            }
            .padding()
        }
        .onAppear { if inventory == nil { loadConfig() } }
        .alert("Tout supprimer ?", isPresented: Binding(
            get: { pendingWipe != nil },
            set: { if !$0 { pendingWipe = nil } }
        )) {
            Button("Annuler", role: .cancel) { pendingWipe = nil }
            Button("Supprimer", role: .destructive) {
                if let scope = pendingWipe { runWipe(scope) }
                pendingWipe = nil
            }
        } message: {
            Text("Règles, programmations, scènes, resourcelinks et capteurs virtuels seront supprimés du bridge. Les pièces, les lampes et les interrupteurs physiques sont conservés. C'est irréversible.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func inventoryCard(_ inv: BridgeInventory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Il y a déjà des choses sur ce bridge")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 4) {
                line("Pièces", inv.groups, keep: true)
                line("Lampes", inv.lights, keep: true)
                line("Règles", inv.rules, detail: inv.huehackRules > 0 ? "dont \(inv.huehackRules) HUEHACK" : nil)
                line("Programmations", inv.schedules)
                line("Scènes", inv.scenes)
                line("Capteurs virtuels", inv.clipSensors, detail: inv.huehackSensors > 0 ? "dont \(inv.huehackSensors) HUEHACK" : nil)
                line("Capteurs physiques", inv.physicalSensors, keep: true)
                line("Resourcelinks", inv.resourcelinks)
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func line(_ label: String, _ count: Int, detail: String? = nil, keep: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .fontWeight(.semibold)
                .frame(minWidth: 28, alignment: .trailing)
            Text(label)
            if let detail {
                Text("(\(detail))").foregroundStyle(.secondary)
            }
            if keep {
                Image(systemName: "lock").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button { makeBackup() } label: {
                    Label("Sauvegarder la config", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                if let url = backupURL {
                    ShareLink(item: url) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text("Export JSON complet du bridge. Utile comme trace de ta config, mais ce n'est pas une restauration automatique : les règles et scènes recréées reçoivent de nouveaux identifiants.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func choicesSection(_ inv: BridgeInventory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Que fait-on ?")
                .font(.headline)

            choice(title: "Tout garder",
                   subtitle: "HUEHACK s'installe à côté de l'existant. Attention aux conflits si d'autres règles pilotent les mêmes lampes.",
                   systemImage: "checkmark.circle",
                   tint: .green) {
                message = "Rien supprimé — HUEHACK s'installe à côté."
                isError = false
            }

            if inv.hasHUEHACK {
                choice(title: "Nettoyer HUEHACK",
                       subtitle: "Supprime les \(inv.huehackRules) règle(s) et \(inv.huehackSensors) capteur(s) HUEHACK, et oublie les réglages locaux. Le reste du bridge n'est pas touché.",
                       systemImage: "arrow.counterclockwise",
                       tint: .blue) {
                    runWipe(.huehackOnly)
                }
            }

            choice(title: "Repartir de zéro",
                   subtitle: "Supprime règles, programmations, scènes, resourcelinks et capteurs virtuels. Pièces, lampes et interrupteurs conservés.",
                   systemImage: "trash",
                   tint: .red) {
                pendingWipe = .everythingButRooms
            }
        }
    }

    @ViewBuilder
    private func choice(title: String, subtitle: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)
        }
        .disabled(wipeProgress != nil)
    }

    // MARK: - Actions

    private func loadConfig() {
        isLoading = true
        message = ""
        fetchBridgeConfig { _, json in
            isLoading = false
            guard let json else {
                inventory = nil
                return
            }
            rawConfig = json
            inventory = bridgeInventory(from: json)
        }
    }

    private func makeBackup() {
        guard let config = rawConfig else { return }
        if let url = saveBridgeBackup(config: config) {
            backupURL = url
            isError = false
            message = "Sauvegarde écrite : \(url.lastPathComponent)"
        } else {
            isError = true
            message = "Échec de la sauvegarde."
        }
    }

    private func runWipe(_ scope: WipeScope) {
        guard let config = rawConfig else { return }
        message = ""
        wipeProgress = (0, 0)
        wipeBridge(scope: scope, config: config) { done, total in
            wipeProgress = (done, total)
        } completion: { deleted, failed in
            wipeProgress = nil
            clearLocalHUEHACKState()
            isError = failed > 0
            message = failed == 0
                ? "\(deleted) élément(s) supprimé(s) ✓"
                : "\(deleted) supprimé(s), \(failed) échec(s)"
            loadConfig()
        }
    }
}

#Preview {
    NavigationStack { _c_welcome() }
}
