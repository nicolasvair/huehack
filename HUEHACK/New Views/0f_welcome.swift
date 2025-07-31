//
//  0e_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 31/07/2025.
//

import SwiftUI
import SunCalc

struct _f_welcome: View {
    
    let date = Date()
    
    @StateObject private var locationManager = LocationManager()
    
    @State private var listOfSegments = [Segment]()
    
    @State private var isEditing = false
    
    
    var body: some View {
        
        HStack{
            
            HStack{
                Text("Sun hours for : ")
                    
                    Button {
                        locationManager.fetchCityName()
                    } label: {
                        Group{
                            Text(locationManager.cityName ?? "Locate me !")
                            Image(systemName: "scope")
                        }
                        .foregroundStyle(.accent)
                    }

            }
            .padding(.horizontal)
            
            Spacer()
                        
            Button(isEditing ? "Done" : "Edit") {
                isEditing.toggle()
            }
            .padding(.horizontal)
        }
        
        ZStack{
            List {
                ForEach(listOfSegments.indices, id: \.self) { index in
                    let segment = listOfSegments[index]
                    
                    if segment.show! || isEditing {
                        HStack {
                            
//                            if(segment.synced != .synced){
//                                Image(systemName: "slider.horizontal.below.sun.max")
//                            }
                            
                            if isEditing {
                                Button(action: {
                                    listOfSegments[index].show?.toggle()
                                }) {
                                    Image(systemName: listOfSegments[index].show! ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            VStack(alignment: .leading){
                                Text("\(segment.name)")
                                
                                Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!))")
                                
                            }
                            .italic(segment.synced == .synced ? false : true)
                            .fontWeight(segment.synced == .synced ? .regular : .light)
                            
                            Spacer()
                            
                            
                            
                            Text("\(segment.temp.miredsToKelvin) °K")
                                .font(.subheadline)
                            
                            Rectangle()
                                .frame(width: 50)
                                .foregroundStyle(Color(mireds: Double(segment.temp)))
                                .padding(7)
                            
                            
                        }
                        
                        
                    }
                    
                }
            }
            .onAppear {
//                locationManager.latitude = 48.866669
//                locationManager.longitude = 2.43333       //base value in case of following command doesn't work
                locationManager.getSingleLocation()
                
                listOfSegments = fillListOfSegmentsInit(locationManager: locationManager)
                                
                listOfSegments = listOfSegments.sorted { ($0.hourStart.hour! < 3 ? 24 + $0.hourStart.hour! : $0.hourStart.hour!) < ($1.hourStart.hour! < 3 ? 24 + $1.hourStart.hour! : $1.hourStart.hour!) }
                
                locationManager.fetchCityName()
            }
            
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    Button_With_Icon(text: "send to bridge", icon: "arrowshape.right")
                }
            }
            .padding()
        }
        
        
    }
    
}

#Preview {
    _f_welcome()
}







func fillListOfSegmentsInit(locationManager: LocationManager) -> [Segment] {
    
    let timeOfSun = SunCalc.getTimes(date: Date(), latitude: locationManager.latitude, longitude: locationManager.longitude)
    
    
    var listOfSegments = [Segment]()
    
    listOfSegments += [ Segment(name: "nightEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nightEnd!), temp: 500, synced: .notSynced, show: false) ]

    listOfSegments += [ Segment(name: "dawn", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dawn!), temp: 325, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "sunrise", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunrise!), temp: 300, synced: .notSynced, show: true) ]
    
    listOfSegments += [ Segment(name: "sunriseEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunriseEnd!), temp: 275, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "goldenHourEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHourEnd!), temp: 250, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "solarNoon", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.solarNoon!), temp: 250, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "goldenHour", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHour!), temp: 250, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "sunsetStart", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunsetStart!), temp: 280, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "dusk", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dusk!), temp: 290, synced: .notSynced, show: true) ]
    
    listOfSegments += [ Segment(name: "night", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.night!), temp: 350, synced: .notSynced, show: true) ]
    
    listOfSegments += [ Segment(name: "nadir", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nadir!), temp: 500, synced: .notSynced, show: true) ]

    return listOfSegments
}
