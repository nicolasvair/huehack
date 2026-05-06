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


func decodeOneRuleResponse(jsonData: Data) -> Rule? {
//    print(String(data: jsonData, encoding: .utf8) ?? "Invalid UTF-8 data")

    do {
        let decoder = JSONDecoder()
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rule = try decoder.decode(Rule.self, from: jsonData)

        return rule
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}

func decodeRulesResponse(jsonData: Data) -> [String:Rule]? {
//    print(String(data: jsonData, encoding: .utf8) ?? "Invalid UTF-8 data")

    do {
        let decoder = JSONDecoder()
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
            //            completion(error.localizedDescription)
        }
        else if let data = data {
            
            // when a specific rule is get
            if let which = which {
                if let rule = decodeOneRuleResponse(jsonData: data) {
                    //                    print(rule.name)
                    let result = [which:rule]
                    completion(result)
                } else {
                    print("Failed to decode response")
                }
            }
            //if not, all rules, then decode all rules
            else {
                if let rules = decodeRulesResponse(jsonData: data) {
//                    var result = " ----- RULES ----- \n"
//                    
//                    for rule in rules {
//                        if let name = rule.1.name {
//                            result += "\(rule.0) - \(name) \n"
//                        } else {
//                            result += "\(rule.0) - \(rule.1.name) - \n"
//                        }
//                    }
//                    print(result)
                    
                    completion(rules)
                }
                else {
                    print("Unknown error")
                }
            }
        }
    }.resume()
}


// ICI
/*
func createRulesFromlistOfSegments(listOfSegments: [Segment], indexGroup: Int, completion: @escaping ([String]) -> Void) {
    deleteAllHUEHACKRulesForGroup(indexGroup: indexGroup) {
        let indiceGlobalOnOff = 171
        let indiceTimer = 172
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
            sendPUTSensors(ip: ip, indexSensor: indiceTimer, state: 0) { response in
                print(response)
            }
            completion(responsesFromPost)
        }
    }
}
 */

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
            // Analyze responses
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
    
//    print("group : \(indexGroupString) - index : \(indexRègleString) - start : \(hourStartString):\(minStartString):00 - end : \(hourEndString):\(minEndString):59 ")

    
    // old value
    /*
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
                    "address": "/sensors/\(indexTimer)/state",
                    "method": "PUT",
                    "body": {
                        "status": 0
                    }
                },
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
     */
    
    
    
    // new value
    // should add som sort of initializer for the 
    
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
//             print("Error: \(error.localizedDescription)")
             completion(error.localizedDescription)
         } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
//             print("Response: \(responseString)")
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
        
//        print("Rules nb : \(results)")
    }
    return results
}

func getRulesAndFilterByGroup(group: Int, completion: @escaping ([String: Rule]) -> Void) {
    var results: [String: Rule] = [:]

    sendGETRules(ip: ip, which: nil) { response in
        for rulesTuple in response {
            if rulesTuple.1.name.prefix(7) == "HUEHACK" {
                let name = String(rulesTuple.1.name.dropFirst(8))
//                print(name)
                if name.prefix(2) == String(format: "%02d", group){
//                    print(rulesTuple.1.name)
                    results[rulesTuple.0] = rulesTuple.1
                }
            }
        }
        completion(results)
//        print("Rules nb : \(results)")
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
            group.enter() // Entrer dans le groupe
            sendDELETERequest(ip: ip, what: TypeWhat.rules, which: Int(index)!) { _ in
                group.leave() // Quitter le groupe une fois la requête terminée
            }
        }

        // Appeler le `completion` une fois que toutes les suppressions sont terminées
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
//                    print(rulesTuple.1.name.dropFirst(8).prefix(2))
                    indexesOfHUEHACKRules.append(rulesTuple.0)
                }
            }
        }

        let group = DispatchGroup()

        for index in indexesOfHUEHACKRules {
            group.enter() // Entrer dans le groupe
            sendDELETERequest(ip: ip, what: TypeWhat.rules, which: Int(index)!) { _ in
                group.leave() // Quitter le groupe une fois la requête terminée
            }
        }

        // Appeler le `completion` une fois que toutes les suppressions sont terminées
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
//        print(dateComponents)
        
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
    
//    listOfSegmentsTemp = listOfSegmentsTemp.sorted{ $0.hourStart.hour! < $1.hourStart.hour! }
    
    for i in listOfSegments.indices {
        
        if listOfSegments.indices.contains(i+1) {
            
            if let hour1 = listOfSegments[i].hourStart.hour, let minute1 = listOfSegments[i].hourStart.minute, let hour2 = listOfSegments[i+1].hourStart.hour, let minute2 = listOfSegments[i+1].hourStart.minute, let hourNow = now.hour, let minuteNow = now.minute, (hour1, minute1) < (hourNow, minuteNow) && (hourNow, minuteNow) < (hour2, minute2)  {
                
                print("now entre \(listOfSegments[i].hourStart) et \(listOfSegments[i+1].hourStart)")
                
                currentTemp = listOfSegments[i].temp
            }
        }
        else {
            if let hour1 = listOfSegments[i].hourStart.hour, let minute1 = listOfSegments[i].hourStart.minute, let hour2 = listOfSegments[0].hourStart.hour, let minute2 = listOfSegments[0].hourStart.minute, let hourNow = now.hour, let minuteNow = now.minute, (hour1, minute1) < (hourNow, minuteNow) && (hourNow, minuteNow) < (hour2, minute2) {
                
                print("now entre \(listOfSegments[i].hourStart) et \(listOfSegments[0].hourStart)")
                
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
    
    getRulesAndFilterByGroup(group: selectedGroupIndex) { filteredRules in
                
        var listOfSegmentsTemp = [Segment]()
        
        for rule in filteredRules {
            if let segment = segmentFromRule(rule: rule.1) {
                listOfSegmentsTemp.append(segment)
            }
        }
        
        // Tri des segments et déplacement du premier à la fin
        listOfSegmentsTemp = listOfSegmentsTemp.sorted {
            if $0.hourStart.hour! == $1.hourStart.hour! {
                return $0.hourStart.minute! < $1.hourStart.minute!
            }
            return $0.hourStart.hour! < $1.hourStart.hour!
        }
        listOfSegmentsTemp.append(listOfSegmentsTemp.removeFirst())
        
        completion(listOfSegmentsTemp)
    }
}
