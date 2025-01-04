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
    
    @State var index: Int
    @Binding var listOfSegments: [Segment]

    @State private var pickerHourIn = Date()
    @State private var pickerHourOut = Date()
    
    @State private var tempKelvins = 200.0
    @State private var tempMireds = 200.0
    
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
                
                //            Text("Temp : \(Int(tempMireds)) mireds")
                //                .padding()
                //                .font(.title2)

            }
            Slider(value: $tempKelvins, in: 2000...5000)
                .padding()
                .frame(height: 100)
                .background(dégradéCouleur)
                .cornerRadius(15)
                .padding()
        }
        
        
        .onAppear {
            if let hourInDate = Calendar.current.date(from: listOfSegments[index].hourIn) {
                pickerHourIn = hourInDate
            }
            if listOfSegments.indices.contains(index+1) {
                if let hourInDate = Calendar.current.date(from: listOfSegments[index + 1].hourIn) {
                    pickerHourOut = hourInDate
                }
            }
            else {
                if let hourInDate = Calendar.current.date(from: listOfSegments[0].hourIn) {
                    pickerHourOut = hourInDate
                }
            }
            
            tempKelvins = Double(1000000 / listOfSegments[index].temp)
        }
        .onChange(of: tempKelvins) {
            tempMireds = Double(1000000 / tempKelvins)
            listOfSegments[index].temp = Int(tempMireds)
        }
        .onChange(of: pickerHourIn) {
            listOfSegments[index].hourIn = Calendar.current.dateComponents([.hour, .minute], from: pickerHourIn)
        }
        .onChange(of: pickerHourOut) {
            if listOfSegments.indices.contains(index+1) {
                listOfSegments[index+1].hourIn = Calendar.current.dateComponents([.hour, .minute], from: pickerHourOut)
            }
            else {
                listOfSegments[0].hourIn = Calendar.current.dateComponents([.hour, .minute], from: pickerHourOut)
            }
        }



    }
}







#Preview {
    EditSegment(index: 0, listOfSegments: .constant(defaultListOfSegments))
}
