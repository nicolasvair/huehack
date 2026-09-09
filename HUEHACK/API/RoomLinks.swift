//
//  RoomLinks.swift
//  HUEHACK
//
//  Link between rooms: a link group is a set of rooms sharing the same schedule.
//  Links are symmetric and fully connected — every member of a group knows all
//  the others. A room keeps its own bridge rules (and its own mireds offset),
//  so its sync state always reflects what is really installed on the bridge.
//  Linking only means: pushing one room pushes the whole group.
//

import Foundation

private func linksKey(_ groupIndex: String) -> String { "huehack-links-\(groupIndex)" }
private func legacyLinkKey(_ groupIndex: String) -> String { "huehack-linkedTo-\(groupIndex)" }

/// Rooms linked to `groupIndex` (excluding itself), sorted by bridge index.
func roomLinks(_ groupIndex: String) -> [String] {
    guard let data = UserDefaults.standard.data(forKey: linksKey(groupIndex)),
          let links = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return sortedIndices(Set(links).subtracting([groupIndex]))
}

/// The whole link group: `groupIndex` plus every room linked to it.
func roomLinkGroup(_ groupIndex: String) -> [String] {
    sortedIndices(Set(roomLinks(groupIndex)).union([groupIndex]))
}

private func setRoomLinks(_ links: Set<String>, for groupIndex: String) {
    let value = sortedIndices(links.subtracting([groupIndex]))
    if value.isEmpty {
        UserDefaults.standard.removeObject(forKey: linksKey(groupIndex))
    } else if let encoded = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(encoded, forKey: linksKey(groupIndex))
    }
}

/// Merge the link groups of `a` and `b` — every member ends up linked to all others.
func linkRooms(_ a: String, _ b: String) {
    guard a != b else { return }
    let members = Set(roomLinkGroup(a)).union(roomLinkGroup(b))
    for member in members {
        setRoomLinks(members, for: member)
    }
}

/// Take `groupIndex` out of its link group, leaving the others linked together.
func unlinkRoom(_ groupIndex: String) {
    for peer in roomLinks(groupIndex) {
        var peerLinks = Set(roomLinks(peer))
        peerLinks.remove(groupIndex)
        // A group of one is not a group.
        setRoomLinks(peerLinks.count > 1 ? peerLinks : [], for: peer)
    }
    setRoomLinks([], for: groupIndex)
}

/// Drop every link of every room in the group of `groupIndex`.
func unlinkWholeGroup(_ groupIndex: String) {
    for member in roomLinkGroup(groupIndex) {
        setRoomLinks([], for: member)
    }
}

/// Migrates the old one-master-per-room storage to symmetric links, and drops
/// links pointing at rooms that no longer exist on the bridge.
func migrateAndPruneRoomLinks(existingIndices: [String]) {
    guard !existingIndices.isEmpty else { return }
    let existing = Set(existingIndices)

    for idx in existingIndices {
        if let master = UserDefaults.standard.string(forKey: legacyLinkKey(idx)) {
            UserDefaults.standard.removeObject(forKey: legacyLinkKey(idx))
            if existing.contains(master) { linkRooms(idx, master) }
        }
    }

    for idx in existingIndices {
        let links = Set(roomLinks(idx))
        let alive = links.intersection(existing)
        if alive != links { setRoomLinks(alive, for: idx) }
    }
}

func roomOffset(_ groupIndex: String) -> Int {
    UserDefaults.standard.integer(forKey: "huehack-offset-\(groupIndex)")
}

func setRoomOffset(_ offset: Int, for groupIndex: String) {
    UserDefaults.standard.set(offset, forKey: "huehack-offset-\(groupIndex)")
}

func sortedIndices<S: Sequence>(_ indices: S) -> [String] where S.Element == String {
    indices.sorted { (Int($0) ?? 0, $0) < (Int($1) ?? 0, $1) }
}
