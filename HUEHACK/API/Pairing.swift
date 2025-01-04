
//
//  JSON Pairing.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import Foundation

struct ErrorResponse: Codable {
    let error: ErrorDetail?
    let success: SuccessDetail?
}

struct ErrorDetail: Codable {
    let type: Int
    let address: String
    let description: String
}

struct SuccessDetail: Codable {
    let username: String
    let clientkey: String
}


func sendPairRequest(ip: String, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/") else {
        print("Invalid URL")
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = """
    {
        "devicetype": "vair#HUEHACK>",
    "generateclientkey":true
    }
    """.data(using: .utf8)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
//                response = error.localizedDescription
        } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
            
            var result = ""
            
            // Convertir la chaîne JSON en Data
            if let jsonData = responseString.data(using: .utf8) {
                do {
                    // Décoder les données JSON
                    let responses = try JSONDecoder().decode([ErrorResponse].self, from: jsonData)
                    
                    // Extraire la description du premier élément
                    if let firstResponse = responses.first {
                        if let description = firstResponse.error?.description {
                            print("Description pour l'utilisateur : \(description)")
                            result = description
                        }
                        else if let username = firstResponse.success?.username {
                            print("Succès ! username : \(username)")
                            result = username
                        }

                    }
                } catch {
                    print("Erreur lors du décodage JSON : \(error)")
                }
            } else {
                print("Erreur : Impossible de convertir la chaîne JSON en Data.")
            }
            
            
            
            print("Response: \(responseString)")
//                response = responseString
            completion(result)
        }
    }.resume()
}

