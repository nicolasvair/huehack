//
//  Groups.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 05/01/2025.
//

import Foundation

struct RoomResponse: Codable, Hashable {
    let name: String
    let lights: [String]
    let sensors: [String]
    let type: String
    let state: RoomState
    let recycle: Bool
    let `class`: String
    let action: RoomAction
    let stream: StreamInfo? // Optional, present in some rooms
    let locations: [String: [Double]]? // Optional, present in some rooms
}

struct RoomState: Codable, Hashable {
    let allOn: Bool
    let anyOn: Bool

    enum CodingKeys: String, CodingKey {
        case allOn = "all_on"
        case anyOn = "any_on"
    }
}

struct RoomAction: Codable, Hashable  {
    let on: Bool
    let bri: Int
    let hue: Int?
    let sat: Int?
    let effect: String?
    let xy: [Double]?
    let ct: Int?
    let alert: String
    let colormode: String?
}

struct StreamInfo: Codable, Hashable {
    let proxymode: String
    let proxynode: String
    let active: Bool
    let owner: String?
}


// Fonction pour décoder le JSON
func decodeOneGroupResponse(jsonData: Data) -> RoomResponse? {
//    print(String(data: jsonData, encoding: .utf8) ?? "Invalid UTF-8 data")

    do {
        let decoder = JSONDecoder()
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let group = try decoder.decode(RoomResponse.self, from: jsonData)

        return group
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}



func decodeGroupsResponse(jsonData: Data) -> [String: RoomResponse]? {
//    print(String(data: jsonData, encoding: .utf8) ?? "Invalid UTF-8 data")

    do {
        let decoder = JSONDecoder()
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let groups = try decoder.decode([String: RoomResponse].self, from: jsonData)

        return groups
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}



func sendGETGroups(ip: String, which: String?, completion: @escaping ([String:RoomResponse]) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/groups/\(which ?? "")") else {
        print("Invalid URL")
//        completion("Invalid URL")
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
            
//            print(String(data: data, encoding: .utf8))
            
            if let which = which {
                
                
                // Utilisation de decodeSensorResponse
                if let group = decodeOneGroupResponse(jsonData: data) {
                    print(group.name)
                    let result = [which : group]
                    completion(result) // Retourne les capteurs décodés
                } else {
                    print("Failed to decode response")
                }
                 
            }
            else {
                
                
                if let groups = decodeGroupsResponse(jsonData: data) {

//                    var result = " ----- GROUPS ----- \n"
//
//                    for group in groups {
//                        result += "\(group.0) - \(group.1.name) - \(group.1.lights)\n"
//                    }
//                    print(result)
                    
                    completion(groups)
                } else {
                    print("Failed to decode response")
                    //completion(nil)
                }
                 
                
            }
        }
        
        else {
            print("Unknown error")
        }
    }.resume()
}



func sendPUTGroupRequest(ip: String, groupIndex: Int, ct: Int, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/groups/\(groupIndex)/action") else {
         print("Invalid URL")
        return
     }
     
     var request = URLRequest(url: url)
     request.httpMethod = "PUT"
        
    let body = """
                {"ct": \(ct)}
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
