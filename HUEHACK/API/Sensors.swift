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
                    completion(result) // Retourne les capteurs décodés
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
                    
                    completion(sensors)
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
    



/*
func globalOnOff(ip: String, indexGlobalOnOff: Int, state: Int, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/\(indexGlobalOnOff)/state/") else {
         print("Invalid URL")
        return
     }
     
     var request = URLRequest(url: url)
     request.httpMethod = "PUT"
    
    var body = ""
    
    
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
