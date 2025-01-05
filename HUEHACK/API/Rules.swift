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

func createRulesFromlistOfSegments(listOfSegments: [Segment]) {
    deleteAllHUEHACKRules {
        let indiceGlobalOnOff = 171
        let indiceTimer = 172
        let indexGroup = 2

        for indice in listOfSegments.indices {
            if listOfSegments.indices.contains(indice + 1) {
                sendPOSTRuleRequest(ip: ip, start: listOfSegments[indice].hourStart, end: listOfSegments[indice + 1].hourStart, temp: listOfSegments[indice].temp, indexGroup: indexGroup, indexRègle: indice, indexTimer: indiceTimer, indexGobalOnOff: indiceGlobalOnOff) { response in
//                    print(response)
                }
            } else {
                sendPOSTRuleRequest(ip: ip, start: listOfSegments[indice].hourStart, end: listOfSegments[0].hourStart, temp: listOfSegments[indice].temp, indexGroup: indexGroup, indexRègle: indice, indexTimer: indiceTimer, indexGobalOnOff: indiceGlobalOnOff) { response in
//                    print(response)
                }
            }
        }
        
        sendPUTSensors(ip: ip, indexSensor: indexTimer, state: 0) { response in
            print(response)
        }
    }
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

    let hourEndString = String(format: "%02d", (end.hour ?? 0  - 1 + 24 ) % 24 )
    let minEndString = String(format: "%02d", (end.minute ?? 0  - 1 + 60 ) % 60 )

    let body = """
    {
            "name": "HUEHACK-\(indexGroup)-\(indexRègle)",
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

    
    if let jsonDataBody = body.data(using: .utf8) {
        request.httpBody = jsonDataBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    


     URLSession.shared.dataTask(with: request) { data, response2, error in
         if let error = error {
             print("Error: \(error.localizedDescription)")
             completion(error.localizedDescription)
         } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
             print("Response: \(responseString)")
             completion(responseString)
         }
     }.resume()
 }



func checkRulesNb() -> [String: String] {
    var results: [String: String] = [:]

    sendGETRules(ip: ip, which: nil) { response in
        for rulesTuple in response {
            if rulesTuple.1.name.prefix(7) == "HUEHACK" {
                let name = String(rulesTuple.1.name.dropFirst(10))
                print("\(name) - \(rulesTuple.0)")

                // WORK HERE
                
//                if name == "TIMER" || name == "GLOBAL ONOFF" {
//                    results[name] = rulesTuple.0
//                    print("\(name) - \(rulesTuple.0)")
//                }
            }
        }
        
//        print("Rules nb : \(results)")
    }
    return results
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
