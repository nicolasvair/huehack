//
//  EditSegment.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import SwiftUI

let dégradéCouleur = LinearGradient(gradient: Gradient(colors: [Color.orange, Color.white]),
                                    startPoint: .leading, endPoint: .trailing)





struct EditSegment: View {
    
    @State var lastRequestTime: Date = Date()
    
    @State var index: Int
    @Binding var listOfSegments: [Segment]
    
    @State private var pickerHourIn = Date()
    @State private var pickerHourOut = Date()
    
    @State private var tempKelvins = 200.0
    @State private var tempMireds = 200.0
    
    @State private var sliderIsEditing = false
    
    var body: some View {
        
        //        var segment = listOfSegments[index]
        
        VStack {
            
            Text(listOfSegments[index].name)
                .font(.title)
            
            DatePicker(selection: $pickerHourIn, displayedComponents: .hourAndMinute, label: { Text("Start") })
                .frame(width:200)
            
            DatePicker(selection: $pickerHourOut, displayedComponents: .hourAndMinute, label: { Text("End") })
                .frame(width:200)
            
            ZStack{
                
                Rectangle()
                    .foregroundStyle(Color.init(mireds: tempMireds))
                    .frame(height:150)
                    .cornerRadius(15)
                    .padding(.horizontal)
                
                Text("Temp : \(Int(tempKelvins)) °K")
                    .padding()
                    .font(.title2)
                                
            }
            
            Slider(value: $tempKelvins, in: 2000...5000, onEditingChanged: { bool in
                if bool {
                    sliderIsEditing = true
                    sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalOnOff, indexTimer: indexTimer, state: 1) { response in print(response) }
                }
                else {
                    sliderIsEditing = false
                    sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalOnOff, indexTimer: indexTimer, state: 0) { response in print(response) }
                }
            })
            .padding()
            .frame(height: 100)
            .background(dégradéCouleur)
            .cornerRadius(15)
            .padding()
            
        }
        
        
        .onAppear {
            if let hourInDate = Calendar.current.date(from: listOfSegments[index].hourStart) {
                pickerHourIn = hourInDate
            }
            if listOfSegments.indices.contains(index+1) {
                if let hourInDate = Calendar.current.date(from: listOfSegments[index + 1].hourStart) {
                    pickerHourOut = hourInDate
                }
            }
            else {
                if let hourInDate = Calendar.current.date(from: listOfSegments[0].hourStart) {
                    pickerHourOut = hourInDate
                }
            }
            
            tempKelvins = Double(1000000 / listOfSegments[index].temp)
        }
        .onChange(of: tempKelvins) { oldValue, newValue in
            tempMireds = Double(1000000 / tempKelvins)
            listOfSegments[index].temp = Int(tempMireds)
            listOfSegments[index].synced = .notSynced
            
            if sliderIsEditing {
                let currentTime = Date()
                if currentTime.timeIntervalSince(lastRequestTime) > 0.5 {
                    lastRequestTime = currentTime
                    let temp = Int(1000000 / newValue)
                    sendPUTGroupRequest(ip: ip, groupIndex: 81, ct: temp) { response in
                    }
                }
            }
        }
        .onChange(of: pickerHourIn) { oldValue, newValue in
            listOfSegments[index].hourStart = Calendar.current.dateComponents([.hour, .minute], from: pickerHourIn)
            listOfSegments[index].synced = .notSynced
        }
        .onChange(of: pickerHourOut) { oldValue, newValue in
            if listOfSegments.indices.contains(index+1) {
                listOfSegments[index+1].hourStart = Calendar.current.dateComponents([.hour, .minute], from: pickerHourOut)
                listOfSegments[index+1].synced = .notSynced
            }
            else {
                listOfSegments[0].hourStart = Calendar.current.dateComponents([.hour, .minute], from: pickerHourOut)
                listOfSegments[0].synced = .notSynced
            }
        }
        
        
        
    }
}







#Preview {
    EditSegment(index: 0, listOfSegments: .constant(defaultListOfSegments))
}
