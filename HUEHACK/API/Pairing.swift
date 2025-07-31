//
//  Pairing.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 01/08/2025.
//

import Foundation

class BridgePairingManager: ObservableObject {
    @Published var status: Status = .idle
    @Published var message: String = ""

    enum Status {
        case idle, inProgress, success, error
    }

    private let ipKey = "BridgeIP"
    private let usernameKey = "BridgeUsername"

    var hueBridgeIP: String? {
        get { UserDefaults.standard.string(forKey: "hueBridgeIP") }
    }

    var storedUsername: String? {
        get { UserDefaults.standard.string(forKey: usernameKey) }
        set { UserDefaults.standard.set(newValue, forKey: usernameKey) }
    }

    func pairWithBridge(ip: String) {
        guard let url = URL(string: "http://\(ip)/api") else {
            self.status = .error
            self.message = "URL invalide"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = """
        {
            "devicetype":"my_hue_app#ios",
            "generateclientkey": true
        }
        """.data(using: .utf8)

        self.status = .inProgress
        self.message = "Pairing en cours..."

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = .error
                    self.message = "Erreur réseau : \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let first = jsonArray.first else {
                    self.status = .error
                    self.message = "Réponse invalide"
                    return
                }

                if let errorDict = first["error"] as? [String: Any],
                   let desc = errorDict["description"] as? String {
                    self.status = .error
                    self.message = desc
                } else if let successDict = first["success"] as? [String: Any],
                          let username = successDict["username"] as? String {
                    self.status = .success
                    self.message = "Succès !"
                    self.storedUsername = username
                } else {
                    self.status = .error
                    self.message = "Réponse inattendue"
                }
            }
        }.resume()
    }
}
