//
//  2_rules.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//


// TO DO :

// PRIO
// ajouter mode "sync / non sync" avec raturer en rouge pour mise à jour des heures selon soleil +
// ajouter bouton et "scénario" pour upload
// gérer première arrivée = fill rules
// gérer la suite = show rules et adapt

// POUR SORTIE
// ajouter sous-vue pour localisation, gérer les autorisations etc

// POUR + TARD
// pouvoir ajouter créneaux "manuels" 



import SwiftUI
import SunCalc
import Foundation






struct __rules: View {
    
    let date = Date()
    @StateObject private var locationManager = LocationManager()
        
    @State private var listOfSegments = [Segment]()

    @State private var isEditing = false
    
    var body: some View {
            
        
        HStack{
                
                HStack{
                    Text("Sun hours for : ")
                    Group{
                        Text(locationManager.cityName ?? "Localisation")
                        Image(systemName: "scope")
                    }
                    .foregroundStyle(.accent)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button {
                    
                } label: {
                    Image(systemName: "plus")
                }
                
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
                            
                            if(segment.synced != .synced){
                                Image(systemName: "slider.horizontal.below.sun.max")
                            }
                            
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
                                
                                if(segment.hourChanged){
                                    HStack{
                                        Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                                        Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!))")
                                            .italic()
                                            .strikethrough()
                                        Image(systemName: "arrowshape.right")
//                                        Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                                        Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!))")
                                    }
                                    .foregroundColor(.sunHours)

                                }
                                else{
                                    Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!))")
                                }

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
                locationManager.latitude = 48.866669
                locationManager.longitude = 2.43333       //base value in case of following command doesn't work
                locationManager.getSingleLocation()
                
                listOfSegments = fillListOfSegmentsWrongHour(locationManager: locationManager)
                
//                listOfSegments += [ Segment(name: "coucher", hourStart: DateComponents.init(hour: 23 , minute: 0), temp: 420, synced: .notSynced, show: true) ]
                
                //            listOfSegments = listOfSegments.sorted { $0.hourStart.hour! < $1.hourStart.hour! }
                
                listOfSegments = listOfSegments.sorted { ($0.hourStart.hour! < 3 ? 24 + $0.hourStart.hour! : $0.hourStart.hour!) < ($1.hourStart.hour! < 3 ? 24 + $1.hourStart.hour! : $1.hourStart.hour!) }
                
                locationManager.fetchCityName()
            }
            
            VStack{
                Spacer()
                HStack{
                    //                    Button_With_Icon(text: "send to bridge", icon: "square.and.arrow.up")
                    Button_With_Icon(text: "update colors", icon: "slider.horizontal.below.sun.max")
                    Spacer()
                    Button_With_Icon(text: "update sun hours", icon: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                        .foregroundStyle(.sunHours)
                    // clock.arrow.trianglehead.2.counterclockwise.rotate.90
                    // slider.horizontal.below.sun.max
                }
            }
            .padding()
        }

        
    }
}


#Preview {
    __rules()
}



func fillListOfSegments(locationManager: LocationManager) -> [Segment] {
    
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

func fillListOfSegmentsWrongHour(locationManager: LocationManager) -> [Segment] {
    
    let timeOfSun = SunCalc.getTimes(date: Date(), latitude: locationManager.latitude, longitude: locationManager.longitude)
    
    
    var listOfSegments = [Segment]()
    
    listOfSegments += [ Segment(name: "nightEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nightEnd!), temp: 500, synced: .synced, show: false, hourChanged: true) ]

    listOfSegments += [ Segment(name: "dawn", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dawn!), temp: 325, synced: .synced, show: true, hourChanged: true) ]

    listOfSegments += [ Segment(name: "sunrise", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunrise!), temp: 300, synced: .synced, show: true) ]
    
    listOfSegments += [ Segment(name: "sunriseEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunriseEnd!), temp: 275, synced: .synced, show: true) ]

    listOfSegments += [ Segment(name: "goldenHourEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHourEnd!), temp: 250, synced: .synced, show: true) ]

    listOfSegments += [ Segment(name: "solarNoon", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.solarNoon!), temp: 250, synced: .synced, show: true) ]

    listOfSegments += [ Segment(name: "goldenHour", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHour!), temp: 250, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "sunsetStart", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunsetStart!), temp: 280, synced: .notSynced, show: true) ]

    listOfSegments += [ Segment(name: "dusk", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dusk!), temp: 290, synced: .synced, show: true) ]
    
    listOfSegments += [ Segment(name: "night", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.night!), temp: 350, synced: .synced, show: true) ]
    
    listOfSegments += [ Segment(name: "nadir", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nadir!), temp: 500, synced: .synced, show: true) ]

    return listOfSegments
}
