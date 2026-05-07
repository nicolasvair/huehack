//
//  AppConfig.swift
//  HUEHACK
//

import Foundation

final class AppConfig {
    static let shared = AppConfig()
    private init() {}

    var ip: String {
        get { UserDefaults.standard.string(forKey: "hueBridgeIP") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "hueBridgeIP") }
    }

    var username: String {
        get { UserDefaults.standard.string(forKey: "usernameKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "usernameKey") }
    }

    var indexGlobalOnOff: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "hueIndexGlobalOnOff")
            if v > 0 { return v }
            // Migrate from old key
            let old = UserDefaults.standard.integer(forKey: "indexGlobalOnOff")
            return old > 0 ? old : 171
        }
        set { UserDefaults.standard.set(newValue, forKey: "hueIndexGlobalOnOff") }
    }

    var indexTimer: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "hueIndexTimer")
            if v > 0 { return v }
            // Migrate from old key
            let old = UserDefaults.standard.integer(forKey: "indexTimer")
            return old > 0 ? old : 172
        }
        set { UserDefaults.standard.set(newValue, forKey: "hueIndexTimer") }
    }

    var isConfigured: Bool {
        !ip.isEmpty && !username.isEmpty
    }
}

// Module-level aliases so all existing API functions keep working without changes
var ip: String { AppConfig.shared.ip }
var username: String { AppConfig.shared.username }
var indexGlobalOnOff: Int { AppConfig.shared.indexGlobalOnOff }
var indexTimer: Int { AppConfig.shared.indexTimer }
