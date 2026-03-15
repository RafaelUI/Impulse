import SwiftUI
import AppKit
import SwiftData

// MARK: - Focus Window Manager
// Открывает окно фокусного редактора через AppKit напрямую,
// минуя SwiftUI WindowGroup (чтобы избежать краша NSMenu при переключении окон)

@MainActor
final class FocusWindowManager {

    static let shared = FocusWindowManager()
    private init() {}

    // Храним открытые окна по ID объекта, чтобы не дублировать
    private var openWindows: [UUID: NSWindow] = [:]

    func open(value: FocusEditorValue, modelContainer: ModelContainer) {
        // Если окно для этого объекта уже открыто — просто поднимем его
        if let existing = openWindows[value.id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = FocusEditorDispatchView(value: value)
            .modelContainer(modelContainer)

        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = [.minSize]

        let window = FocusNSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.isReleasedWhenClosed = false

        // Цвет фона из assets
        if let color = NSColor(named: "Editor") {
            window.backgroundColor = color
        }

        // Отслеживаем закрытие, чтобы освободить ссылку
        let id = value.id
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.openWindows.removeValue(forKey: id)
        }

        openWindows[id] = window
        window.makeKeyAndOrderFront(nil)
    }
}

// NSWindow-подкласс, который НЕ добавляется в список окон приложения как сцена SwiftUI
private final class FocusNSWindow: NSWindow {
    // Переопределяем, чтобы окно не замусоривало меню "Window"
    // (оно туда попадёт через стандартный NSApp.addWindowsItem, но без SwiftUI-дерева меню)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
