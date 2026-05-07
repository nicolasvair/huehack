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
                ForEach(groupsIndices.sorted(), id: \.self) { idx in
                    if let room = groups[idx] {
                        NavigationLink {
                            __rules(presetGroupIndex: idx)
                                .navigationTitle(room.name)
                        } label: {
                            RoomCard(name: room.name, ct: room.action.ct ?? 300, offset: loadRoomOffset(idx))
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
        sendGETGroups(ip: ip, which: nil) { response in
            groups = response
            groupsIndices = response.map { $0.key }
        }
    }
}

struct RoomCard: View {
    let name: String
    let ct: Int
    let offset: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .foregroundStyle(Color(mireds: Double(min(500, max(153, ct)))))
                .frame(height: 110)
                .cornerRadius(14)

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

func loadRoomOffset(_ groupIndex: String) -> Int {
    UserDefaults.standard.integer(forKey: "huehack-offset-\(groupIndex)")
}

#Preview {
    NavigationStack {
        __rooms()
    }
}
