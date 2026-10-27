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
            // Creates the 10 s schedule if missing.
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

private let timerScheduleName = "HUEHACK-TIMER"
/// Recurring forever, every 10 s.
private let timerScheduleTime = "R/PT00:00:10"
/// Rule created by earlier builds: it never fired (a rule does not re-trigger
/// on its own writes), so it is removed.
private let legacyHeartbeatRuleName = "HUEHACK-HEARTBEAT"

/// The 10 s tick is a bridge schedule `HUEHACK-TIMER` (`R/PT00:00:10`) that
/// writes `{"status":0}` to the TIMER sensor; each write updates its
/// `lastupdated`, which the segment rules watch (`ddx PT00:00:05`).
/// Makes sure exactly one such schedule targets the current TIMER sensor
/// (anything else under that name is replaced) and removes the legacy heartbeat
/// rule. Completes on main with false if the schedule could not be checked or
/// created.
func ensureTimerRunning(completion: @escaping (Bool) -> Void = { _ in }) {
    func finish(_ ok: Bool) { DispatchQueue.main.async { completion(ok) } }
    if demoMode { finish(true); return }
    let address = "/api/\(username)/sensors/\(indexTimer)/state"

    func isValid(_ schedule: [String: Any]) -> Bool {
        let command = schedule["command"] as? [String: Any] ?? [:]
        let status = (command["body"] as? [String: Any])?["status"] as? Int
        return schedule["localtime"] as? String == timerScheduleTime
            && schedule["status"] as? String == "enabled"
            && command["address"] as? String == address
            && command["method"] as? String == "PUT"
            && status == 0
    }

    func removeLegacyHeartbeat(then ok: Bool) {
        fetchRawRules { rules in
            let ids = (rules ?? [:]).filter { resourceName($0.value) == legacyHeartbeatRuleName }
                .compactMap { Int($0.key) }.sorted()
            deleteSequentially(.rules, ids: ids) { _ in finish(ok) }
        }
    }

    hueRequest(.GET, "schedules") { json in
        guard let schedules = json as? [String: [String: Any]] else { finish(false); return }
        let matches = schedules.filter { resourceName($0.value) == timerScheduleName }
        if matches.count == 1, let schedule = matches.first?.value, isValid(schedule) {
            removeLegacyHeartbeat(then: true)
            return
        }
        print("HUEHACK: timer schedule missing or outdated — recreating it")
        deleteSequentially(.schedules, ids: matches.keys.compactMap { Int($0) }.sorted()) { deleted in
            // Posting on top of a schedule that could not be deleted would double the tick.
            guard deleted else { finish(false); return }
            let body: [String: Any] = [
                "name": timerScheduleName,
                "description": "HUEHACK 10 s tick",
                "command": ["address": address, "method": "PUT", "body": ["status": 0]],
                "localtime": timerScheduleTime,
                "status": "enabled",
                // No "autodelete": the bridge rejects it on a recurring timer (type 6).
            ]
            hueRequest(.POST, "schedules", body: body) { json in
                let ok = hueSucceeded(json)
                if !ok { print("HUEHACK: timer schedule rejected: \(String(describing: json))") }
                removeLegacyHeartbeat(then: ok)
            }
        }
    }
}
