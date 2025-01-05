
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




struct TestView: View {
        
    @State private var textShownToUser = ""
    
    
    
    var body: some View {
    
        Button {
            sendGETRequest(ip: ip, what: TypeWhat.sensors, which: String(1)) { response in
                textShownToUser = response
            }
        } label: {
            Text("Get sensors")
                .padding()
        }
        
        Button {
            checkSensorsNb()
        } label: {
            Text("Check sensors")
                .padding()
        }

        
        Button {
            sendGETRequest(ip: ip, what: TypeWhat.rules, which: nil) { response in
                textShownToUser = response
            }
        } label: {
            Text("Get rules")
                .padding()
        }
        
        Button {
            checkRulesNb()
//            sendGETRules(ip: ip, which: nil) { response in
//                textShownToUser = response
//            }
        } label: {
            Text("Check rules")
                .padding()
        }

        
        
        Button {
            sendPOSTRequest(ip: ip, what: TypeWhat.sensors, body: testSensorBody) { response in
                textShownToUser = response
            }
        } label: {
            Text("Create sensor")
                .padding()
        }
        
        Button {
            sendDELETERequest(ip: ip, what: TypeWhat.sensors, which: 174) { response in
                textShownToUser = response
            }
        } label: {
            Text("Delete sensor")
                .padding()
        }

        
        
        
        
        Button {
            deleteAllHUEHACKRules{}
        } label: {
            Text("Delete all HUEHACK rules")
                .padding()
        }


        
        Text("Response:")
            .font(.headline)
            .padding(.horizontal)

        ScrollView {
            Text(textShownToUser)
                .font(.body)
                .padding()
        }
        .border(Color.gray, width: 1)
//        .frame(height: 400)
        .padding(.horizontal)



    }
    
}








#Preview {
    TestView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
