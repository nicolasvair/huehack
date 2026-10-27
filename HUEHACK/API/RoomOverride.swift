//
//  RoomOverride.swift
//  HUEHACK
//
//  Per-room circadian pause ("manual colour override").
//
//  Each room gets a virtual sensor `HUEHACK-OVR-<g>` (CLIPGenericStatus):
//    status 0 = circadian running, 1 = paused (manual colour),
//    2 = resume pending: the pause ended while the room was off, its manual
//        brightness is restored to 100 % at the next switch-on.
//  Every segment rule of the room carries a 4th condition
//  `/sensors/<ovr>/state/status eq 0`, so setting the sensor to 1 pauses only
//  that room. A rule `HUEHACK-OVRRESET-<g>` sets it to 2 when the room is
//  switched off (any_on goes false); `HUEHACK-OVRRESTORE-<g>` then puts the
//  brightness back to 100 % and the sensor to 0 at the next switch-on, so the
//  room is circadian again (the rules only send ct, never bri).
//
//  Pushing a schedule never touches the sensor's status: a paused room stays
//  paused after an Update (or a push coming from a linked room).
//

import Foundation

// MARK: - Names & local storage

func overrideSensorName(_ groupIndex: Int) -> String {
    "HUEHACK-OVR-\(String(format: "%02d", groupIndex))"
}

func overrideResetRuleName(_ groupIndex: Int) -> String {
    "HUEHACK-OVRRESET-\(String(format: "%02d", groupIndex))"
}

func overrideRestoreRuleName(_ groupIndex: Int) -> String {
    "HUEHACK-OVRRESTORE-\(String(format: "%02d", groupIndex))"
}

/// OVR sensor status values.
let overrideStatusRunning = 0
let overrideStatusPaused = 1
let overrideStatusRestorePending = 2

/// Brightness the circadian gives back after a manual colour (Hue max).
let circadianBrightness = 254

private func overrideIndexKey(_ groupIndex: Int) -> String { "huehack-ovr-\(groupIndex)" }

/// Last known bridge id of the room's OVR sensor (nil if never seen).
func storedOverrideIndex(_ groupIndex: Int) -> Int? {
    let value = UserDefaults.standard.integer(forKey: overrideIndexKey(groupIndex))
    return value > 0 ? value : nil
}

private func storeOverrideIndex(_ index: Int, for groupIndex: Int) {
    UserDefaults.standard.set(index, forKey: overrideIndexKey(groupIndex))
}

func forgetOverrideIndex(_ groupIndex: Int) {
    UserDefaults.standard.removeObject(forKey: overrideIndexKey(groupIndex))
}

/// `HUEHACK-OVR-<g>` → g. Nil for any other name (TIMER, GLOBAL ONOFF…).
func parseOverrideSensorName(_ name: String) -> Int? {
    let prefix = "HUEHACK-OVR-"
    guard name.hasPrefix(prefix) else { return nil }
    return Int(name.dropFirst(prefix.count))
}

func overrideConditionAddress(_ overrideIndex: Int) -> String {
    "/sensors/\(overrideIndex)/state/status"
}

// MARK: - Raw bridge access
// JSONSerialization rather than the Decodable models: a single odd sensor or
// rule on the bridge must not make the whole read fail.

private func onMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
}

/// Completes on main with the parsed JSON response, or nil on any failure.
private func hueRequest(_ method: TypeRequest, _ path: String, body: Any? = nil,
                        completion: @escaping (Any?) -> Void) {
    func finish(_ result: Any?) { DispatchQueue.main.async { completion(result) } }

    guard let url = URL(string: "http://\(ip)/api/\(username)/\(path)") else {
        finish(nil)
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    if let body = body {
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            finish(nil)
            return
        }
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    URLSession.shared.dataTask(with: request) { data, _, error in
        guard error == nil, let data = data else { finish(nil); return }
        finish(try? JSONSerialization.jsonObject(with: data))
    }.resume()
}

/// True when the bridge answered only `success` entries.
private func hueSucceeded(_ json: Any?) -> Bool {
    guard let items = json as? [[String: Any]], !items.isEmpty else { return false }
    return items.allSatisfy { $0["success"] != nil }
}

/// GET /sensors as raw dictionaries. Nil if the read failed (network, bridge error).
func fetchRawSensors(completion: @escaping ([String: [String: Any]]?) -> Void) {
    hueRequest(.GET, "sensors") { completion($0 as? [String: [String: Any]]) }
}

/// GET /rules as raw dictionaries. Nil if the read failed (network, bridge error).
func fetchRawRules(completion: @escaping ([String: [String: Any]]?) -> Void) {
    hueRequest(.GET, "rules") { completion($0 as? [String: [String: Any]]) }
}

/// Deletes the resources one after the other (the bridge throttles bursts).
/// Completes on main with false if any delete failed.
private func deleteSequentially(_ what: TypeWhat, ids: [Int], completion: @escaping (Bool) -> Void) {
    var remaining = ids
    var allDeleted = true

    func deleteNext() {
        guard !remaining.isEmpty else {
            DispatchQueue.main.async { completion(allDeleted) }
            return
        }
        let id = remaining.removeFirst()
        sendDELETERequest(ip: ip, what: what, which: id) { response in
            if !response.contains("\"success\"") { allDeleted = false }
            deleteNext()
        }
    }

    deleteNext()
}

private func resourceName(_ resource: [String: Any]) -> String {
    resource["name"] as? String ?? ""
}

private func sensorStatus(_ sensor: [String: Any]) -> Int? {
    (sensor["state"] as? [String: Any])?["status"] as? Int
}

/// Ids of the sensors exactly named `HUEHACK-OVR-<g>`, lowest first.
private func overrideSensorIds(in sensors: [String: [String: Any]], groupIndex: Int) -> [Int] {
    let expected = overrideSensorName(groupIndex)
    return sensors.filter { resourceName($0.value) == expected }.compactMap { Int($0.key) }.sorted()
}

private func ruleConditions(_ rule: [String: Any]) -> [[String: Any]] {
    rule["conditions"] as? [[String: Any]] ?? []
}

private func ruleHasOverrideCondition(_ rule: [String: Any], overrideIndex: Int) -> Bool {
    let address = overrideConditionAddress(overrideIndex)
    return ruleConditions(rule).contains { $0["address"] as? String == address }
}

// MARK: - OVR sensor

/// Main-thread only: completions waiting for an ensure already in flight.
private var pendingOverrideSensorRequests = [Int: [(Int?) -> Void]]()

/// Finds (or creates) the room's OVR sensor and completes on main with its id.
/// - Found by exact name (lowest id if duplicated) → id saved and returned, so a
///   reinstall or a sensor recreated elsewhere is picked up.
/// - Read failed → the stored id or nil. Never creates after a failed read
///   (it could not know the sensor is really missing).
/// - Absent → created (status 0 = circadian running).
/// The status of an existing sensor is never changed here. Concurrent calls for
/// the same room share one request, so they cannot create duplicates.
func ensureOverrideSensor(groupIndex: Int, completion: @escaping (Int?) -> Void) {
    onMain {
        if demoMode { completion(nil); return }
        if pendingOverrideSensorRequests[groupIndex] != nil {
            pendingOverrideSensorRequests[groupIndex]?.append(completion)
            return
        }
        pendingOverrideSensorRequests[groupIndex] = [completion]

        func finish(_ index: Int?) {
            let waiters = pendingOverrideSensorRequests.removeValue(forKey: groupIndex) ?? []
            waiters.forEach { $0(index) }
        }

        fetchRawSensors { sensors in
            guard let sensors = sensors else {
                finish(storedOverrideIndex(groupIndex))
                return
            }
            if let existing = overrideSensorIds(in: sensors, groupIndex: groupIndex).first {
                storeOverrideIndex(existing, for: groupIndex)
                finish(existing)
                return
            }
            createVirtualSensor(name: overrideSensorName(groupIndex),
                                uniqueid: "huehack-ovr-\(String(format: "%02d", groupIndex))") { index in
                if let index = index { storeOverrideIndex(index, for: groupIndex) }
                finish(index)
            }
        }
    }
}

// MARK: - Auto-resume rules

/// Main-thread only: completions waiting for a reset-rule ensure already in flight.
private var pendingResetRuleRequests = [Int: [(Bool) -> Void]]()

private func ruleActions(_ rule: [String: Any]) -> [[String: Any]] {
    rule["actions"] as? [[String: Any]] ?? []
}

private func actionStatus(_ action: [String: Any]) -> Int? {
    (action["body"] as? [String: Any])?["status"] as? Int
}

private func ruleWatchesRoom(_ rule: [String: Any], groupIndex: Int) -> Bool {
    ruleConditions(rule).contains { $0["address"] as? String == "/groups/\(groupIndex)/state/any_on" }
}

/// Switch-off while paused → status 2 (resume pending).
private func resetRuleIsValid(_ rule: [String: Any], groupIndex: Int, overrideIndex: Int) -> Bool {
    let setsPending = ruleActions(rule).contains {
        $0["address"] as? String == "/sensors/\(overrideIndex)/state"
            && actionStatus($0) == overrideStatusRestorePending
    }
    return setsPending && ruleWatchesRoom(rule, groupIndex: groupIndex)
        && ruleHasOverrideCondition(rule, overrideIndex: overrideIndex)
}

/// Switch-on while resume pending → full brightness, then status 0.
private func restoreRuleIsValid(_ rule: [String: Any], groupIndex: Int, overrideIndex: Int) -> Bool {
    let actions = ruleActions(rule)
    let restoresBri = actions.contains {
        $0["address"] as? String == "/groups/\(groupIndex)/action"
            && ($0["body"] as? [String: Any])?["bri"] as? Int == circadianBrightness
    }
    let resumes = actions.contains {
        $0["address"] as? String == "/sensors/\(overrideIndex)/state"
            && actionStatus($0) == overrideStatusRunning
    }
    return restoresBri && resumes && ruleWatchesRoom(rule, groupIndex: groupIndex)
        && ruleHasOverrideCondition(rule, overrideIndex: overrideIndex)
}

private func postResetRule(groupIndex: Int, overrideIndex: Int, completion: @escaping (Bool) -> Void) {
    let anyOn = "/groups/\(groupIndex)/state/any_on"
    let conditions: [[String: String]] = [
        ["address": anyOn, "operator": "dx"],
        ["address": anyOn, "operator": "eq", "value": "false"],
        ["address": overrideConditionAddress(overrideIndex), "operator": "eq", "value": String(overrideStatusPaused)],
    ]
    let action: [String: Any] = [
        "address": "/sensors/\(overrideIndex)/state",
        "method": "PUT",
        "body": ["status": overrideStatusRestorePending],
    ]
    let body: [String: Any] = [
        "name": overrideResetRuleName(groupIndex),
        "conditions": conditions,
        "actions": [action],
    ]
    hueRequest(.POST, "rules", body: body) { completion(hueSucceeded($0)) }
}

private func postRestoreRule(groupIndex: Int, overrideIndex: Int, completion: @escaping (Bool) -> Void) {
    let anyOn = "/groups/\(groupIndex)/state/any_on"
    let conditions: [[String: String]] = [
        ["address": anyOn, "operator": "dx"],
        ["address": anyOn, "operator": "eq", "value": "true"],
        ["address": overrideConditionAddress(overrideIndex), "operator": "eq", "value": String(overrideStatusRestorePending)],
    ]
    // Brightness first; the next 10 s tick then applies the segment's ct.
    let actions: [[String: Any]] = [
        ["address": "/groups/\(groupIndex)/action", "method": "PUT", "body": ["bri": circadianBrightness]],
        ["address": "/sensors/\(overrideIndex)/state", "method": "PUT", "body": ["status": overrideStatusRunning]],
    ]
    let body: [String: Any] = [
        "name": overrideRestoreRuleName(groupIndex),
        "conditions": conditions,
        "actions": actions,
    ]
    hueRequest(.POST, "rules", body: body) { completion(hueSucceeded($0)) }
}

/// Makes sure exactly one valid rule named `name` exists; anything else under
/// that name (duplicates, wrong sensor, older version) is deleted and replaced.
private func ensureNamedRule(_ name: String, in rules: [String: [String: Any]],
                             isValid: ([String: Any]) -> Bool,
                             post: @escaping (@escaping (Bool) -> Void) -> Void,
                             completion: @escaping (Bool) -> Void) {
    let matches = rules.filter { resourceName($0.value) == name }
    if matches.count == 1, let rule = matches.first?.value, isValid(rule) {
        completion(true)
        return
    }
    deleteSequentially(.rules, ids: matches.keys.compactMap { Int($0) }.sorted()) { deleted in
        // Posting on top of a rule that could not be deleted would leave duplicates.
        guard deleted else { completion(false); return }
        post(completion)
    }
}

/// Makes sure the room's two auto-resume rules exist and are current:
/// `HUEHACK-OVRRESET-<g>` (switch-off while paused → resume pending) and
/// `HUEHACK-OVRRESTORE-<g>` (switch-on while pending → 100 % brightness, circadian).
/// Completes on main.
func ensureOverrideResetRule(groupIndex: Int, overrideIndex: Int, completion: @escaping (Bool) -> Void) {
    onMain {
        if demoMode { completion(true); return }
        if pendingResetRuleRequests[groupIndex] != nil {
            pendingResetRuleRequests[groupIndex]?.append(completion)
            return
        }
        pendingResetRuleRequests[groupIndex] = [completion]

        func finish(_ ok: Bool) {
            let waiters = pendingResetRuleRequests.removeValue(forKey: groupIndex) ?? []
            waiters.forEach { $0(ok) }
        }

        fetchRawRules { rules in
            guard let rules = rules else { finish(false); return }
            ensureNamedRule(overrideResetRuleName(groupIndex), in: rules,
                            isValid: { resetRuleIsValid($0, groupIndex: groupIndex, overrideIndex: overrideIndex) },
                            post: { postResetRule(groupIndex: groupIndex, overrideIndex: overrideIndex, completion: $0) }) { resetOK in
                ensureNamedRule(overrideRestoreRuleName(groupIndex), in: rules,
                                isValid: { restoreRuleIsValid($0, groupIndex: groupIndex, overrideIndex: overrideIndex) },
                                post: { postRestoreRule(groupIndex: groupIndex, overrideIndex: overrideIndex, completion: $0) }) { restoreOK in
                    finish(resetOK && restoreOK)
                }
            }
        }
    }
}

// MARK: - Guarding the segment rules

/// Conditions re-serialized for a PUT (only address / operator / value, value omitted when absent).
private func reserializedConditions(_ rule: [String: Any]) -> [[String: Any]] {
    ruleConditions(rule).map { condition in
        var out = [String: Any]()
        out["address"] = condition["address"] as? String
        out["operator"] = condition["operator"] as? String
        if let value = condition["value"] as? String { out["value"] = value }
        return out
    }
}

/// A status condition left behind by an OVR sensor that no longer exists (or by
/// another OVR sensor than the current one).
private func isStaleOverrideCondition(_ condition: [String: Any], overrideIndex: Int,
                                      sensors: [String: [String: Any]]) -> Bool {
    guard let address = condition["address"] as? String,
          address.hasPrefix("/sensors/"), address.hasSuffix("/state/status") else { return false }
    let id = address.dropFirst("/sensors/".count).dropLast("/state/status".count)
    guard let index = Int(id), index != overrideIndex else { return false }
    guard let sensor = sensors[String(id)] else { return true }
    return resourceName(sensor).hasPrefix("HUEHACK-OVR-")
}

/// Adds the OVR condition to every `HUEHACK-<g>-NN` rule of the room that lacks it
/// (`PUT /rules/<id>` with the conditions only: ids, names, actions and segment
/// meta are kept). Sequential. Completes on main with false if any rule could not
/// be read or updated.
private func guardSegmentRules(groupIndex: Int, overrideIndex: Int, completion: @escaping (Bool) -> Void) {
    fetchRawRules { rules in
        guard let rules = rules else { completion(false); return }
        var remaining = rules
            .filter { parseHUEHACKRuleName(resourceName($0.value))?.group == groupIndex
                && !ruleHasOverrideCondition($0.value, overrideIndex: overrideIndex) }
            .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }
        guard !remaining.isEmpty else { completion(true); return }

        fetchRawSensors { sensors in
            guard let sensors = sensors else { completion(false); return }
            var allOK = true

            func patchNext() {
                guard !remaining.isEmpty else { completion(allOK); return }
                let (id, rule) = remaining.removeFirst()
                var conditions = reserializedConditions(rule)
                    .filter { !isStaleOverrideCondition($0, overrideIndex: overrideIndex, sensors: sensors) }
                conditions.append(["address": overrideConditionAddress(overrideIndex), "operator": "eq", "value": "0"])
                hueRequest(.PUT, "rules/\(id)", body: ["conditions": conditions]) { json in
                    if !hueSucceeded(json) { allOK = false }
                    patchNext()
                }
            }

            patchNext()
        }
    }
}

/// Everything a room needs for the pause to work: its OVR sensor, its reset rule
/// (best effort — without it the pause just does not end by itself) and the OVR
/// condition on all its segment rules. Completes on main with the sensor id, or
/// nil if the pause could not be made effective.
func prepareRoomOverride(groupIndex: Int, completion: @escaping (Int?) -> Void) {
    ensureOverrideSensor(groupIndex: groupIndex) { overrideIndex in
        guard let overrideIndex = overrideIndex else { completion(nil); return }
        ensureOverrideResetRule(groupIndex: groupIndex, overrideIndex: overrideIndex) { resetOK in
            if !resetOK { print("HUEHACK: reset rule not installed for group \(groupIndex)") }
            guardSegmentRules(groupIndex: groupIndex, overrideIndex: overrideIndex) { guarded in
                completion(guarded ? overrideIndex : nil)
            }
        }
    }
}

// MARK: - Migration of rules pushed by older builds

/// Main-thread only.
private var overrideMigrationStarted = false

/// Once per app session (retried on the next call if the bridge could not be
/// read): for every existing room whose segment rules lack the OVR condition,
/// or whose OVR sensor / reset rule is missing, installs them and patches the
/// rules in place. Rooms are handled one after the other. Completes on main with
/// the number of rooms migrated.
func migrateLegacyRulesToOverride(existingGroups: [String], completion: @escaping (Int) -> Void = { _ in }) {
    onMain {
        guard !demoMode, !overrideMigrationStarted, !existingGroups.isEmpty else {
            completion(0)
            return
        }
        overrideMigrationStarted = true
        let existing = Set(existingGroups.compactMap { Int($0) })

        fetchRawRules { rules in
            guard let rules = rules else {
                overrideMigrationStarted = false
                completion(0)
                return
            }
            fetchRawSensors { sensors in
                guard let sensors = sensors else {
                    overrideMigrationStarted = false
                    completion(0)
                    return
                }
                let ruleNames = Set(rules.values.map { resourceName($0) })
                var segmentRulesByGroup = [Int: [[String: Any]]]()
                for rule in rules.values {
                    if let group = parseHUEHACKRuleName(resourceName(rule))?.group, existing.contains(group) {
                        segmentRulesByGroup[group, default: []].append(rule)
                    }
                }
                var remaining = segmentRulesByGroup.filter { group, groupRules in
                    guard let ovr = overrideSensorIds(in: sensors, groupIndex: group).first else { return true }
                    if !ruleNames.contains(overrideResetRuleName(group))
                        || !ruleNames.contains(overrideRestoreRuleName(group)) { return true }
                    return groupRules.contains { !ruleHasOverrideCondition($0, overrideIndex: ovr) }
                }.keys.sorted()
                var migrated = 0

                func migrateNext() {
                    guard !remaining.isEmpty else { completion(migrated); return }
                    let group = remaining.removeFirst()
                    prepareRoomOverride(groupIndex: group) { overrideIndex in
                        if overrideIndex != nil { migrated += 1 }
                        migrateNext()
                    }
                }

                migrateNext()
            }
        }
    }
}

// MARK: - Reading the pause state

/// [groupIndex: paused] for every room that has an OVR sensor (lowest id when
/// duplicated). Nil if the sensors could not be read. Completes on main.
func fetchOverrideStates(completion: @escaping ([String: Bool]?) -> Void) {
    if demoMode {
        completion(Dictionary(uniqueKeysWithValues: demoPausedRooms.map { ($0, true) }))
        return
    }
    fetchRawSensors { sensors in
        guard let sensors = sensors else { completion(nil); return }
        var lowest = [Int: (id: Int, sensor: [String: Any])]()
        for (key, sensor) in sensors {
            guard let group = parseOverrideSensorName(resourceName(sensor)), let id = Int(key) else { continue }
            if let current = lowest[group], current.id < id { continue }
            lowest[group] = (id, sensor)
        }
        var states = [String: Bool]()
        for (group, entry) in lowest {
            states[String(group)] = sensorStatus(entry.sensor) == overrideStatusPaused
        }
        completion(states)
    }
}

/// Whether this room's circadian is paused; nil if the bridge could not be read.
func fetchRoomOverrideState(groupIndex: Int, completion: @escaping (Bool?) -> Void) {
    fetchOverrideStates { states in
        guard let states = states else { completion(nil); return }
        completion(states[String(groupIndex)] ?? false)
    }
}

// MARK: - Manual colour / resume

private func putOverrideStatus(_ overrideIndex: Int, status: Int, completion: @escaping (Bool) -> Void) {
    hueRequest(.PUT, "sensors/\(overrideIndex)/state", body: ["status": status]) {
        completion(hueSucceeded($0))
    }
}

/// Pauses the room's circadian, THEN sends the colour (the reverse order would
/// let a 10 s tick overwrite it). Completes on main with (success, message).
func applyManualColor(groupIndex: Int, hue: Int, sat: Int, bri: Int, completion: @escaping (Bool, String) -> Void) {
    if demoMode {
        demoPausedRooms.insert(String(groupIndex))
        completion(true, "Couleur appliquée")
        return
    }
    prepareRoomOverride(groupIndex: groupIndex) { overrideIndex in
        guard let overrideIndex = overrideIndex else {
            completion(false, "Impossible de préparer la pause de cette pièce sur le bridge. La couleur n'a pas été envoyée.")
            return
        }
        putOverrideStatus(overrideIndex, status: overrideStatusPaused) { paused in
            guard paused else {
                completion(false, "Impossible de mettre le circadien en pause. La couleur n'a pas été envoyée.")
                return
            }
            let body: [String: Any] = [
                "on": true,
                "hue": min(65535, max(0, hue)),
                "sat": min(254, max(0, sat)),
                "bri": min(254, max(1, bri)),
            ]
            hueRequest(.PUT, "groups/\(groupIndex)/action", body: body) { json in
                if hueSucceeded(json) {
                    completion(true, "Couleur appliquée")
                } else {
                    completion(false, "Circadien en pause, mais la couleur n'a pas pu être envoyée.")
                }
            }
        }
    }
}

/// Resumes the room's circadian and gives back full brightness (the manual colour
/// may have dimmed it; the rules only send ct).
/// - Room on: OVR → 0, then if the global switch is on, sends `ct` (current
///   segment, offset applied) with full brightness right away, with `fade`
///   (deciseconds) as its transitiontime when given — the same as the room's rules.
/// - Room off: OVR → 2, the restore rule applies the brightness at the next
///   switch-on (an off light cannot take a brightness).
/// Completes on main with (success, message).
func resumeCircadian(groupIndex: Int, ct: Int?, fade: Int? = nil, completion: @escaping (Bool, String) -> Void) {
    if demoMode {
        demoPausedRooms.remove(String(groupIndex))
        completion(true, "")
        return
    }
    prepareRoomOverride(groupIndex: groupIndex) { overrideIndex in
        guard let overrideIndex = overrideIndex else {
            completion(false, "Impossible de joindre le capteur de pause de cette pièce.")
            return
        }
        hueRequest(.GET, "groups/\(groupIndex)") { groupJSON in
            let anyOn = ((groupJSON as? [String: Any])?["state"] as? [String: Any])?["any_on"] as? Bool
            // Unknown → treated as on: the brightness is then sent now (best effort).
            let roomOff = anyOn == false
            let status = roomOff ? overrideStatusRestorePending : overrideStatusRunning
            putOverrideStatus(overrideIndex, status: status) { resumed in
                guard resumed else {
                    completion(false, "Impossible de reprendre le circadien.")
                    return
                }
                guard !roomOff else { completion(true, ""); return }
                hueRequest(.GET, "sensors/\(indexGlobalOnOff)") { json in
                    let status = ((json as? [String: Any])?["state"] as? [String: Any])?["status"] as? Int
                    // Global switch off (or unknown): leave the lights as they are.
                    guard status == 0 else { completion(true, ""); return }
                    var body: [String: Any] = ["bri": circadianBrightness]
                    if let ct = ct { body["ct"] = clampMireds(ct) }
                    if let fade = fade { body["transitiontime"] = min(65535, max(0, fade)) }
                    hueRequest(.PUT, "groups/\(groupIndex)/action", body: body) { _ in
                        // Best effort: the next tick applies the ct anyway.
                        completion(true, "")
                    }
                }
            }
        }
    }
}

// MARK: - Room deletion

/// Removes the room's reset / restore rules, OVR sensor(s) and stored index. The segment
/// rules are removed separately (`deleteAllHUEHACKRulesForGroup`). Completes on
/// main with false if anything could not be read or deleted.
func deleteRoomOverride(groupIndex: Int, completion: @escaping (Bool) -> Void) {
    if demoMode {
        demoPausedRooms.remove(String(groupIndex))
        completion(true)
        return
    }
    fetchRawRules { rules in
        let names: Set<String> = [overrideResetRuleName(groupIndex), overrideRestoreRuleName(groupIndex)]
        let ruleIds = (rules ?? [:]).filter { names.contains(resourceName($0.value)) }.compactMap { Int($0.key) }
        // Rules first: they reference the sensor.
        deleteSequentially(.rules, ids: ruleIds) { rulesDeleted in
            fetchRawSensors { sensors in
                let sensorIds = overrideSensorIds(in: sensors ?? [:], groupIndex: groupIndex)
                deleteSequentially(.sensors, ids: sensorIds) { sensorsDeleted in
                    forgetOverrideIndex(groupIndex)
                    completion(rules != nil && sensors != nil && rulesDeleted && sensorsDeleted)
                }
            }
        }
    }
}
