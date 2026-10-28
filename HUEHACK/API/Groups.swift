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


/// Always calls `completion` on the main queue. On any failure (invalid URL, network
/// error, bridge error payload, decode failure) it is called with an empty dictionary,
/// so callers never hang on a spinner.
func sendGETGroups(ip: String, which: String?, completion: @escaping ([String:RoomResponse]) -> Void) {
    func finish(_ result: [String: RoomResponse]) {
        DispatchQueue.main.async { completion(result) }
    }

    guard let url = URL(string: "http://\(ip)/api/\(username)/groups/\(which ?? "")") else {
        print("Invalid URL")
        finish([:])
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.GET.rawValue

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            finish([:])
        }
        else if let data = data {
            if let which = which {
                if let group = decodeOneGroupResponse(jsonData: data) {
                    finish([which : group])
                } else {
                    print("Failed to decode response")
                    finish([:])
                }
            }
            else {
                if let groups = decodeGroupsResponse(jsonData: data) {
                    finish(groups)
                } else {
                    print("Failed to decode response")
                    finish([:])
                }
            }
        }
        else {
            print("Unknown error")
            finish([:])
        }
    }.resume()
}


func sendPOSTGroup(ip: String, name: String, lights: [String], completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/groups") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.POST.rawValue
    let lightsJSON = lights.map { "\"\($0)\"" }.joined(separator: ",")
    let body = "{\"name\":\"\(name)\",\"type\":\"Room\",\"class\":\"Other\",\"lights\":[\(lightsJSON)]}"
    request.httpBody = body.data(using: .utf8)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    URLSession.shared.dataTask(with: request) { _, _, error in
        completion(error == nil)
    }.resume()
}

func sendPUTGroup(ip: String, groupIndex: Int, name: String, lights: [String], completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/groups/\(groupIndex)") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.PUT.rawValue
    let lightsJSON = lights.map { "\"\($0)\"" }.joined(separator: ",")
    let body = "{\"name\":\"\(name)\",\"lights\":[\(lightsJSON)]}"
    request.httpBody = body.data(using: .utf8)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    URLSession.shared.dataTask(with: request) { _, _, error in
        completion(error == nil)
    }.resume()
}

func sendDELETEGroup(ip: String, groupIndex: Int, completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/groups/\(groupIndex)") else {
        completion(false)
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.DELETE.rawValue
    URLSession.shared.dataTask(with: request) { _, _, error in
        completion(error == nil)
    }.resume()
}


