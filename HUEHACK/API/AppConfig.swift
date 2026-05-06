import Foundation

class AppConfig {
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
            let v = UserDefaults.standard.integer(forKey: "indexGlobalOnOff")
            return v == 0 ? 171 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: "indexGlobalOnOff") }
    }

    var indexTimer: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "indexTimer")
            return v == 0 ? 172 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: "indexTimer") }
    }

    var isConfigured: Bool {
        !ip.isEmpty && !username.isEmpty
    }
}
