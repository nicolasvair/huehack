import Foundation

// Modèle pour un capteur
struct Sensor: Codable {
    var state: SensorState
    var config: SensorConfig
    var name: String
    var type: String
    var modelid: String?
    var manufacturername: String
    var swversion: String
    var uniqueid: String?
    var recycle: Bool?
}

// Sous-structure pour l'état
struct SensorState: Codable {
    var status: Int?         // Utilisé par certains capteurs
    var daylight: Bool?      // Utilisé par le capteur "Daylight"
    var lastupdated: String
}

// Sous-structure pour la configuration
struct SensorConfig: Codable {
    var on: Bool
    var reachable: Bool?     // Optionnel pour certains capteurs
    var sunriseoffset: Int?  // Utilisé par "Daylight"
    var sunsetoffset: Int?   // Utilisé par "Daylight"
    var configured: Bool?
}

// Fonction pour décoder le JSON
func decodeOneSensorResponse(jsonData: Data) -> Sensor? {
//    print(String(data: jsonData, encoding: .utf8) ?? "Invalid UTF-8 data")

    do {
        let decoder = JSONDecoder()
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let sensors = try decoder.decode(Sensor.self, from: jsonData)

        return sensors
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}

func decodeSensorsResponse(jsonData: Data) -> [String:Sensor]? {
//    print(String(data: jsonData, encoding: .utf8) ?? "Invalid UTF-8 data")
    
    do {
        let decoder = JSONDecoder()
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let sensors = try decoder.decode([String:Sensor].self, from: jsonData)

        return sensors
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return [:]
    }
}




func sendGETSensors(ip: String, which: String?, completion: @escaping ([String:Sensor]) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/sensors/\(which ?? "")") else {
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
//            print(data)
            if let which = which {
                // Utilisation de decodeSensorResponse
                if let sensor = decodeOneSensorResponse(jsonData: data) {
//                    print(sensor)
                    let result = [which : sensor]
                    DispatchQueue.main.async { completion(result) }
                } else {
                    print("Failed to decode response")
                }
            }
            else {
                if let sensors = decodeSensorsResponse(jsonData: data) {

//                    var result = " ----- SENSORS ----- \n"
//                    
//                    for sensor in sensors {
//                        if let status = sensor.1.state.status {
//                            result += "\(sensor.0) - \(sensor.1.name) - \(status) \n"
//                        } else {
//                            result += "\(sensor.0) - \(sensor.1.name) - \(sensor.1.state.daylight)\n"
//                        }
//                    }
//                    print(result)
                    
                    DispatchQueue.main.async { completion(sensors) }
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



func checkSensorsNb() -> [String: String] {
    var results: [String: String] = [:]

    sendGETSensors(ip: ip, which: nil) { response in
        for sensorTuple in response {
            if sensorTuple.1.name.prefix(7) == "HUEHACK" {
                let name = String(sensorTuple.1.name.dropFirst(10))
                
                if name == "TIMER" || name == "GLOBAL ONOFF" {
                    results[name] = sensorTuple.0
//                    print("\(name) - \(sensorTuple.0)")
                }
            }
        }
        
//        print("Sensors nb : \(results)")
    }
    return results
}
    


func sendPUTSensors(ip: String, indexSensor: Int, state: Int, completion: @escaping (String) -> Void) {
    
    
    guard let url = URL(string: "http://\(ip)/api/\(username)/sensors/\(indexSensor)/state/") else {
         print("Invalid URL")
        return
     }
     
     var request = URLRequest(url: url)
     request.httpMethod = "PUT"
    
    let body = """
                {"status":\(state)}
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



func sendGlobalOnOff(ip: String, indexGlobalOnOff: Int, indexTimer: Int, state: Int, completion: @escaping (String) -> Void) {

    sendPUTSensors(ip: ip, indexSensor: indexGlobalOnOff, state: state) { response in
        print(response)
    }
    sendPUTSensors(ip: ip, indexSensor: indexTimer, state: 0) { response in
        print(response)
    }
 }


// MARK: - HUEHACK installation

/// Creates a CLIPGenericStatus sensor (status starts at 0). Completes on main with
/// its bridge id, or nil on failure. Also used for the per-room OVR sensors
/// (RoomOverride.swift).
func createVirtualSensor(name: String, uniqueid: String, completion: @escaping (Int?) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/sensors") else {
        DispatchQueue.main.async { completion(nil) }
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body = """
    {"name":"\(name)","modelid":"HUEHACK","swversion":"1.0","type":"CLIPGenericStatus","uniqueid":"\(uniqueid)","manufacturername":"HUEHACK","recycle":false}
    """
    request.httpBody = body.data(using: .utf8)
    URLSession.shared.dataTask(with: request) { data, _, _ in
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let idStr = json.first?["success"] as? [String: Any],
              let id = idStr["id"] as? String,
              let idx = Int(id) else { DispatchQueue.main.async { completion(nil) }; return }
        DispatchQueue.main.async { completion(idx) }
    }.resume()
}

private func createTimerHeartbeatRule(indexTimer: Int, completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/rules") else { completion(false); return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body = """
    {"name":"HUEHACK-HEARTBEAT","conditions":[{"address":"/sensors/\(indexTimer)/state/status","operator":"gt","value":"-1"}],"actions":[{"address":"/sensors/\(indexTimer)/state","method":"PUT","body":{"status":1}}]}
    """
    request.httpBody = body.data(using: .utf8)
    URLSession.shared.dataTask(with: request) { data, _, _ in
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              json.first?["success"] != nil else { DispatchQueue.main.async { completion(false) }; return }
        DispatchQueue.main.async { completion(true) }
    }.resume()
}

func installHUEHACKSensors(completion: @escaping (Bool, String) -> Void) {
    sendGETSensors(ip: ip, which: nil) { sensors in
        var timerIdx: Int? = nil
        var globalOnOffIdx: Int? = nil
        for (key, sensor) in sensors {
            if sensor.name.hasSuffix("TIMER") { timerIdx = Int(key) }
            if sensor.name.hasSuffix("GLOBAL ONOFF") { globalOnOffIdx = Int(key) }
        }
        let alreadyInstalled = timerIdx != nil && globalOnOffIdx != nil
        let group = DispatchGroup()

        if timerIdx == nil {
            group.enter()
            createVirtualSensor(name: "HUEHACK - TIMER", uniqueid: "huehack-timer") { idx in
                timerIdx = idx
                group.leave()
            }
        }
        if globalOnOffIdx == nil {
            group.enter()
            createVirtualSensor(name: "HUEHACK - GLOBAL ONOFF", uniqueid: "huehack-global") { idx in
                globalOnOffIdx = idx
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard let ti = timerIdx, let goi = globalOnOffIdx else {
                completion(false, "Impossible de créer les capteurs")
                return
            }
            AppConfig.shared.indexTimer = ti
            AppConfig.shared.indexGlobalOnOff = goi
            // Creates the heartbeat rule if missing and starts the loop.
            ensureTimerRunning { ok in
                if !ok {
                    completion(false, "Capteurs prêts mais minuteur 10 s non démarré")
                } else {
                    completion(true, alreadyInstalled ? "HUEHACK déjà installé — indices mis à jour ✓" : "HUEHACK installé ✓")
                }
            }
        }
    }
}


// MARK: - Timer loop

private let heartbeatRuleName = "HUEHACK-HEARTBEAT"

/// Bridge `lastupdated` ("2026-10-27T10:53:26", UTC, or "none") → Date.
private func bridgeUTCDate(_ value: String?) -> Date? {
    guard let value = value else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter.date(from: value)
}

/// The 10 s tick only runs once something writes the TIMER sensor: the heartbeat
/// rule re-fires on its own writes, but a freshly created rule (or a bridge
/// reboot) leaves it idle and no segment rule ever fires. Makes sure the
/// heartbeat rule exists, then writes the timer once if it has not ticked for a
/// minute (never while it runs: each extra write could start a second loop).
/// Completes on main with false if the loop could not be checked or started.
func ensureTimerRunning(completion: @escaping (Bool) -> Void = { _ in }) {
    func finish(_ ok: Bool) { DispatchQueue.main.async { completion(ok) } }
    if demoMode { finish(true); return }
    let timer = indexTimer

    fetchRawRules { rules in
        guard let rules = rules else { finish(false); return }
        let address = "/sensors/\(timer)/state/status"
        let hasHeartbeat = rules.values.contains { rule in
            guard rule["name"] as? String == heartbeatRuleName else { return false }
            let conditions = rule["conditions"] as? [[String: Any]] ?? []
            return conditions.contains { $0["address"] as? String == address }
        }

        func kickIfIdle() {
            fetchRawSensors { sensors in
                guard let sensor = sensors?[String(timer)] else { finish(false); return }
                let last = bridgeUTCDate((sensor["state"] as? [String: Any])?["lastupdated"] as? String)
                if let last = last, Date().timeIntervalSince(last) < 60 {
                    finish(true)
                    return
                }
                print("HUEHACK: timer idle — starting the 10 s loop")
                sendPUTSensors(ip: ip, indexSensor: timer, state: 0) { response in
                    finish(response.contains("\"success\""))
                }
            }
        }

        if hasHeartbeat {
            kickIfIdle()
        } else {
            print("HUEHACK: heartbeat rule missing — recreating it")
            createTimerHeartbeatRule(indexTimer: timer) { ok in
                guard ok else { finish(false); return }
                kickIfIdle()
            }
        }
    }
}
