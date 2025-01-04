
//
//  ContentView2.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//


import SwiftUI


// username":"MN07hphqoytdZ5mWmnEuXKknn8tfc27IXW5wVbkH"
// clientkey":"E29C7C25BB209C9FB14B5157AC427AAC"

var ip = "192.168.1.121"
var username = "MN07hphqoytdZ5mWmnEuXKknn8tfc27IXW5wVbkH"

var testSensorBody = """
        {
            "name": "HUEHACK - Test ",
            "type": "CLIPGenericStatus",
            "modelid": "MyModel",
            "manufacturername": "HUEHACK",
            "swversion": "1.0",
            "uniqueid": "sensor-01",
            "state": {
                "status": 0
            },
            "config": {
                "on": true,
                "reachable": true
            }
        }
        """




struct ContentView3: View {
    
    @State private var mainOnOff = true
    
    @State private var retour = ""
    
    
    
    var body: some View {

        Toggle(isOn: $mainOnOff) {
            Text("Main on/off")
        }
        .padding(80)

        Button {
            sendGETRequest(ip: ip, what: TypeWhat.sensors) { response in
                retour = response
            }
        } label: {
            Text("Get sensors")
                .padding()
        }
        
        Button {
            sendGETRequest(ip: ip, what: TypeWhat.rules) { response in
                retour = response
            }
        } label: {
            Text("Get rules")
                .padding()
        }
        
        
        Button {
            sendPOSTRequest(ip: ip, what: TypeWhat.sensors, body: testSensorBody) { response in
                retour = response
            }
        } label: {
            Text("Create sensor")
                .padding()
        }
        
        Button {
            sendDELETERequest(ip: ip, what: TypeWhat.sensors, which: 174) { response in
                retour = response
            }
        } label: {
            Text("Delete sensor")
                .padding()
        }

        
        
        Button {
            sendPOSTRuleRequest(ip: ip, hourStart: 3, hourEnd: 4, temp:200) { response in
                retour = response
            }
        } label: {
            Text("Create rule")
                .padding()
        }
        
        
        Button {
            sendDELETERequest(ip: ip, what: TypeWhat.rules, which: 9) { response in
                retour = response
            }
        } label: {
            Text("Delete rule")
                .padding()
        }


        
        Text("Response:")
            .font(.headline)
            .padding(.horizontal)

        ScrollView {
            Text(retour)
                .font(.body)
                .padding()
        }
        .border(Color.gray, width: 1)
        .frame(height: 400)
        .padding(.horizontal)



    }
    
    /*
    func sendRequestInit() {
        guard let url = URL(string: url) else {
            response = "Invalid URL"
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
                print("Response: \(responseString)")
//                response = responseString
            }
        }.resume()
    }
     */
    
    /*
    func sendTestRequest() {
        guard let url = URL(string: "http://192.168.1.121/api/MN07hphqoytdZ5mWmnEuXKknn8tfc27IXW5wVbkH/rules/") else {
            response = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response2, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                response = error.localizedDescription
            } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
                response = responseString
            }
        }.resume()
    }
    */
    
    func deleteAllRules(){
        
    }

}






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




func sendGETRequest(ip: String, what: TypeWhat?, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "http://\(ip)/api/\(username)/\(what?.rawValue ?? "")") else {
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
        } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
            print("Response: \(responseString)")
            completion(responseString)
        } else {
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











#Preview {
    ContentView3().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
