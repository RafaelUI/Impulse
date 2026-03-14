import SwiftUI
import SwiftData
import AppKit

@main
struct ImpulseApp: App {

    @StateObject private var languageManager = LanguageManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WritingProject.self,
            Character.self,
            Chapter.self,
            WorldBuilding.self,
            WorldLocation.self,
            WorldResource.self,
            MetaphysicsConcept.self,
            WorldConcept.self,
            WorldStructure.self,
            TimelineTrack.self,
            TrashItem.self,
            ChapterSnapshot.self,
            ScreenScene.self,
            ScreenRole.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            try? FileManager.default.removeItem(at: modelConfiguration.url)
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Не удалось создать ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            WelcomeView()
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .onAppear { purgeExpiredTrashItems() }
                .preferredColorScheme(.dark)
                // Ключевое: передаём locale всему дереву view.
                // При смене languageManager.currentLanguage все Text("...") мгновенно перерисовываются.
                .environment(\.locale, languageManager.currentLocale)
                .environmentObject(languageManager)
        }
        .modelContainer(sharedModelContainer)
    }

    private func purgeExpiredTrashItems() {
        let context = sharedModelContainer.mainContext
        let now = Date()
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.deletedAt < twoMonthsAgo }
        )
        if let expired = try? context.fetch(descriptor) {
            for item in expired { context.delete(item) }
            try? context.save()
        }
    }
}
