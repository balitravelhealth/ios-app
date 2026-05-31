//
//  BaliTravelHealthApp.swift
//  BaliTravelHealth
//
//  Created by Bergz on 3/5/26.
//

import SwiftUI
import SwiftData

@main
struct BaliTravelHealthApp: App {
    @State private var auth = AuthenticationManager()
    @State private var profileStore = ProfileStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            HealthcareFacility.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(profileStore)
        }
        .modelContainer(sharedModelContainer)
    }
}
