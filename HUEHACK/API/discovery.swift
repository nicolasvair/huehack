//
//  discovery.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 01/08/2025.
//

import Foundation
import Network

enum DiscoveryStatus {
    case notStarted
    case searching
    case found
    case failed
}

class HueBridgeDiscovery: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    
//    var ipAdressBridge: String?
    @Published var status: DiscoveryStatus = .notStarted

    override init() {
        super.init()
        browser.delegate = self
    }

    func startDiscovery() {
        status = .searching
        browser.searchForServices(ofType: "_hue._tcp.", inDomain: "local.")
        print("Starting mDNS discovery for Hue bridges...")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Found service: \(service.name)")
        status = .found
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        if let addresses = sender.addresses {
            for addressData in addresses {
                addressData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                    let sockaddrPointer = pointer.bindMemory(to: sockaddr.self).baseAddress!
                    if sockaddrPointer.pointee.sa_family == sa_family_t(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(sockaddrPointer, socklen_t(addressData.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ipAddress = String(cString: hostname)
                            UserDefaults.standard.set(ipAddress, forKey: "hueBridgeIP")
                            print("Hue Bridge IP: \(ipAddress)")
                            status = .found
                        }
                    }
                }
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Failed to resolve service: \(sender.name), error: \(errorDict)")
        status = .failed
    }
}

