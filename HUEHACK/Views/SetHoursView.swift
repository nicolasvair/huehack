//
//  SetHoursView.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//


import Foundation
import SwiftUI

var ip = "192.168.1.121"
var username = "MN07hphqoytdZ5mWmnEuXKknn8tfc27IXW5wVbkH"

var indexGlobalTimer = 171
var indexTimer = 172

 var defaultListOfSegments = [
    Segment(name: "Sunrise", hourStart: DateComponents.init(hour:8, minute: 0), temp: 300),
    Segment(name: "Daylight", hourStart: DateComponents.init(hour:10, minute: 0), temp: 250),
    Segment(name: "Sunset", hourStart: DateComponents.init(hour:17, minute: 0), temp: 300),
    Segment(name: "Evening", hourStart: DateComponents.init(hour:20, minute: 0), temp: 350),
    Segment(name: "Night", hourStart: DateComponents.init(hour:0, minute: 0), temp: 420)
    ]



struct Segment: Identifiable {
    var id = UUID()
    
    var name: String
    var hourStart: DateComponents // Représente uniquement l'heure et les minutes
    var temp: Int
}


struct SetHoursView: View {
    
    @State private var nbOfSegments = 4
    @State var listOfSegments = [Segment]()
    @State var firstAppear = true
    @State var globalOnOff = true
    
    var body: some View {
        
        VStack{
            
            List(listOfSegments.indices, id: \.self) { index in
                NavigationLink {
                    EditSegment(index: index, listOfSegments: $listOfSegments)
                } label: {
                    HStack{
                        let segment = listOfSegments[index]
                        Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!)) - \(segment.name) - \(segment.temp.miredsToKelvin) °K")
                        Spacer()
                        Rectangle()
                            .frame(width: 50)
                            .foregroundStyle(Color.init(mireds: Double(segment.temp)))
                            .padding()
                    }
                }
            }
            
            HStack{
                Toggle(isOn: $globalOnOff) {
                    Text("Global on off")
                }
                .frame(width:120)
                
                Button {
                    createRulesFromlistOfSegments(listOfSegments: listOfSegments)

                } label: {
                    Text("Create rules")
                        .padding()
                }

            }
            
        }
        .onAppear {
            if firstAppear {
                listOfSegments = defaultListOfSegments
                firstAppear = false
            }
        }
        .onChange(of: globalOnOff) { oldValue, newValue in
            let state = globalOnOff ? 0 : 1
            sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalTimer, indexTimer: indexTimer, state: state) { response in
                print(response)
            }
        }
        
    }
    
}




#Preview {
    NavigationStack{
        SetHoursView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
