//
//  0d_welcome.swift
//  HUEHACK
//

import SwiftUI

struct _d_welcome: View {

    @State private var groups = [String: RoomResponse]()
    @State private var groupsIndices = [String]()
    @State private var selectedIndices = Set<String>()
    @State private var isLoading = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Text("Choisis les pièces que HUEHACK va contrôler.")
                    .padding()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if groupsIndices.isEmpty {
                    Text("Aucune pièce trouvée sur le bridge.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(groupsIndices, id: \.self) { idx in
                            if let room = groups[idx] {
                                Button {
                                    if selectedIndices.contains(idx) {
                                        selectedIndices.remove(idx)
                                    } else {
                                        selectedIndices.insert(idx)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: selectedIndices.contains(idx) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedIndices.contains(idx) ? .blue : .secondary)
                                        VStack(alignment: .leading) {
                                            Text(room.name)
                                                .foregroundStyle(.primary)
                                            Text("\(room.lights.count) lumière\(room.lights.count > 1 ? "s" : "")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    NavigationLink {
                        _e_welcome(selectedRooms: sortedIndices(selectedIndices))
                            .navigationTitle("Installation")
                    } label: {
                        Button_With_Icon(text: "next", icon: "arrowshape.right.circle", color: .fondClair)
                    }
                    .disabled(selectedIndices.isEmpty)
                    .opacity(selectedIndices.isEmpty ? 0.35 : 1)
                }
            }
            .padding()
        }
        .onAppear {
            if demoMode {
                groups = demoGroups
                groupsIndices = sortedIndices(demoGroups.keys)
                selectedIndices = Set(groupsIndices)
                return
            }
            isLoading = true
            sendGETGroups(ip: ip, which: nil) { response in
                groups = response
                groupsIndices = sortedIndices(response.map { $0.key })
                selectedIndices = Set(groupsIndices)
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack { _d_welcome() }
}
