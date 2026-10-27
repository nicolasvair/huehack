//
//  BridgeConfig.swift
//  HUEHACK
//
//  Reads the whole bridge config in one call, turns it into an inventory,
//  exports it as a JSON backup, and wipes resources from the bridge.
//
//  Note on backups: this is an EXPORT, not a restorable snapshot. Re-posting
//  rules/scenes/schedules gives them new ids, and rules reference sensor ids
//  (/sensors/172/state), so restoring needs a remapping pass that is not
//  implemented. Lights and groups are hardware-bound and cannot be recreated.
//

import Foundation

// MARK: - Inventory

struct BridgeInventory {
    var rules = 0
    var huehackRules = 0
    var schedules = 0
    var scenes = 0
    var resourcelinks = 0
    var clipSensors = 0
    var huehackSensors = 0
    var physicalSensors = 0
    var groups = 0
    var lights = 0

    /// Rules that are not HUEHACK's own.
    var otherRules: Int { max(0, rules - huehackRules) }
    var hasHUEHACK: Bool { huehackRules + huehackSensors > 0 }
    /// Anything HUEHACK could remove — rooms and physical devices excluded.
    var hasRemovableContent: Bool {
        rules + schedules + scenes + resourcelinks + clipSensors > 0
    }
}

private func isHUEHACK(_ name: String) -> Bool { name.hasPrefix("HUEHACK") }
private func isCLIP(_ type: String) -> Bool { type.hasPrefix("CLIP") }

func bridgeInventory(from config: [String: Any]) -> BridgeInventory {
    var inv = BridgeInventory()

    let rules = config["rules"] as? [String: [String: Any]] ?? [:]
    inv.rules = rules.count
    inv.huehackRules = rules.values.filter { isHUEHACK($0["name"] as? String ?? "") }.count

    inv.schedules = (config["schedules"] as? [String: Any])?.count ?? 0
    inv.scenes = (config["scenes"] as? [String: Any])?.count ?? 0
    inv.resourcelinks = (config["resourcelinks"] as? [String: Any])?.count ?? 0
    inv.groups = (config["groups"] as? [String: Any])?.count ?? 0
    inv.lights = (config["lights"] as? [String: Any])?.count ?? 0

    let sensors = config["sensors"] as? [String: [String: Any]] ?? [:]
    for sensor in sensors.values {
        let type = sensor["type"] as? String ?? ""
        let name = sensor["name"] as? String ?? ""
        if isCLIP(type) {
            inv.clipSensors += 1
            if isHUEHACK(name) { inv.huehackSensors += 1 }
        } else {
            inv.physicalSensors += 1
        }
    }

    return inv
}

// MARK: - Reading the whole config

/// GET /api/<username> — the bridge's entire configuration.
func fetchBridgeConfig(completion: @escaping (Data?, [String: Any]?) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)") else {
        DispatchQueue.main.async { completion(nil, nil) }
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.GET.rawValue

    URLSession.shared.dataTask(with: request) { data, _, _ in
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        DispatchQueue.main.async { completion(data, json) }
    }.resume()
}

// MARK: - Backup

/// Writes the config as pretty-printed JSON in Documents, returns the file URL.
func saveBridgeBackup(config: [String: Any]) -> URL? {
    guard let pretty = try? JSONSerialization.data(withJSONObject: config,
                                                   options: [.prettyPrinted, .sortedKeys]) else { return nil }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmm"
    let name = "huehack-bridge-backup-\(formatter.string(from: Date())).json"

    guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let url = dir.appendingPathComponent(name)
    do {
        try pretty.write(to: url, options: .atomic)
        return url
    } catch {
        print("Backup failed: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Wipe

enum WipeScope {
    /// HUEHACK's own rules and virtual sensors only — the rest of the bridge is untouched.
    case huehackOnly
    /// Rules, schedules, scenes, resourcelinks and CLIP sensors.
    /// Rooms (groups), lights and physical sensors are always kept.
    case everythingButRooms
}

private struct BridgeResource {
    let what: TypeWhat
    let id: String
}

private func resourcesToDelete(scope: WipeScope, config: [String: Any]) -> [BridgeResource] {
    var targets = [BridgeResource]()

    let rules = config["rules"] as? [String: [String: Any]] ?? [:]
    let sensors = config["sensors"] as? [String: [String: Any]] ?? [:]

    switch scope {
    case .huehackOnly:
        for (id, rule) in rules where isHUEHACK(rule["name"] as? String ?? "") {
            targets.append(BridgeResource(what: .rules, id: id))
        }
        for (id, sensor) in sensors
        where isCLIP(sensor["type"] as? String ?? "") && isHUEHACK(sensor["name"] as? String ?? "") {
            targets.append(BridgeResource(what: .sensors, id: id))
        }
        // The 10 s tick (HUEHACK-TIMER schedule) writes the TIMER sensor.
        let schedules = config["schedules"] as? [String: [String: Any]] ?? [:]
        for (id, schedule) in schedules where isHUEHACK(schedule["name"] as? String ?? "") {
            targets.append(BridgeResource(what: .schedules, id: id))
        }

    case .everythingButRooms:
        for id in rules.keys {
            targets.append(BridgeResource(what: .rules, id: id))
        }
        for id in ((config["schedules"] as? [String: Any]) ?? [:]).keys {
            targets.append(BridgeResource(what: .schedules, id: id))
        }
        for id in ((config["scenes"] as? [String: Any]) ?? [:]).keys {
            targets.append(BridgeResource(what: .scenes, id: id))
        }
        for id in ((config["resourcelinks"] as? [String: Any]) ?? [:]).keys {
            targets.append(BridgeResource(what: .resourcelinks, id: id))
        }
        // Physical sensors (switches, motion, Daylight) are never deleted:
        // removing them would mean re-pairing the hardware.
        for (id, sensor) in sensors where isCLIP(sensor["type"] as? String ?? "") {
            targets.append(BridgeResource(what: .sensors, id: id))
        }
    }

    // Rules first: they reference the sensors we are about to remove.
    return targets.filter { $0.what == .rules } + targets.filter { $0.what != .rules }
}

/// Scene and resourcelink ids are not numeric, so this takes a String id.
private func deleteBridgeResource(what: TypeWhat, id: String, completion: @escaping (Bool) -> Void) {
    guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let url = URL(string: "http://\(ip)/api/\(username)/\(what.rawValue)/\(encoded)") else {
        completion(false)
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.DELETE.rawValue

    URLSession.shared.dataTask(with: request) { data, _, _ in
        let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        completion(body.contains("\"success\""))
    }.resume()
}

/// Deletes the resources of `scope`, one at a time (the bridge throttles bursts).
/// Reports progress as (done, total) on the main queue.
func wipeBridge(scope: WipeScope,
                config: [String: Any],
                progress: @escaping (Int, Int) -> Void = { _, _ in },
                completion: @escaping (Int, Int) -> Void) {
    var remaining = resourcesToDelete(scope: scope, config: config)
    let total = remaining.count
    var deleted = 0
    var failed = 0

    guard total > 0 else {
        DispatchQueue.main.async { completion(0, 0) }
        return
    }

    func deleteNext() {
        guard let target = remaining.first else {
            DispatchQueue.main.async { completion(deleted, failed) }
            return
        }
        remaining.removeFirst()
        deleteBridgeResource(what: target.what, id: target.id) { ok in
            if ok { deleted += 1 } else { failed += 1 }
            DispatchQueue.main.async { progress(deleted + failed, total) }
            deleteNext()
        }
    }

    deleteNext()
}

/// Forgets everything HUEHACK stored locally: sensor indices, room links,
/// offsets and segment metadata. The bridge is not touched.
func clearLocalHUEHACKState() {
    let defaults = UserDefaults.standard
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("huehack-") {
        defaults.removeObject(forKey: key)
    }
    defaults.removeObject(forKey: "hueIndexTimer")
    defaults.removeObject(forKey: "hueIndexGlobalOnOff")
    defaults.removeObject(forKey: "indexTimer")
    defaults.removeObject(forKey: "indexGlobalOnOff")
}
