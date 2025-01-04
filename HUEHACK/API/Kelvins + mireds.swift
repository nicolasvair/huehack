//
//  Kelvins color.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import SwiftUI

extension Color {
    /// Crée une couleur à partir de la température en kelvin
    /// - Parameter kelvin: Température en kelvin (1000K - 40000K)
    init(kelvin: Double) {
        let temperature = max(1000, min(kelvin, 40000)) / 100.0
        
        var red: Double
        var green: Double
        var blue: Double
        
        if temperature <= 66 {
            red = 255
        } else {
            red = temperature - 60
            red = 329.698727446 * pow(red, -0.1332047592)
            red = max(0, min(red, 255))
        }
        
        if temperature <= 66 {
            green = temperature
            green = 99.4708025861 * log(green) - 161.1195681661
            green = max(0, min(green, 255))
        } else {
            green = temperature - 60
            green = 288.1221695283 * pow(green, -0.0755148492)
            green = max(0, min(green, 255))
        }
        
        if temperature >= 66 {
            blue = 255
        } else {
            if temperature <= 19 {
                blue = 0
            } else {
                blue = temperature - 10
                blue = 138.5177312231 * log(blue) - 305.0447927307
                blue = max(0, min(blue, 255))
            }
        }
        
        self.init(
            .sRGB,
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: 1.0
        )
    }
}




extension Color {
    /// Initializes a `Color` from a Mireds value.
    /// - Parameter mireds: The Mireds value (153 to 500).
    init(mireds: Double) {
        // Convert Mireds to Kelvin
        let kelvin = 1_000_000 / mireds
        
        // Ensure Kelvin stays within realistic bounds
        let temperature = max(1000, min(kelvin, 40000)) / 100.0
        
        var red: Double
        var green: Double
        var blue: Double
        
        // Calculate red
        if temperature <= 66 {
            red = 255
        } else {
            red = temperature - 60
            red = 329.698727446 * pow(red, -0.1332047592)
            red = max(0, min(red, 255))
        }
        
        // Calculate green
        if temperature <= 66 {
            green = temperature
            green = 99.4708025861 * log(green) - 161.1195681661
            green = max(0, min(green, 255))
        } else {
            green = temperature - 60
            green = 288.1221695283 * pow(green, -0.0755148492)
            green = max(0, min(green, 255))
        }
        
        // Calculate blue
        if temperature >= 66 {
            blue = 255
        } else {
            if temperature <= 19 {
                blue = 0
            } else {
                blue = temperature - 10
                blue = 138.5177312231 * log(blue) - 305.0447927307
                blue = max(0, min(blue, 255))
            }
        }
        
        self.init(
            .sRGB,
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: 1.0
        )
    }
}



extension Int {
    var miredsToKelvin: Int {
        return Int(1000000 / self)
    }
}
