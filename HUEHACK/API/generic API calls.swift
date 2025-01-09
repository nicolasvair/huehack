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
            if let result = String(data: data, encoding: .utf8){
                completion(result)
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
//            print("Error: \(error.localizedDescription)")
            completion(error.localizedDescription)
        } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
//            print("Response: \(responseString)")
            completion(responseString)
        } else {
            completion("Unknown error")
        }
    }.resume()
}








