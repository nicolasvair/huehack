//
//  ContentView2.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import SwiftUI

struct ContentView2: View {
    @State private var url = ""
    @State private var method = "GET"
    @State private var bodyR = """
    {
        "name": "HUEHACK - 23h-00h",
        "conditions": [
            {
                "address": "/sensors/172/state/lastupdated",
                "operator": "ddx",
                "value": "PT00:00:03"
            },
            {
                "address": "/config/localtime",
                "operator": "in",
                "value": "T23:00:00/T23:59:59"
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
                "address": "/groups/2/state",
                "method": "PUT",
                "body": {
                    "ct": 500
                }
            }
        ]
    }
    """
    @State private var response = ""
    let methods = ["GET", "POST", "PUT", "DELETE"]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Enter URL", text: $url)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Picker("Method", selection: $method) {
                    ForEach(methods, id: \.self) { method in
                        Text(method)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                if method != "GET" {
                    Text("Body (JSON):")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextEditor(text: $bodyR)
                        .border(Color.gray, width: 1)
                        .frame(height: 200)
                        .padding(.horizontal)
                }

                Button(action: sendRequest) {
                    Text("Send Request")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                Text("Response:")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView {
                    Text(response)
                        .font(.body)
                        .padding()
                }
                .border(Color.gray, width: 1)
                .frame(height: 200)
                .padding(.horizontal)
            }
            .navigationTitle("HTTP Client")
        }
    }

    func sendRequest() {
        guard let url = URL(string: url) else {
            response = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if method != "GET", let jsonData = bodyR.data(using: .utf8) {
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        URLSession.shared.dataTask(with: request) { data, res, error in
            DispatchQueue.main.async {
                if let error = error {
                    response = "Error: \(error.localizedDescription)"
                    return
                }
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    response = responseString
                } else {
                    response = "No data received"
                }
            }
        }.resume()
    }
}




#Preview {
    ContentView2().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
