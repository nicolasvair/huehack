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
struct ActionBody: Decodable {
    let status: Int?
    let ct: Int?
}

// MARK: - Segment metadata persistence (name + show state, keyed by group)

private struct SegmentMeta: Codable {
    let name: String
    let show: Bool
}

func saveSegmentMeta(segments: [Segment], groupIndex: Int) {
    let meta = segments.map { SegmentMeta(name: $0.name, show: $0.show ?? true) }
    if let encoded = try? JSONEncoder().encode(meta) {
        UserDefaults.standard.set(encoded, forKey: "huehack-meta-\(String(format: "%02d", groupIndex))")
    }
}

private func loadSegmentMeta(_ groupIndex: Int) -> [SegmentMeta] {
    guard let data = UserDefaults.standard.data(forKey: "huehack-meta-\(String(format: "%02d", groupIndex))"),
          let meta = try? JSONDecoder().decode([SegmentMeta].self, from: data) else { return [] }
    return meta
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


func sendGETRules(ip: String, which: String?, completion: @escaping ([String: Rule]) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/rules/\(which ?? "")") else {
        print("Invalid URL")
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.GET.rawValue

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        else if let data = data {
            if let which = which {
                if let rule = decodeOneRuleResponse(jsonData: data) {
                    let result = [which:rule]
                    completion(result)
                } else {
                    print("Failed to decode response")
                }
            }
            else {
                if let rules = decodeRulesResponse(jsonData: data) {
                    completion(rules)
                }
                else {
                    print("Unknown error")
                }
            }
        }
    }.resume()
}


func createRulesFromlistOfSegments(listOfSegments: [Segment], indexGroup: Int, completion: @escaping (String) -> Void) {
    deleteAllHUEHACKRulesForGroup(indexGroup: indexGroup) {
        let indiceGlobalOnOff = indexGlobalOnOff
        let indiceTimer = indexTimer
        var responsesFromPost = [String]()
        let dispatchGroup = DispatchGroup()

        for indice in listOfSegments.indices {
            dispatchGroup.enter()
            let nextIndex = (indice + 1) % listOfSegments.count
            sendPOSTRuleRequest(ip: ip,
                                 start: listOfSegments[indice].hourStart,
                                 end: listOfSegments[nextIndex].hourStart,
                                 temp: listOfSegments[indice].temp,
                                 indexGroup: indexGroup,
                                 indexRègle: indice,
                                 indexTimer: indiceTimer,
                                 indexGobalOnOff: indiceGlobalOnOff) { response in
                responsesFromPost.append(response)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            saveSegmentMeta(segments: listOfSegments, groupIndex: indexGroup)

            var errors = [String]()
            for response in responsesFromPost {
                if !response.contains("\"success\"") {
                    if let id = extractID(from: response) {
                        errors.append(id)
                    } else {
                        errors.append("Unknown ID")
                    }
                }
            }

            if errors.isEmpty {
                completion("All rules were correctly sent")
            } else {
                completion("Error at IDs: \(errors.joined(separator: ", "))")
            }
        }
    }
}

// Helper function to extract the ID from the response
private func extractID(from response: String) -> String? {
    if let startRange = response.range(of: "\"id\":\""),
       let endRange = response[startRange.upperBound...].range(of: "\"") {
        return String(response[startRange.upperBound..<endRange.lowerBound])
    }
    return nil
}

func sendPOSTRuleRequest(ip: String, start: DateComponents, end: DateComponents, temp: Int, indexGroup:Int, indexRègle: Int, indexTimer: Int, indexGobalOnOff: Int, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/rules") else {
         print("Invalid URL")
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
                }
            ],
            "actions": [
                {
                    "address": "/groups/\(indexGroup)/action",
                    "method": "PUT",
                    "body": {
                        "ct": \(temp)
                    }
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
         }
     }.resume()
 }



func checkRulesIndex() -> [String: String] {
    var results: [String: String] = [:]

    sendGETRules(ip: ip, which: nil) { response in
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

func getRulesAndFilterByGroup(group: Int, completion: @escaping ([String: Rule]) -> Void) {
    var results: [String: Rule] = [:]

    sendGETRules(ip: ip, which: nil) { response in
        for rulesTuple in response {
            if rulesTuple.1.name.prefix(7) == "HUEHACK" {
                let name = String(rulesTuple.1.name.dropFirst(8))
                if name.prefix(2) == String(format: "%02d", group){
                    results[rulesTuple.0] = rulesTuple.1
                }
            }
        }
        completion(results)
    }
}


func deleteAllHUEHACKRules(completion: @escaping () -> Void) {
    var indexesOfHUEHACKRules = [String]()

    sendGETRules(ip: ip, which: nil) { response in
        for rulesTuple in response {
            if rulesTuple.1.name.prefix(7) == "HUEHACK" {
                indexesOfHUEHACKRules.append(rulesTuple.0)
            }
        }

        let group = DispatchGroup()

        for index in indexesOfHUEHACKRules {
            group.enter()
            sendDELETERequest(ip: ip, what: TypeWhat.rules, which: Int(index)!) { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }
}


func deleteAllHUEHACKRulesForGroup(indexGroup: Int, completion: @escaping () -> Void) {
    var indexesOfHUEHACKRules = [String]()

    sendGETRules(ip: ip, which: nil) { response in
        for rulesTuple in response {
            if rulesTuple.1.name.prefix(7) == "HUEHACK" {
                if rulesTuple.1.name.dropFirst(8).prefix(2) == String(format: "%02d", indexGroup) {
                    indexesOfHUEHACKRules.append(rulesTuple.0)
                }
            }
        }

        let group = DispatchGroup()

        for index in indexesOfHUEHACKRules {
            group.enter()
            sendDELETERequest(ip: ip, what: TypeWhat.rules, which: Int(index)!) { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }
}


func segmentFromRule(rule: Rule) -> Segment? {

    let name = String(rule.name.dropFirst(8))

    if let time = rule.conditions![1].value {

        let timeFormatted = time.split(separator: "/")[0].dropFirst(1).split(separator: ":")
        let hourStart = DateComponents(hour: Int(timeFormatted[0]) ?? 0, minute: Int(timeFormatted[1]) ?? 0)

        if let temp = rule.actions![0].body.ct {
            return Segment(name: name, hourStart: hourStart, temp: temp, synced: .synced)
        }
    }

    return nil
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
            if let hour1 = listOfSegments[i].hourStart.hour, let minute1 = listOfSegments[i].hourStart.minute, let hour2 = listOfSegments[i+1].hourStart.hour, let minute2 = listOfSegments[i+1].hourStart.minute, let hourNow = now.hour, let minuteNow = now.minute, (hour1, minute1) < (hourNow, minuteNow) && (hourNow, minuteNow) < (hour2, minute2)  {
                currentTemp = listOfSegments[i].temp
            }
        }
        else {
            if let hour1 = listOfSegments[i].hourStart.hour, let minute1 = listOfSegments[i].hourStart.minute, let hour2 = listOfSegments[0].hourStart.hour, let minute2 = listOfSegments[0].hourStart.minute, let hourNow = now.hour, let minuteNow = now.minute, (hour1, minute1) < (hourNow, minuteNow) && (hourNow, minuteNow) < (hour2, minute2) {
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


func getSegmentFromRulesForGroup(selectedGroupIndex: Int, completion: @escaping ([Segment]) -> Void) {
    let meta = loadSegmentMeta(selectedGroupIndex)

    getRulesAndFilterByGroup(group: selectedGroupIndex) { filteredRules in
        var listOfSegmentsTemp = [Segment]()

        for rule in filteredRules {
            if var segment = segmentFromRule(rule: rule.1) {
                let parts = segment.name.split(separator: "-")
                if parts.count == 2, let ruleIdx = Int(parts[1]), ruleIdx < meta.count {
                    segment.name = meta[ruleIdx].name
                    segment.show = meta[ruleIdx].show
                }
                listOfSegmentsTemp.append(segment)
            }
        }

        listOfSegmentsTemp = listOfSegmentsTemp.sorted {
            let h0 = ($0.hourStart.hour! < 3 ? $0.hourStart.hour! + 24 : $0.hourStart.hour!) * 60 + ($0.hourStart.minute ?? 0)
            let h1 = ($1.hourStart.hour! < 3 ? $1.hourStart.hour! + 24 : $1.hourStart.hour!) * 60 + ($1.hourStart.minute ?? 0)
            return h0 < h1
        }

        completion(listOfSegmentsTemp)
    }
}

// MARK: - Solar merge

private func solarSortKey(_ s: Segment) -> Int {
    let h = s.hourStart.hour ?? 0
    return (h < 3 ? h + 24 : h) * 60 + (s.hourStart.minute ?? 0)
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
