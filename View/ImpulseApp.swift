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
        // Allow forcing a local-only store for diagnostics by setting the
        // environment variable IMPULSE_FORCE_LOCAL_DB=1 (useful when CloudKit
        // is causing corruption or you need to inspect data without syncing).
        let forceLocal = ProcessInfo.processInfo.environment["IMPULSE_FORCE_LOCAL_DB"] == "1"

        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.Cloud.Impulse")
        )

        let container: ModelContainer
        if forceLocal {
            // Create a local-only configuration (no CloudKit)
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                container = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Не удалось создать локальный ModelContainer: \(error)")
            }
        } else {
            do {
                container = try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                // CloudKit недоступен (нет сети, iCloud выключен) — открываем локально.
                // НЕ удаляем store: данные пользователя должны оставаться нетронутыми.
                let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                do {
                    container = try ModelContainer(for: schema, configurations: [localConfig])
                } catch {
                    fatalError("Не удалось создать ModelContainer: \(error)")
                }
            }
        }

        // Дедупликация проектов — запускается сразу после создания контейнера,
        // до первого рендера любого View. Удаляет дубли WritingProject с одинаковым id UUID,
        // которые могут появиться после сбоя CloudKit-синхронизации.
        let ctx = container.mainContext
        if let all = try? ctx.fetch(FetchDescriptor<WritingProject>()) {
            var seen: [UUID: WritingProject] = [:]
            var toDelete: [WritingProject] = []
            for project in all {
                if let existing = seen[project.id] {
                    let existingScore = (existing.chapters?.count ?? 0) + (existing.scenes?.count ?? 0)
                    let newScore      = (project.chapters?.count ?? 0)  + (project.scenes?.count ?? 0)
                    if newScore > existingScore {
                        toDelete.append(existing)
                        seen[project.id] = project
                    } else {
                        toDelete.append(project)
                    }
                } else {
                    seen[project.id] = project
                }
            }
            if !toDelete.isEmpty {
                toDelete.forEach { ctx.delete($0) }
                try? ctx.save()
            }
        }

        return container
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
