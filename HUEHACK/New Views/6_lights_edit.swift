//
//  6_lights_edit.swift
//  HUEHACK
//

import SwiftUI

struct __lightsManage: View {

    @State private var lights = [String: LightResponse]()
    @State private var isLoading = false
    @State private var blinkingIdx: String? = nil

    private var sortedIndices: [String] {
        lights.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    var body: some View {
        List {
            if isLoading && lights.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(sortedIndices, id: \.self) { idx in
                    if let light = lights[idx] {
                        NavigationLink {
                            LightEditView(lightIndex: idx, initialName: light.name) {
                                loadData()
                            }
                            .navigationTitle("Renommer")
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Text(light.name)
                                Spacer()
                                Button {
                                    blink(idx: idx)
                                } label: {
                                    Image(systemName: blinkingIdx == idx ? "bolt.fill" : "bolt")
                                        .foregroundStyle(blinkingIdx == idx ? .yellow : .secondary)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        isLoading = true
        sendGETLights(ip: ip) { response in
            DispatchQueue.main.async {
                lights = response
                isLoading = false
            }
        }
    }

    private func blink(idx: String) {
        guard let id = Int(idx) else { return }
        blinkingIdx = idx
        sendPUTLightAlert(ip: ip, lightIndex: id) { _ in
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if blinkingIdx == idx { blinkingIdx = nil }
                }
            }
        }
    }
}

// MARK: - Rename

struct LightEditView: View {

    let lightIndex: String
    @State private var name: String
    @State private var isSaving = false
    @State private var isBlinking = false
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(lightIndex: String, initialName: String, onSave: @escaping () -> Void) {
        self.lightIndex = lightIndex
        self._name = State(initialValue: initialName)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Nom") {
                TextField("Nom de la lumière", text: $name)
            }

            Section {
                Button(isSaving ? "Enregistrement…" : "Enregistrer") {
                    save()
                }
                .disabled(name.isEmpty || isSaving)
            }

            Section {
                Button {
                    blink()
                } label: {
                    HStack {
                        Image(systemName: isBlinking ? "bolt.fill" : "bolt")
                            .foregroundStyle(isBlinking ? .yellow : .accentColor)
                        Text(isBlinking ? "Clignotement…" : "Faire clignoter")
                    }
                }
                .disabled(isBlinking)
            } footer: {
                Text("Fait clignoter la lumière une fois pour l'identifier.")
                    .font(.caption)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        guard let id = Int(lightIndex) else { return }
        isSaving = true
        sendPUTLightName(ip: ip, lightIndex: id, name: name) { _ in
            DispatchQueue.main.async {
                isSaving = false
                onSave()
                dismiss()
            }
        }
    }

    private func blink() {
        guard let id = Int(lightIndex) else { return }
        isBlinking = true
        sendPUTLightAlert(ip: ip, lightIndex: id) { _ in
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isBlinking = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        __lightsManage()
            .navigationTitle("Lumières")
    }
}
