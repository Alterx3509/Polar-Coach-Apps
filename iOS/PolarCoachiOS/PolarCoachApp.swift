import SwiftUI

@main
struct PolarCoachApp: App {
    @StateObject private var store = TrainingStore()
    @StateObject private var healthKit = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
                .environmentObject(healthKit)
        }
    }
}
