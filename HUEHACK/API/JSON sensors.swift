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




