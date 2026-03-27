import SwiftUI
import SwiftData
import AppKit

@main
struct ImpulseApp: App {

    @StateObject private var languageManager = LanguageManager.shared
    @AppStorage("appColorScheme") private var colorSchemeRaw: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.Cloud.Impulse")
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {

            // Фоллбэк: удалить старый store и пересоздать локально
            // (это может произойти если схема изменилась и требует миграции)
            let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            if let storeURL = localConfiguration.url as URL? {
                try? FileManager.default.removeItem(at: storeURL)
            }
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
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
                .preferredColorScheme(preferredColorScheme)
                .environment(\.locale, languageManager.currentLocale)
                .environmentObject(languageManager)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    NSWorkspace.shared.open(URL(string: "https://impulsewriting.app/shortcuts")!)
                }
            }

            CommandMenu("Формат") {
                Button("Заголовок") {
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.applyHeading()
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Подзаголовок") {
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.applySubheading()
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Divider()

                Button("Курсив") {
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.applyItalic()
                }
                .keyboardShortcut("y", modifiers: [.command])

                Button("Подчёркнутый") {
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.applyUnderline()
                }
                .keyboardShortcut("u", modifiers: [.command])
            }
        }
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
