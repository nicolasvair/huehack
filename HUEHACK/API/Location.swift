//
//  location.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//
import CoreLocation


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    
    @Published var latitude = 0.0
    @Published var longitude = 0.0
    @Published var cityName: String?
    
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
    
    
    func fetchCityName() {
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocode failed: \(error.localizedDescription)")
                return
            }
            
            if let city = placemarks?.first?.locality {
                DispatchQueue.main.async {
                    self.cityName = city
                    print("City name found: \(city)")
                }
            } else {
                print("City not found")
            }
        }
    }

}
