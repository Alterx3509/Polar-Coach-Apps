import SwiftUI

@main
struct PolarCoachApp: App {
    @StateObject private var store = TrainingStore()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
        }
    }
}
