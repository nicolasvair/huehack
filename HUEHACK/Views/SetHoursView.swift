//
//  SetHoursView.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//


import Foundation
import SwiftUI


 var defaultListOfSegments = [
    Segment(name: "Sunrise", hourIn: DateComponents.init(hour:8), temp: 300),
    Segment(name: "Daylight", hourIn: DateComponents.init(hour:10), temp: 250),
    Segment(name: "Sunset", hourIn: DateComponents.init(hour:17), temp: 300),
    Segment(name: "Evening", hourIn: DateComponents.init(hour:20), temp: 350),
    Segment(name: "Night", hourIn: DateComponents.init(hour:0), temp: 420)
    ]



struct Segment: Identifiable {
    var id = UUID()
    
    var name: String
    var hourIn: DateComponents // Représente uniquement l'heure et les minutes
    var temp: Int
}


struct SetHoursView: View {
    
    @State private var nbOfSegments = 4
    
    @State var listOfSegments = [Segment]()
    
    @State var firstAppear = true

    var body: some View {
    
        
        List(listOfSegments.indices, id: \.self) { index in
            NavigationLink {
                EditSegment(index: index, listOfSegments: $listOfSegments)
            } label: {
                HStack{
                    let segment = listOfSegments[index]
                    Text("\(String(segment.hourIn.hour!))h - \(segment.name) - \(segment.temp.miredsToKelvin) °K")
                    Spacer()
                    Rectangle()
                        .frame(width: 50)
                        .foregroundStyle(Color.init(mireds: Double(segment.temp)))
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

    }
    
}




#Preview {
    NavigationStack{
        SetHoursView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
