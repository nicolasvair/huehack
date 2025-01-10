//
//  SunPositionView.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 10/01/2025.
//

import SwiftUI

import SunCalc
import Foundation
import CoreLocation


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    
    @Published var latitude: Double?
    @Published var longitude: Double?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    func getSingleLocation() {
        locationManager.requestLocation() // Request location once
        print()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
}




struct SunPositionView: View {
    
    let date = Date()
    @StateObject private var locationManager = LocationManager()
        
    var body: some View {
        
        

        Text("Hello, World!")
        
        Button {
            locationManager.getSingleLocation()
            
            locationManager.latitude = 48.85035817703762
            locationManager.longitude = 2.425457625295625
            
            
            print("latitude : \(locationManager.latitude), longitude : \(locationManager.longitude)")

            let timeOfSun = SunCalc.getTimes(date: Date(), latitude: locationManager.latitude!, longitude: locationManager.longitude!)
            
            print("sunrise : \(timeOfSun.sunrise)")
            print("sunriseEnd : \(timeOfSun.sunriseEnd  )")
            print("goldenHourEnd : \(timeOfSun.goldenHourEnd)")
            print("solarNoon : \(timeOfSun.solarNoon)")
            print("goldenHour : \(timeOfSun.goldenHour)")
            print("sunsetStart : \(timeOfSun.sunsetStart)")
            print("dusk : \(timeOfSun.dusk)")
            print("night : \(timeOfSun.night)")
            print("nadir : \(timeOfSun.nadir)")
            print("nightEnd : \(timeOfSun.nightEnd)")
            print("dawn : \(timeOfSun.dawn)")

            

        } label: {
            Text("test")
        }
        .onAppear {
//            locationManager.locationManager(<#T##manager: CLLocationManager##CLLocationManager#>, didFailWithError: <#T##any Error#>)
            locationManager.getSingleLocation()
        }



        
        // Example Usage
        /*
        if let sunPositions = calculateSunPositions(for: Date(), latitude: 37.7749, longitude: -122.4194) {
            for position in sunPositions {
                print("Time: \(position.time), Altitude: \(position.altitude), Azimuth: \(position.azimuth)")
            }
        }
         */

    }
}

// get today's sunlight times for London


#Preview {
    SunPositionView()
}
