import SwiftUI
import SwiftData
import AppKit

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
            WorldLocation.self,
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
            // При несовместимости схемы (например, после добавления новых моделей)
            // удаляем старый файл базы и пересоздаём контейнер с чистого листа
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
        }
        // Внедряем контейнер в приложение, чтобы @Query в WelcomeView работал
        .modelContainer(sharedModelContainer)
    }
}
