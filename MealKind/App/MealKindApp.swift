import SwiftUI
import SwiftData

@main
struct MealKindApp: App {
    private let services = ServiceContainer.live

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(\.services, services)
        }
        .modelContainer(for: [
            StoredHabit.self,
            StoredDailyTask.self,
            StoredUserSettings.self,
            StoredMealRecord.self,
            StoredWorkoutRecord.self,
            StoredSleepRecord.self,
            StoredWaterRecord.self,
            StoredWeightRecord.self,
            StoredSupplementRecord.self,
            StoredMeasurementRecord.self,
            StoredDailyStrategy.self,
            StoredWeeklyReview.self,
            StoredTrainingCycle.self
        ])
    }
}
