import SwiftUI

@main
struct PolarCoachApp: App {
    @StateObject private var store = TrainingStore()
    @StateObject private var healthKit = HealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
                .environmentObject(healthKit)
                .task {
                    await healthKit.requestAccess()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        store.refresh()
                        await healthKit.refresh()
                    }
                }
        }
    }
}
