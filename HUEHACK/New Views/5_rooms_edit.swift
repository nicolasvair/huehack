//
//  5_rooms_edit.swift
//  HUEHACK
//

import SwiftUI

struct __roomsManage: View {

    @State private var groups = [String: RoomResponse]()
    @State private var isLoading = false
    @State private var pendingDelete: String? = nil
    @State private var showDeleteConfirm = false

    private var sortedIndices: [String] {
        groups.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    var body: some View {
        List {
            if isLoading && groups.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(sortedIndices, id: \.self) { idx in
                    if let room = groups[idx] {
                        NavigationLink {
                            RoomEditView(
                                groupIndex: idx,
                                initialName: room.name,
                                initialLights: Set(room.lights)
                            ) { loadData() }
                            .navigationTitle("Modifier la pièce")
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(room.name)
                                Text("\(room.lights.count) lumière\(room.lights.count > 1 ? "s" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let idx = sortedIndices[offsets.first!]
                    pendingDelete = idx
                    showDeleteConfirm = true
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RoomEditView(groupIndex: nil, initialName: "", initialLights: []) {
                        loadData()
                    }
                    .navigationTitle("Nouvelle pièce")
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Supprimer \(groups[pendingDelete ?? ""]?.name ?? "cette pièce") ?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let idx = pendingDelete, let id = Int(idx) {
                    sendDELETEGroup(ip: ip, groupIndex: id) { _ in
                        DispatchQueue.main.async { loadData() }
                    }
                }
            }
        } message: {
            Text("Les règles HUEHACK associées resteront sur le bridge.")
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        isLoading = true
        sendGETGroups(ip: ip, which: nil) { response in
            DispatchQueue.main.async {
                groups = response
                isLoading = false
            }
        }
    }
}

// MARK: - Room create / edit

struct RoomEditView: View {

    let groupIndex: String?
    @State private var name: String
    @State private var selectedLights: Set<String>
    @State private var allLights = [String: LightResponse]()
    @State private var isLoadingLights = true
    @State private var isSaving = false
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(groupIndex: String?, initialName: String, initialLights: Set<String>, onSave: @escaping () -> Void) {
        self.groupIndex = groupIndex
        self._name = State(initialValue: initialName)
        self._selectedLights = State(initialValue: initialLights)
        self.onSave = onSave
    }

    private var sortedLightIndices: [String] {
        allLights.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    var body: some View {
        Form {
            Section("Nom") {
                TextField("Nom de la pièce", text: $name)
            }

            Section("Lumières") {
                if isLoadingLights {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if allLights.isEmpty {
                    Text("Aucune lumière trouvée sur le bridge.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedLightIndices, id: \.self) { idx in
                        if let light = allLights[idx] {
                            Button {
                                if selectedLights.contains(idx) {
                                    selectedLights.remove(idx)
                                } else {
                                    selectedLights.insert(idx)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedLights.contains(idx) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedLights.contains(idx) ? .blue : .secondary)
                                    Text(light.name)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button(isSaving ? "Enregistrement…" : "Enregistrer") {
                    save()
                }
                .disabled(name.isEmpty || selectedLights.isEmpty || isSaving)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sendGETLights(ip: ip) { response in
                DispatchQueue.main.async {
                    allLights = response
                    isLoadingLights = false
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let lightsArray = Array(selectedLights)
        if let idx = groupIndex, let id = Int(idx) {
            sendPUTGroup(ip: ip, groupIndex: id, name: name, lights: lightsArray) { _ in
                DispatchQueue.main.async {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            }
        } else {
            sendPOSTGroup(ip: ip, name: name, lights: lightsArray) { _ in
                DispatchQueue.main.async {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        __roomsManage()
            .navigationTitle("Pièces")
    }
}
