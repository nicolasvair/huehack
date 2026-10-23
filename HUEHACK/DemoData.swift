// DemoData.swift — flip demoMode to true to preview UI without a bridge

import Foundation

// ← flip this to enable / disable demo mode
let demoMode = false

// MARK: - Fake rooms

let demoGroups: [String: RoomResponse] = {
    func room(_ name: String, ct: Int, hue: Int? = nil, sat: Int? = nil) -> RoomResponse {
        RoomResponse(
            name: name,
            lights: ["1", "2"],
            sensors: [],
            type: "Room",
            state: RoomState(allOn: true, anyOn: true),
            recycle: false,
            class: "Living room",
            action: RoomAction(on: true, bri: 200, hue: hue, sat: sat,
                               effect: nil, xy: nil, ct: ct, alert: "none",
                               colormode: hue == nil ? "ct" : "hs"),
            stream: nil,
            locations: nil
        )
    }
    return [
        "1": room("Salon",   ct: 280),
        "2": room("Chambre", ct: 370, hue: 50000, sat: 200),  // paused, manual colour
        "3": room("Bureau",  ct: 250),
        "4": room("Cuisine", ct: 300),
    ]
}()

// MARK: - Fake circadian pause
// Rooms whose circadian is paused (manual colour). Mutated by the RoomOverride
// helpers in demo mode instead of talking to a bridge.

var demoPausedRooms: Set<String> = ["2"]

// MARK: - Fake segments for group "1"
// Includes .notSynced and hourChanged states so all UI elements are visible.

let demoSegments: [Segment] = [
    Segment(name: "nightEnd",      hourStart: DateComponents(hour: 5,  minute: 22), temp: 500, synced: .synced,    show: false),
    Segment(name: "dawn",          hourStart: DateComponents(hour: 6,  minute: 4),  temp: 325, synced: .synced,    show: true),
    Segment(name: "sunrise",       hourStart: DateComponents(hour: 6,  minute: 38), temp: 300, synced: .notSynced, show: true),  // → shows update colors
    Segment(name: "sunriseEnd",    hourStart: DateComponents(hour: 7,  minute: 10),
            temp: 275, synced: .synced, show: true,
            hourChanged: true,
            newHourStart: DateComponents(hour: 7, minute: 18)),                                                                  // → shows update sun hours
    Segment(name: "goldenHourEnd", hourStart: DateComponents(hour: 8,  minute: 5),  temp: 250, synced: .synced,    show: true),
    Segment(name: "solarNoon",     hourStart: DateComponents(hour: 13, minute: 20), temp: 250, synced: .synced,    show: true),
    Segment(name: "goldenHour",    hourStart: DateComponents(hour: 19, minute: 45), temp: 250, synced: .synced,    show: true),
    Segment(name: "sunsetStart",   hourStart: DateComponents(hour: 20, minute: 30), temp: 280, synced: .synced,    show: true),
    Segment(name: "dusk",          hourStart: DateComponents(hour: 21, minute: 15), temp: 290, synced: .synced,    show: true),
    Segment(name: "night",         hourStart: DateComponents(hour: 22, minute: 5),  temp: 350, synced: .synced,    show: true),
    Segment(name: "nadir",         hourStart: DateComponents(hour: 1,  minute: 30), temp: 500, synced: .synced,    show: true),
]
