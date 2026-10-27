//
//  4_rooms.swift
//  HUEHACK
//

import SwiftUI

struct __rooms: View {

    @State private var groups = [String: RoomResponse]()
    @State private var groupsIndices = [String]()
    @State private var linkCounts = [String: Int]()  // refreshed on every appear (links edited in __rules)
    @State private var pausedRooms = [String: Bool]() // circadian paused (manual colour), refreshed on every appear

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
                                linkedCount: linkCounts[idx] ?? 0,
                                paused: pausedRooms[idx] ?? false,
                                manualColor: manualColor(for: room, paused: pausedRooms[idx] ?? false)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            refreshLinkCounts()
            refreshPauseStates()
            loadGroups()
        }
    }

    /// One GET /sensors for every room's pause sensor. Keeps the last known
    /// states if the bridge cannot be read.
    private func refreshPauseStates() {
        fetchOverrideStates { states in
            guard let states = states else { return }
            pausedRooms = states
        }
    }

    /// A paused room in hue/sat mode shows its manual colour instead of a ct.
    private func manualColor(for room: RoomResponse, paused: Bool) -> Color? {
        guard paused, room.action.colormode == "hs",
              let hue = room.action.hue, let sat = room.action.sat else { return nil }
        return Color(hue: Double(hue) / 65535, saturation: Double(sat) / 254, brightness: 1)
    }

    private func refreshLinkCounts() {
        linkCounts = Dictionary(uniqueKeysWithValues: groupsIndices.map { ($0, roomLinks($0).count) })
    }

    private func loadGroups() {
        if demoMode {
            groups = demoGroups
            groupsIndices = sortedIndices(demoGroups.keys)
            refreshLinkCounts()
            return
        }
        sendGETGroups(ip: ip, which: nil) { response in
            groups = response
            groupsIndices = sortedIndices(response.map { $0.key })
            migrateAndPruneRoomLinks(existingIndices: groupsIndices)
            refreshLinkCounts()
            // The 10 s loop stops after a bridge reboot: restart it if idle.
            ensureTimerRunning()
            // Once per session: adds the pause condition to rules pushed by older builds.
            migrateLegacyRulesToOverride(existingGroups: groupsIndices) { migrated in
                if migrated > 0 { refreshPauseStates() }
            }
        }
    }
}

struct RoomCard: View {
    let name: String
    let ct: Int
    let offset: Int
    var linkedCount: Int = 0
    var paused: Bool = false
    var manualColor: Color? = nil

    var body: some View {
        Rectangle()
            .foregroundStyle(manualColor ?? Color(mireds: Double(min(500, max(153, ct)))))
            .frame(height: 110)
            .cornerRadius(14)
            // Icon only — the link is what matters, not a label explaining it.
            .overlay(alignment: .topTrailing) {
                if linkedCount > 0 {
                    Image(systemName: "link")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(8)
                        .background(.white.opacity(0.35), in: Circle())
                        .padding(6)
                        .accessibilityLabel("Liée à \(linkedCount) pièce(s)")
                }
            }
            .overlay(alignment: .topLeading) {
                if paused {
                    Image(systemName: "pause.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(8)
                        .background(.white.opacity(0.35), in: Circle())
                        .padding(6)
                        .accessibilityLabel("Circadien en pause")
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
