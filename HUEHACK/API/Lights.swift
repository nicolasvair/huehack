//
//  Lights.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 05/01/2025.
//
import Foundation

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
