//
//  4_rooms.swift
//  HUEHACK
//

import SwiftUI

struct __rooms: View {

    @State private var groups = [String: RoomResponse]()
    @State private var groupsIndices = [String]()

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(groupsIndices, id: \.self) { idx in
                    if let room = groups[idx] {
                        NavigationLink {
                            __rules(presetGroupIndex: idx)
                                .navigationTitle(room.name)
                        } label: {
                            RoomCard(
                                name: room.name,
                                ct: room.action.ct ?? 300,
                                offset: roomOffset(idx),
                                linkedCount: roomLinks(idx).count
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .onAppear { loadGroups() }
    }

    private func loadGroups() {
        if demoMode {
            groups = demoGroups
            groupsIndices = sortedIndices(demoGroups.keys)
            return
        }
        sendGETGroups(ip: ip, which: nil) { response in
            groups = response
            groupsIndices = sortedIndices(response.map { $0.key })
            migrateAndPruneRoomLinks(existingIndices: groupsIndices)
        }
    }
}

struct RoomCard: View {
    let name: String
    let ct: Int
    let offset: Int
    var linkedCount: Int = 0

    var body: some View {
        Rectangle()
            .foregroundStyle(Color(mireds: Double(min(500, max(153, ct)))))
            .frame(height: 110)
            .cornerRadius(14)
            // Icon only — the link is what matters, not a label explaining it.
            .overlay(alignment: .topTrailing) {
                if linkedCount > 0 {
                    Image(systemName: "link")
                        .font(.title2)
                        .foregroundStyle(.black.opacity(0.5))
                        .padding(10)
                        .accessibilityLabel("Liée à \(linkedCount) pièce(s)")
                }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black.opacity(0.75))
                    if offset != 0 {
                        Text("\(offset > 0 ? "+" : "")\(offset) mir")
                            .font(.caption2)
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
                .padding(10)
            }
    }
}

#Preview {
    NavigationStack {
        __rooms()
    }
}
