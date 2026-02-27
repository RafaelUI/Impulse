import SwiftUI
import SwiftData

@main
struct ImpulseApp: App {
    // Создаем контейнер для всех наших моделей
    var sharedModelContainer: ModelContainer = {
        // Указываем схему данных: пока только WritingProject
        let schema = Schema([
            WritingProject.self,
            Character.self,
            Chapter.self,
            WorldBuilding.self,
            WorldResource.self,
            MetaphysicsConcept.self,
            WorldConcept.self,
            WorldStructure.self,
            TimelineEvent.self,
        ])
        
        // Настройка конфигурации (здесь в будущем можно включить iCloud)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
        // Внедряем контейнер в приложение, чтобы @Query в WelcomeView работал
        .modelContainer(sharedModelContainer)
    }
}

