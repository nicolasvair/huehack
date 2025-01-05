//
//  DefaultValues Lists.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 05/01/2025.
//

import Foundation

var defaultListOfSegments = [
    Segment(name: "Sunrise", hourStart: DateComponents.init(hour:8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Daylight", hourStart: DateComponents.init(hour:10, minute: 0), temp: 250, synced: .notSynced),
    Segment(name: "Sunset", hourStart: DateComponents.init(hour:17, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents.init(hour:20, minute: 0), temp: 350, synced: .notSynced),
    Segment(name: "Night", hourStart: DateComponents.init(hour:0, minute: 0), temp: 420, synced: .notSynced)
]



var list1 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced)
]

var list2 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced)
]

var list3 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Daylight", hourStart: DateComponents(hour: 12, minute: 0), temp: 250, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced)
]

var list4 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Morning", hourStart: DateComponents(hour: 10, minute: 0), temp: 280, synced: .notSynced),
    Segment(name: "Afternoon", hourStart: DateComponents(hour: 15, minute: 0), temp: 260, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced)
]

var list5 = defaultListOfSegments // inchangée

var list6 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Morning", hourStart: DateComponents(hour: 10, minute: 0), temp: 280, synced: .notSynced),
    Segment(name: "Daylight", hourStart: DateComponents(hour: 12, minute: 0), temp: 250, synced: .notSynced),
    Segment(name: "Afternoon", hourStart: DateComponents(hour: 15, minute: 0), temp: 260, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced),
    Segment(name: "Night", hourStart: DateComponents(hour: 23, minute: 0), temp: 420, synced: .notSynced)
]

var list7 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Morning", hourStart: DateComponents(hour: 10, minute: 0), temp: 280, synced: .notSynced),
    Segment(name: "Daylight", hourStart: DateComponents(hour: 12, minute: 0), temp: 250, synced: .notSynced),
    Segment(name: "Afternoon", hourStart: DateComponents(hour: 15, minute: 0), temp: 260, synced: .notSynced),
    Segment(name: "Sunset", hourStart: DateComponents(hour: 18, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced),
    Segment(name: "Night", hourStart: DateComponents(hour: 23, minute: 0), temp: 420, synced: .notSynced)
]

var list8 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Morning", hourStart: DateComponents(hour: 10, minute: 0), temp: 280, synced: .notSynced),
    Segment(name: "Daylight", hourStart: DateComponents(hour: 12, minute: 0), temp: 250, synced: .notSynced),
    Segment(name: "Sunset", hourStart: DateComponents(hour: 18, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced),
    Segment(name: "Late Evening", hourStart: DateComponents(hour: 21, minute: 30), temp: 370, synced: .notSynced),
    Segment(name: "Pre-Night", hourStart: DateComponents(hour: 22, minute: 30), temp: 400, synced: .notSynced),
    Segment(name: "Night", hourStart: DateComponents(hour: 23, minute: 30), temp: 420, synced: .notSynced)
]

var list9 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Morning", hourStart: DateComponents(hour: 10, minute: 0), temp: 280, synced: .notSynced),
    Segment(name: "Daylight", hourStart: DateComponents(hour: 12, minute: 0), temp: 250, synced: .notSynced),
    Segment(name: "Afternoon", hourStart: DateComponents(hour: 15, minute: 0), temp: 260, synced: .notSynced),
    Segment(name: "Sunset", hourStart: DateComponents(hour: 18, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced),
    Segment(name: "Late Evening", hourStart: DateComponents(hour: 21, minute: 30), temp: 370, synced: .notSynced),
    Segment(name: "Pre-Night", hourStart: DateComponents(hour: 22, minute: 30), temp: 400, synced: .notSynced),
    Segment(name: "Night", hourStart: DateComponents(hour: 23, minute: 30), temp: 420, synced: .notSynced)
]

var list10 = [
    Segment(name: "Sunrise", hourStart: DateComponents(hour: 8, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Morning", hourStart: DateComponents(hour: 10, minute: 0), temp: 280, synced: .notSynced),
    Segment(name: "Daylight", hourStart: DateComponents(hour: 12, minute: 0), temp: 250, synced: .notSynced),
    Segment(name: "Afternoon", hourStart: DateComponents(hour: 15, minute: 0), temp: 260, synced: .notSynced),
    Segment(name: "Sunset", hourStart: DateComponents(hour: 18, minute: 0), temp: 300, synced: .notSynced),
    Segment(name: "Evening", hourStart: DateComponents(hour: 20, minute: 0), temp: 350, synced: .notSynced),
    Segment(name: "Late Evening", hourStart: DateComponents(hour: 21, minute: 0), temp: 370, synced: .notSynced),
    Segment(name: "Nightfall", hourStart: DateComponents(hour: 22, minute: 0), temp: 390, synced: .notSynced),
    Segment(name: "Pre-Night", hourStart: DateComponents(hour: 23, minute: 0), temp: 410, synced: .notSynced),
    Segment(name: "Night", hourStart: DateComponents(hour: 23, minute: 45), temp: 420, synced: .notSynced)
]
