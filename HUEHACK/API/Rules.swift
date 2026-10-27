//
//  Rules.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 05/01/2025.
//
import Foundation

struct Rule: Decodable {
    let name: String
    let owner: String?
    let created: String?
    let lasttriggered: String?
    let timestriggered: Int?
    let status: String?
    let recycle: Bool?
    let conditions: [Condition]?
    let actions: [Action]?
}


struct Condition: Decodable {
    let address: String?
    let `operator`: String?
    let value: String?
}


struct Action: Decodable {
    let address: String
    let method: String
    let body: ActionBody
}

// MARK: - Action Body Structure
// Other keys of a segment action (e.g. `transitiontime`) are ignored by the decoder.
struct ActionBody: Decodable {
    let status: Int?
    let ct: Int?
}

// MARK: - Segment metadata persistence (name + show state + pushed temps, keyed by group)

/// One entry per rule index (`HUEHACK-GG-RR` → entry RR).
/// `baseTemp` / `offset` were added later: optional so metadata saved by older
/// builds still decodes.
private struct SegmentMeta: Codable {
    let name: String
    let show: Bool
    /// Temperature BEFORE the room offset was applied (the shared schedule value).
    var baseTemp: Int? = nil
    /// Room offset (mireds) applied when this schedule was pushed.
    var offset: Int? = nil
    /// Fade (`transitiontime`, deciseconds) sent with this schedule. Nil for meta
    /// saved by builds that sent no transitiontime (bridge default, 0.4 s).
    var fade: Int? = nil
}

func clampMireds(_ value: Int) -> Int {
    min(500, max(153, value))
}

func saveSegmentMeta(segments: [Segment], groupIndex: Int, offset: Int = 0, fade: Int = defaultRoomFade) {
    let meta = segments.map {
        SegmentMeta(name: $0.name, show: $0.show ?? true, baseTemp: $0.temp, offset: offset, fade: fade)
    }
    if let encoded = try? JSONEncoder().encode(meta) {
        UserDefaults.standard.set(encoded, forKey: "huehack-meta-\(String(format: "%02d", groupIndex))")
    }
}

private func loadSegmentMeta(_ groupIndex: Int) -> [SegmentMeta] {
    guard let data = UserDefaults.standard.data(forKey: "huehack-meta-\(String(format: "%02d", groupIndex))"),
          let meta = try? JSONDecoder().decode([SegmentMeta].self, from: data) else { return [] }
    return meta
}

/// Offset (mireds) used the last time this app pushed rules for this group,
/// or nil if unknown (nothing pushed yet, or pushed by an older build).
func lastPushedOffset(groupIndex: Int) -> Int? {
    loadSegmentMeta(groupIndex).first?.offset
}

/// Fade (deciseconds) used the last time this app pushed rules for this group, or
/// nil if nothing was pushed. Meta from builds without fade → the bridge default
/// (those rules carried no transitiontime).
func lastPushedFade(groupIndex: Int) -> Int? {
    guard let first = loadSegmentMeta(groupIndex).first else { return nil }
    return first.fade ?? defaultRoomFade
}

/// Parses `HUEHACK-<group>-<rule>` structurally (works for any number of digits,
/// so group 100 no longer collides with group 10). Returns nil for any other name,
/// including HUEHACK's own non-segment rules (e.g. `HUEHACK-HEARTBEAT`, and
/// `HUEHACK-OVRRESET-<g>`: "OVRRESET" is not a number), so per-group deletes and
/// read-backs never touch the pause reset rule.
func parseHUEHACKRuleName(_ name: String) -> (group: Int, rule: Int)? {
    let parts = name.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0] == "HUEHACK",
          let group = Int(parts[1]), let rule = Int(parts[2]) else { return nil }
    return (group, rule)
}


func decodeOneRuleResponse(jsonData: Data) -> Rule? {
    do {
        let decoder = JSONDecoder()
        let rule = try decoder.decode(Rule.self, from: jsonData)
        return rule
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}

func decodeRulesResponse(jsonData: Data) -> [String:Rule]? {
    do {
        let decoder = JSONDecoder()
        let rules = try decoder.decode([String:Rule].self, from: jsonData)
        return rules
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}


/// Always calls `completion` on the main queue: the rules on success, nil on any
/// failure (invalid URL, network error, bridge error payload, decode failure).
func sendGETRules(ip: String, which: String?, completion: @escaping ([String: Rule]?) -> Void) {
    func finish(_ result: [String: Rule]?) {
        DispatchQueue.main.async { completion(result) }
    }

    guard let url = URL(string: "http://\(ip)/api/\(username)/rules/\(which ?? "")") else {
        print("Invalid URL")
        finish(nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.GET.rawValue

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            finish(nil)
        }
        else if let data = data {
            if let which = which {
                if let rule = decodeOneRuleResponse(jsonData: data) {
                    finish([which: rule])
                } else {
                    print("Failed to decode response")
                    finish(nil)
                }
            }
            else {
                if let rules = decodeRulesResponse(jsonData: data) {
                    finish(rules)
                }
                else {
                    print("Failed to decode response")
                    finish(nil)
                }
            }
        }
        else {
            print("Unknown error")
            finish(nil)
        }
    }.resume()
}


/// Success message returned by `createRulesFromlistOfSegments`. Callers test for
/// `"correctly"` — keep that word in it.
let rulesSentSuccessMessage = "All rules were correctly sent"

/// Replaces the group's HUEHACK rules with one rule per segment.
/// - `listOfSegments`: the BASE schedule (without room offset), sorted circularly.
/// - `offset`: room offset in mireds, applied here as `clamp(temp + offset)`. The
///   base temps and the offset are stored in the group's segment meta so the
///   read-back (`getSegmentFromRulesForGroup`) can return the exact base schedule,
///   even where the clamp lost information.
/// Completes on main with `rulesSentSuccessMessage` on success, otherwise an error
/// string (which never contains "correctly"). If the existing rules cannot be
/// read or deleted, nothing is posted.
/// Each rule also checks the room's pause sensor (`HUEHACK-OVR-<g>`, found or
/// created here, its status left untouched: a paused room stays paused). If that
/// sensor cannot be obtained, the rules are posted without the pause condition.
/// - `fade`: `transitiontime` (deciseconds) sent with every ct, remembered in the
///   meta like the offset (`lastPushedFade`).
func createRulesFromlistOfSegments(listOfSegments: [Segment], indexGroup: Int, offset: Int = 0, fade: Int = defaultRoomFade, completion: @escaping (String) -> Void) {
    deleteAllHUEHACKRulesForGroup(indexGroup: indexGroup) { deleted in
        guard deleted else {
            completion("Erreur : impossible de lire ou supprimer les règles existantes du bridge. Rien n'a été envoyé.")
            return
        }

        ensureOverrideSensor(groupIndex: indexGroup) { indiceOverride in
            if indiceOverride == nil {
                print("HUEHACK: no pause sensor for group \(indexGroup) — rules posted without the pause condition")
            }
            let indiceGlobalOnOff = indexGlobalOnOff
            let indiceTimer = indexTimer
            var failedRules = [String]()
            var bridgeErrors = [String]()

            func finish() {
                DispatchQueue.main.async {
                    saveSegmentMeta(segments: listOfSegments, groupIndex: indexGroup, offset: offset, fade: fade)
                    if failedRules.isEmpty {
                        completion(rulesSentSuccessMessage)
                    } else {
                        var message = "Erreur sur les règles : \(failedRules.joined(separator: ", "))"
                        if !bridgeErrors.isEmpty { message += "\nBridge : \(bridgeErrors.joined(separator: " / "))" }
                        completion(message)
                    }
                }
            }

            // Posted one after the other: ~11 parallel POSTs can overload the bridge.
            func postNext(_ indice: Int) {
                guard indice < listOfSegments.count else {
                    guard let indiceOverride = indiceOverride else {
                        finish()
                        return
                    }
                    // Auto-resume when the room is switched off (best effort).
                    ensureOverrideResetRule(groupIndex: indexGroup, overrideIndex: indiceOverride) { ok in
                        if !ok { print("HUEHACK: reset rule not installed for group \(indexGroup)") }
                        finish()
                    }
                    return
                }
                let nextIndex = (indice + 1) % listOfSegments.count
                sendPOSTRuleRequest(ip: ip,
                                    start: listOfSegments[indice].hourStart,
                                    end: listOfSegments[nextIndex].hourStart,
                                    temp: clampMireds(listOfSegments[indice].temp + offset),
                                    indexGroup: indexGroup,
                                    indexRègle: indice,
                                    indexTimer: indiceTimer,
                                    indexGobalOnOff: indiceGlobalOnOff,
                                    indexOverride: indiceOverride,
                                    transitionTime: fade) { response in
                    if !response.contains("\"success\"") {
                        failedRules.append(String(format: "%02d", indice))
                        print("HUEHACK: rule \(indice) rejected: \(response)")
                        let detail = bridgeErrorDescription(response)
                        if !bridgeErrors.contains(detail) { bridgeErrors.append(detail) }
                    }
                    postNext(indice + 1)
                }
            }

            postNext(0)
        }
    }
}

/// Readable summary of a bridge reply (`[{"error":{"type":…,"description":…}}]`),
/// or the raw reply (network error text…) when it is not one.
func bridgeErrorDescription(_ response: String) -> String {
    guard let data = response.data(using: .utf8),
          let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return String(response.prefix(200))
    }
    let errors = items.compactMap { $0["error"] as? [String: Any] }.map { error in
        "\(error["description"] as? String ?? "?") (type \(error["type"] as? Int ?? 0))"
    }
    return errors.isEmpty ? String(response.prefix(200)) : errors.joined(separator: " / ")
}

/// `indexOverride`: the room's pause sensor. When given, the rule gets a 4th
/// condition `/sensors/<ovr>/state/status eq 0`; nil keeps the 3-condition rule.
/// `transitionTime`: deciseconds, added to the action body next to `ct`; nil sends
/// `ct` alone (bridge default 0.4 s).
func sendPOSTRuleRequest(ip: String, start: DateComponents, end: DateComponents, temp: Int, indexGroup:Int, indexRègle: Int, indexTimer: Int, indexGobalOnOff: Int, indexOverride: Int? = nil, transitionTime: Int? = nil, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/rules") else {
        print("Invalid URL")
        completion("Invalid URL")
        return
    }

     var request = URLRequest(url: url)
     request.httpMethod = "POST"

    let hourStartString = String(format: "%02d", start.hour ?? 0)
    let minStartString = String(format: "%02d", start.minute ?? 0)

    var hourEndString = ""
    if end.minute == 0 {
        hourEndString = String(format: "%02d", ( (end.hour ?? 0) - 1 + 24 ) % 24 )
    }
    else {
        hourEndString = String(format: "%02d", ( (end.hour ?? 0) + 24 ) % 24 )
    }

    let minEndString = String(format: "%02d", ((end.minute ?? 0)  - 1 + 60 ) % 60 )

    let indexGroupString = String(format: "%02d", indexGroup)
    let indexRègleString = String(format: "%02d", indexRègle)

    // Per-room pause: the rule only fires while the room's OVR sensor is 0.
    var overrideCondition = ""
    if let indexOverride = indexOverride {
        overrideCondition = """
        ,
                        {
                            "address": "/sensors/\(indexOverride)/state/status",
                            "operator": "eq",
                            "value": "0"
                        }
        """
    }

    // Compact on purpose: the bridge measures the action body as raw text and
    // rejects it ("too big for parameter, body", type 7) once indentation is added.
    var actionBody = "{\"ct\":\(temp)"
    if let transitionTime = transitionTime {
        actionBody += ",\"transitiontime\":\(min(65535, max(0, transitionTime)))"
    }
    actionBody += "}"

    let body = """
    {
            "name": "HUEHACK-\(indexGroupString)-\(indexRègleString)",
            "conditions": [
                {
                    "address": "/sensors/\(indexTimer)/state/lastupdated",
                    "operator": "ddx",
                    "value": "PT00:00:05"
                },
                {
                    "address": "/config/localtime",
                    "operator": "in",
                    "value": "T\(hourStartString):\(minStartString):00/T\(hourEndString):\(minEndString):59"
                },
                {
                    "address": "/sensors/\(indexGobalOnOff)/state/status",
                    "operator": "eq",
                    "value": "0"
                }\(overrideCondition)
            ],
            "actions": [
                {
                    "address": "/groups/\(indexGroup)/action",
                    "method": "PUT",
                    "body": \(actionBody)
                }
            ]
        }
    """

    if let jsonDataBody = body.data(using: .utf8) {
        request.httpBody = jsonDataBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

     URLSession.shared.dataTask(with: request) { data, response2, error in
         if let error = error {
             completion(error.localizedDescription)
         } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
             completion(responseString)
         } else {
             completion("Unknown error")
         }
     }.resume()
 }



func checkRulesIndex() -> [String: String] {
    var results: [String: String] = [:]

    sendGETRules(ip: ip, which: nil) { response in
        guard let response = response else { return }
        for rulesTuple in response {
            if rulesTuple.1.name.prefix(7) == "HUEHACK" {
                let name = String(rulesTuple.1.name.dropFirst(10))

                if name == "TIMER" || name == "GLOBAL ONOFF" {
                    results[name] = rulesTuple.0
                    print("\(name) - \(rulesTuple.0)")
                }
            }
        }
    }
    return results
}

/// Completes on main with the group's HUEHACK segment rules (keyed by bridge rule id),
/// or nil if the rules could not be read.
func getRulesAndFilterByGroup(group: Int, completion: @escaping ([String: Rule]?) -> Void) {
    sendGETRules(ip: ip, which: nil) { response in
        guard let response = response else {
            completion(nil)
            return
        }
        let results = response.filter { parseHUEHACKRuleName($0.value.name)?.group == group }
        completion(results)
    }
}


func deleteAllHUEHACKRules(completion: @escaping () -> Void) {
    sendGETRules(ip: ip, which: nil) { response in
        let indexesOfHUEHACKRules = (response ?? [:])
            .filter { $0.value.name.hasPrefix("HUEHACK") }
            .compactMap { Int($0.key) }

        let group = DispatchGroup()

        for index in indexesOfHUEHACKRules {
            group.enter()
            sendDELETERequest(ip: ip, what: TypeWhat.rules, which: index) { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }
}


/// Deletes the group's HUEHACK segment rules. Completes on main with false if the
/// rules could not be read or any delete failed (posting new rules on top would
/// leave duplicates on the bridge).
func deleteAllHUEHACKRulesForGroup(indexGroup: Int, completion: @escaping (Bool) -> Void) {
    // Raw read: one rule the Decodable model cannot parse must not block the push.
    fetchRawRules { rules in
        guard let rules = rules else {
            completion(false)
            return
        }
        let ids = rules.compactMap { key, rule -> Int? in
            guard parseHUEHACKRuleName(rule["name"] as? String ?? "")?.group == indexGroup else { return nil }
            return Int(key)
        }

        var allDeleted = true
        let lock = NSLock()
        let group = DispatchGroup()

        for index in ids {
            group.enter()
            sendDELETERequest(ip: ip, what: TypeWhat.rules, which: index) { response in
                if !response.contains("\"success\"") {
                    lock.lock(); allDeleted = false; lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(allDeleted)
        }
    }
}


/// Converts one HUEHACK segment rule to a Segment named `GG-RR`.
/// Returns nil for malformed rules instead of crashing.
func segmentFromRule(rule: Rule) -> Segment? {
    guard let parsed = parseHUEHACKRuleName(rule.name) else { return nil }
    let name = String(format: "%02d-%02d", parsed.group, parsed.rule)

    guard let conditions = rule.conditions,
          let timeCondition = conditions.first(where: { $0.address == "/config/localtime" })
                ?? (conditions.count > 1 ? conditions[1] : nil),
          let time = timeCondition.value,
          let start = time.split(separator: "/").first?.dropFirst(1) else { return nil }

    let timeFormatted = start.split(separator: ":")
    guard timeFormatted.count >= 2,
          let hour = Int(timeFormatted[0]), let minute = Int(timeFormatted[1]) else { return nil }

    // Found by address, like the time condition: the group action carrying a ct.
    guard let temp = rule.actions?.first(where: { $0.address.hasSuffix("/action") && $0.body.ct != nil })?.body.ct
    else { return nil }

    return Segment(name: name, hourStart: DateComponents(hour: hour, minute: minute), temp: temp, synced: .synced)
}


func createSegmentFor(listOfSegments: [Segment], time: DateComponents) {
    // TO BE CONTINUED
}

func createSegmentForNow(listOfSegments: inout [Segment]) {
    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())

    var currentTemp = 200
    var listOfSegmentsTemp = listOfSegments

    for i in listOfSegments.indices {

        if listOfSegments.indices.contains(i+1) {
            let h1 = listOfSegments[i].hourStart.hour ?? 0
            let m1 = listOfSegments[i].hourStart.minute ?? 0
            let h2 = listOfSegments[i+1].hourStart.hour ?? 0
            let m2 = listOfSegments[i+1].hourStart.minute ?? 0
            let hn = now.hour ?? 0
            let mn = now.minute ?? 0
            if (h1, m1) < (hn, mn) && (hn, mn) < (h2, m2) {
                currentTemp = listOfSegments[i].temp
            }
        } else {
            let h1 = listOfSegments[i].hourStart.hour ?? 0
            let m1 = listOfSegments[i].hourStart.minute ?? 0
            let h2 = listOfSegments[0].hourStart.hour ?? 0
            let m2 = listOfSegments[0].hourStart.minute ?? 0
            let hn = now.hour ?? 0
            let mn = now.minute ?? 0
            if (h1, m1) < (hn, mn) && (hn, mn) < (h2, m2) {
                currentTemp = listOfSegments[i].temp
            }
        }
    }

    let newSegment = Segment(name: "", hourStart: now, temp: currentTemp, synced: .notSynced)
    listOfSegmentsTemp = listOfSegments + [newSegment]
    listOfSegmentsTemp = listOfSegmentsTemp.sorted {
        if $0.hourStart.hour! == $1.hourStart.hour! {
            return $0.hourStart.minute! < $1.hourStart.minute!
        }
        return $0.hourStart.hour! < $1.hourStart.hour!
    }
    listOfSegmentsTemp.append(listOfSegmentsTemp.removeFirst())
    listOfSegments = listOfSegmentsTemp
}


/// Reads the group's rules back as the BASE schedule (room offset removed).
/// - If the stored meta has the pushed base temp and `clamp(base + pushedOffset)`
///   still equals the bridge temp, the base temp is returned as-is (lossless even
///   when the clamp saturated).
/// - Otherwise falls back to `clamp(bridgeTemp - offset)`, with the offset stored
///   at push time, or `legacyOffset` for rules pushed by an older build.
/// Completes on main with nil if the rules could not be read.
func getSegmentFromRulesForGroup(selectedGroupIndex: Int, legacyOffset: Int = 0, completion: @escaping ([Segment]?) -> Void) {
    let meta = loadSegmentMeta(selectedGroupIndex)

    getRulesAndFilterByGroup(group: selectedGroupIndex) { filteredRules in
        guard let filteredRules = filteredRules else {
            completion(nil)
            return
        }

        var listOfSegmentsTemp = [Segment]()

        for rule in filteredRules.values {
            guard var segment = segmentFromRule(rule: rule),
                  let ruleIdx = parseHUEHACKRuleName(rule.name)?.rule else { continue }

            let entry: SegmentMeta? = (ruleIdx >= 0 && ruleIdx < meta.count) ? meta[ruleIdx] : nil
            if let entry = entry {
                segment.name = entry.name
                segment.show = entry.show
            }

            let bridgeTemp = segment.temp
            let offset = entry?.offset ?? legacyOffset
            if let base = entry?.baseTemp, let metaOffset = entry?.offset,
               clampMireds(base + metaOffset) == bridgeTemp {
                segment.temp = base
            } else if offset != 0 {
                segment.temp = clampMireds(bridgeTemp - offset)
            }

            listOfSegmentsTemp.append(segment)
        }

        completion(sortedCircular(listOfSegmentsTemp))
    }
}

// MARK: - Solar merge

/// Circular order: hours before 3am sort after the evening ones.
func solarSortKey(_ s: Segment) -> Int {
    let h = s.hourStart.hour ?? 0
    return (h < 3 ? h + 24 : h) * 60 + (s.hourStart.minute ?? 0)
}

func sortedCircular(_ segments: [Segment]) -> [Segment] {
    segments.sorted { solarSortKey($0) < solarSortKey($1) }
}

func mergeSegmentsWithSolar(bridgeSegments: [Segment], locationManager: LocationManager) -> [Segment] {
    let solar = fillListOfSegments(locationManager: locationManager)
    let solarNames = Set(solar.map { $0.name })

    if bridgeSegments.contains(where: { solarNames.contains($0.name) }) {
        var result = [Segment]()
        for solarSeg in solar {
            if let bridge = bridgeSegments.first(where: { $0.name == solarSeg.name }) {
                let hourDiffers = bridge.hourStart.hour != solarSeg.hourStart.hour
                    || bridge.hourStart.minute != solarSeg.hourStart.minute
                var merged = bridge
                merged.newHourStart = solarSeg.hourStart
                merged.hourChanged = hourDiffers
                result.append(merged)
            } else {
                result.append(solarSeg)
            }
        }
        for bridge in bridgeSegments where !solarNames.contains(bridge.name) {
            result.append(bridge)
        }
        return result
    }

    // Positional fallback: assign solar names to unnamed bridge segments
    let sortedBridge = bridgeSegments.sorted { solarSortKey($0) < solarSortKey($1) }
    let sortedSolar = solar.sorted { solarSortKey($0) < solarSortKey($1) }
    var result = [Segment]()
    for (i, solarSeg) in sortedSolar.enumerated() {
        if i < sortedBridge.count {
            let bridge = sortedBridge[i]
            let hourDiffers = bridge.hourStart.hour != solarSeg.hourStart.hour
                || bridge.hourStart.minute != solarSeg.hourStart.minute
            var merged = bridge
            merged.name = solarSeg.name
            merged.show = solarSeg.show
            merged.newHourStart = solarSeg.hourStart
            merged.hourChanged = hourDiffers
            result.append(merged)
        } else {
            result.append(solarSeg)
        }
    }
    return result
}
