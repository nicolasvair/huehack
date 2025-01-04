//
//  API calls.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//
import Foundation

enum TypeRequest: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum TypeWhat: String {
    case sensors = "sensors"
    case rules = "rules"
}



//func sendPairRequest(ip: String, completion: @escaping (String) -> Void) {
//    guard let url = URL(string: "http://\(ip)/api/") else {
//        print("Invalid URL")
//        return
//    }
//
//    var request = URLRequest(url: url)
//    request.httpMethod = "POST"
//    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//    request.httpBody = """
//    {
//        "devicetype": "vair#HUEHACK>",
//    "generateclientkey":true
//    }
//    """.data(using: .utf8)
//
//    URLSession.shared.dataTask(with: request) { data, response, error in
//        if let error = error {
//            print("Error: \(error.localizedDescription)")
////                response = error.localizedDescription
//        } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
//            print("Response: \(responseString)")
////                response = responseString
//            completion(responseString)
//        }
//    }.resume()
//}



func sendGETRequest(ip: String, what: TypeWhat?, which: String?, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/\(what?.rawValue ?? "")/\(which ?? "")") else {
        print("Invalid URL")
        completion("Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.GET.rawValue
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            completion(error.localizedDescription)
        }
        else if let data = data {
            
            if which != nil {
                // Utilisation de decodeSensorResponse
                if let sensors = decodeOneSensorResponse(jsonData: data) {
                    print(sensors)
                    //                        completion(sensors) // Retourne les capteurs décodés
                } else {
                    print("Failed to decode response")
                    //                        completion(nil)
                }
            }
            else {
                
                if let sensors = decodeSensorsResponse(jsonData: data) {
                    
                    var result = " ----- SENSORS ----- \n \n"
                    
                    for sensor in sensors {
                        if let status = sensor.1.state.status {
                            result += "\(sensor.0) - \(sensor.1.name) - \(status) \n\n"
                        } else {
                            result += "\(sensor.0) - \(sensor.1.name) - \(sensor.1.state.daylight) \n\n"
                        }                    }
                    
                    completion(result)
                    
//                    print(sensors)
                    //                        completion(sensors) // Retourne les capteurs décodés
                } else {
                    print("Failed to decode response")
                    //                        completion(nil)
                }

                
            }
        }
        
        else {
            completion("Unknown error")
        }
    }.resume()
}





func sendPOSTRequest(ip: String, what: TypeWhat, body: String?, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/\(what.rawValue)") else {
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

 


func sendPOSTRuleRequest(ip: String, hourStart: Int, hourEnd: Int, temp: Int, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/rules") else {
         print("Invalid URL")
        return
     }
     
     var request = URLRequest(url: url)
     request.httpMethod = "POST"
    
    
    var body = """
    {
            "name": "HUEHACK - 23h-00h ",
            "conditions": [
                {
                    "address": "/sensors/172/state/lastupdated",
                    "operator": "ddx",
                    "value": "PT00:00:03"
                },
                {
                    "address": "/config/localtime",
                    "operator": "in",
                    "value": "T\(String(format: "%02d", hourStart)):00:00/T\(String(format: "%02d", hourEnd - 1 )):59:59"
                },
                {
                    "address": "/sensors/171/state/status",
                    "operator": "eq",
                    "value": "1"
                }
            ],
            "actions": [
                {
                    "address": "/sensors/172/state",
                    "method": "PUT",
                    "body": {
                        "status": 0
                    }
                },
                {
                    "address": "/groups/2/action",
                    "method": "PUT",
                    "body": {
                        "ct": \(temp)
                    }
                }
            ]
        }
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




func sendDELETERequest(ip: String, what: TypeWhat, which: Int, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/\(what.rawValue)/\(which)") else {
        print("Invalid URL")
        completion("Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = TypeRequest.DELETE.rawValue
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            completion(error.localizedDescription)
        } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
            print("Response: \(responseString)")
            completion(responseString)
        } else {
            completion("Unknown error")
        }
    }.resume()
}








