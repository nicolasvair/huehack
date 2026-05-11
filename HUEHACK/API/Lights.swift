//
//  Lights.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 05/01/2025.
//
import Foundation

struct LightResponse: Codable {
    let name: String
}

func sendGETLights(ip: String, completion: @escaping ([String: LightResponse]) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/lights") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.GET.rawValue
    URLSession.shared.dataTask(with: request) { data, _, error in
        guard let data = data, error == nil,
              let lights = try? JSONDecoder().decode([String: LightResponse].self, from: data) else { return }
        completion(lights)
    }.resume()
}

/*
func sendPUTLightsRequest(ip: String, body: String?, ct: Int, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/") else {
         print("Invalid URL")
        return
     }
     
     var request = URLRequest(url: url)
     request.httpMethod = "POST"
    
    
    if let jsonDataBody = body?.data(using: .utf8) {
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
*/


func sendPUTLightName(ip: String, lightIndex: Int, name: String, completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/lights/\(lightIndex)") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.PUT.rawValue
    request.httpBody = "{\"name\":\"\(name)\"}".data(using: .utf8)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    URLSession.shared.dataTask(with: request) { _, _, error in
        completion(error == nil)
    }.resume()
}

func sendPUTLightAlert(ip: String, lightIndex: Int, completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/lights/\(lightIndex)/state") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.PUT.rawValue
    request.httpBody = "{\"alert\":\"select\"}".data(using: .utf8)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    URLSession.shared.dataTask(with: request) { _, _, error in
        completion(error == nil)
    }.resume()
}

// presque mais la ça marche pas
func sendPUTLightsRequest(ip: String, which: Int, ct: Int?, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/lights/\(which)/state") else {
         print("Invalid URL")
        return
     }
     
     var request = URLRequest(url: url)
     request.httpMethod = "PUT"
    
    let body = """
                {"ct":\(ct)}
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
