//
//  genericAPIcalls.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 01/08/2025.
//

import Foundation
import Combine

enum TypeRequest: String {
    case GET, POST, PUT, DELETE
}

enum TypeWhat: String {
    case sensors, rules, lights, groups, config, schedules, scenes, resourcelinks
}

enum HueAPIStatus {
    case idle
    case inProgress
    case success(String)
    case failure(String)
}

class HueAPIManager: ObservableObject {
    @Published var status: HueAPIStatus = .idle
    @Published var data: String = ""

    private var ip: String? {
        UserDefaults.standard.string(forKey: "hueBridgeIP")
    }

    private var username: String? {
        UserDefaults.standard.string(forKey: "usernameKey")
    }

    private func buildURL(path: String) -> URL? {
        guard let ip = ip, let username = username else { return nil }
        return URL(string: "http://\(ip)/api/\(username)/\(path)")
    }

    func sendGET(what: TypeWhat?, which: String?) {
        guard let path = [what?.rawValue, which].compactMap({ $0 }).joined(separator: "/").nonEmpty,
              let url = buildURL(path: path) else {
            status = .failure("Invalid URL or missing IP/username")
            return
        }

        status = .inProgress

        var request = URLRequest(url: url)
        request.httpMethod = TypeRequest.GET.rawValue

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = .failure(error.localizedDescription)
                } else if let data = data, let result = String(data: data, encoding: .utf8) {
                    self.data = result
                    self.status = .success(result)
                } else {
                    self.status = .failure("Unknown error")
                }
            }
        }.resume()
    }

    
    func sendGETall() {
        guard let ip = ip, let username = username,
              let url = URL(string: "http://\(ip)/api/\(username)") else {
            status = .failure("Invalid URL or missing IP/username")
            return
        }

        status = .inProgress

        var request = URLRequest(url: url)
        request.httpMethod = TypeRequest.GET.rawValue

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = .failure(error.localizedDescription)
                } else if let data = data, let result = String(data: data, encoding: .utf8) {
                    self.data = result
                    self.status = .success(result)
                } else {
                    self.status = .failure("Unknown error")
                }
            }
        }.resume()
    }

    func sendPOST(ip: String, what: TypeWhat, body: String?) {
        guard let username = username,
              let url = URL(string: "http://\(ip)/api/\(username)/\(what.rawValue)") else {
            status = .failure("Invalid URL or missing username")
            return
        }

        status = .inProgress

        var request = URLRequest(url: url)
        request.httpMethod = TypeRequest.POST.rawValue

        if let bodyData = body?.data(using: .utf8) {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = .failure(error.localizedDescription)
                } else if let data = data, let result = String(data: data, encoding: .utf8) {
                    self.status = .success(result)
                } else {
                    self.status = .failure("Unknown error")
                }
            }
        }.resume()
    }

    func sendDELETE(ip: String, what: TypeWhat, which: Int) {
        guard let username = username,
              let url = URL(string: "http://\(ip)/api/\(username)/\(what.rawValue)/\(which)") else {
            status = .failure("Invalid URL or missing username")
            return
        }

        status = .inProgress

        var request = URLRequest(url: url)
        request.httpMethod = TypeRequest.DELETE.rawValue

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = .failure(error.localizedDescription)
                } else if let data = data, let result = String(data: data, encoding: .utf8) {
                    self.status = .success(result)
                } else {
                    self.status = .failure("Unknown error")
                }
            }
        }.resume()
    }
}

private extension String {
    var nonEmpty: String? {
        self.isEmpty ? nil : self
    }
}
