//
//  Segment.swift
//  HUEHACK
//
//  One time segment of a room's circadian schedule (one bridge rule).
//

import Foundation

struct Segment: Identifiable {
    var id = UUID()
    
    var name: String
    var hourStart: DateComponents // hour + minute only
    var temp: Int                 // mireds (153 cool … 500 warm)
    var synced: Synced
    var show: Bool?
    var hourChanged: Bool = false
    var newHourStart: DateComponents? = nil
    var tempChanged: Bool = false
    var newTemp: Int? = nil
}

enum Synced {
    case synced, notSynced
}

/// "7h05".
func timeStr(_ dc: DateComponents) -> String {
    "\(dc.hour ?? 0)h\(String(format: "%02d", dc.minute ?? 0))"
}
