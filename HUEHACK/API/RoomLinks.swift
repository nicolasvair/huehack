//
//  RoomLinks.swift
//  HUEHACK
//
//  Link between rooms: a link group is a set of rooms sharing the same schedule.
//  Links are symmetric and fully connected — every member of a group knows all
//  the others. A room keeps its own bridge rules (and its own mireds offset),
//  so its sync state always reflects what is really installed on the bridge.
//  Linking only means: pushing one room pushes the whole group, and the fade
//  (transition time) is shared by the whole group.
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
        // `peerLinks` excludes `peer` itself: one remaining entry still means a
        // group of two. An empty set (group of one) is cleared by setRoomLinks.
        setRoomLinks(peerLinks, for: peer)
    }
    setRoomLinks([], for: groupIndex)
}

/// Makes the rooms linked to `groupIndex` exactly `selection` (multi-select UI).
/// Unticked rooms leave the group (the others stay linked together); ticked rooms
/// join it — a ticked room that already belongs to another group leaves that group
/// (whose other members stay linked together) instead of bringing it along.
/// Returns the rooms that were not in the group before and now are: they still
/// hold their old schedule on the bridge and need a push.
@discardableResult
func updateRoomLinks(for groupIndex: String, to selection: Set<String>) -> [String] {
    let before = Set(roomLinkGroup(groupIndex))
    let selection = selection.subtracting([groupIndex])
    let current = Set(roomLinks(groupIndex))

    for removed in current.subtracting(selection) {
        unlinkRoom(removed)
    }
    for added in selection.subtracting(current) {
        unlinkRoom(added)
        linkRooms(groupIndex, added)
    }
    let joined = sortedIndices(Set(roomLinkGroup(groupIndex)).subtracting(before))
    // The fade is a shared link setting: newcomers adopt this room's fade, so the
    // push that follows installs it on them too.
    let fade = roomFade(groupIndex)
    for room in joined {
        setRoomFade(fade, for: room)
    }
    return joined
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

    // Repair groups that are not fully connected (defensive: links are written
    // one room at a time): every member must list every other member.
    for idx in existingIndices {
        for peer in roomLinks(idx) where !roomLinks(peer).contains(idx) {
            linkRooms(idx, peer)
        }
    }
}

func roomOffset(_ groupIndex: String) -> Int {
    UserDefaults.standard.integer(forKey: "huehack-offset-\(groupIndex)")
}

func setRoomOffset(_ offset: Int, for groupIndex: String) {
    UserDefaults.standard.set(offset, forKey: "huehack-offset-\(groupIndex)")
}

/// Hue `transitiontime` (deciseconds) the bridge uses when none is sent: 0.4 s.
let defaultRoomFade = 4

private func fadeKey(_ groupIndex: String) -> String { "huehack-fade-\(groupIndex)" }

/// Room fade in deciseconds (Hue `transitiontime`): `defaultRoomFade` when never set.
/// Shared by every room of a link group (unlike the offset, which stays per room).
func roomFade(_ groupIndex: String) -> Int {
    guard UserDefaults.standard.object(forKey: fadeKey(groupIndex)) != nil else { return defaultRoomFade }
    return min(65535, max(0, UserDefaults.standard.integer(forKey: fadeKey(groupIndex))))
}

/// Sets the fade of this room only. UI code should use `setLinkGroupFade`.
func setRoomFade(_ fade: Int, for groupIndex: String) {
    UserDefaults.standard.set(min(65535, max(0, fade)), forKey: fadeKey(groupIndex))
}

/// Sets the fade of `groupIndex` and of every room linked to it.
func setLinkGroupFade(_ fade: Int, for groupIndex: String) {
    for member in roomLinkGroup(groupIndex) {
        setRoomFade(fade, for: member)
    }
}

func sortedIndices<S: Sequence>(_ indices: S) -> [String] where S.Element == String {
    indices.sorted { (Int($0) ?? 0, $0) < (Int($1) ?? 0, $1) }
}
