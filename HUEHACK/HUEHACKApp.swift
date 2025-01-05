//
//  HUEHACKApp.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import SwiftUI

@main
struct HUEHACKApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack{
                SetHoursView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
