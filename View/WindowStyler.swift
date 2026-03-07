import SwiftUI
import AppKit

/// Невидимый NSView, который при встраивании в иерархию находит своё окно
/// и применяет к нему нужный стиль: тулбар и скрытие разделителей колонок.
struct WindowStyler: NSViewRepresentable {
    /// Передайте любое меняющееся значение чтобы триггерить повторную стилизацию
    var token: AnyHashable = 0

    func makeNSView(context: Context) -> StylerView {
        StylerView()
    }
    func updateNSView(_ nsView: StylerView, context: Context) {
        nsView.scheduleStyle()
    }
}

final class StylerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleStyle()
    }

    func scheduleStyle() {
        applyWindowStyle()
        // Применяем трижды с нарастающей задержкой — пока SwiftUI достраивает иерархию
        for delay in [0.05, 0.15, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.hideSplitViewDividers()
            }
        }
    }

    private func applyWindowStyle() {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        // Убираем separator под toolbar (deprecated в 15, но работает как fallback)
        #if compiler(>=5.9)
        if #available(macOS 15, *) { } else {
            window.toolbar?.showsBaselineSeparator = false
        }
        #endif
        if let color = NSColor(named: "PrimaryAccent") {
            window.backgroundColor = color
        }
        // Убираем vibrancy-материал тулбарной области
        if let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview {
            titlebarView.wantsLayer = true
            if let color = NSColor(named: "PrimaryAccent") {
                titlebarView.layer?.backgroundColor = color.cgColor
            }
        }
    }

    private func hideSplitViewDividers() {
        guard let contentView = window?.contentView else { return }
        // Ищем только верхний NSSplitView — не рекурсируем вглубь detail колонки
        guard let splitView = findTopSplitView(in: contentView) else { return }
        styleTopSplitView(splitView)
    }

    private func findTopSplitView(in view: NSView) -> NSSplitView? {
        if let sv = view as? NSSplitView { return sv }
        for sub in view.subviews {
            if let found = findTopSplitView(in: sub) { return found }
        }
        return nil
    }

    private func styleTopSplitView(_ splitView: NSSplitView) {
        splitView.dividerStyle = .thin

        // Скрываем divider-views (не arrangedSubviews) — красим в PrimaryAccent
        let arranged = Set(splitView.arrangedSubviews.map { ObjectIdentifier($0) })
        for sub in splitView.subviews where !arranged.contains(ObjectIdentifier(sub)) {
            sub.wantsLayer = true
            sub.layer?.backgroundColor = NSColor(named: "PrimaryAccent")?.cgColor
            sub.subviews.forEach { $0.isHidden = true }
        }

        // Только прямой NSVisualEffectView sidebar колонки — не рекурсируем вглубь
        if let sidebarColumn = splitView.arrangedSubviews.first {
            for sub in sidebarColumn.subviews {
                if let vev = sub as? NSVisualEffectView {
                    vev.material = .windowBackground
                    vev.blendingMode = .withinWindow
                    vev.state = .inactive
                    vev.wantsLayer = true
                    vev.layer?.cornerRadius = 0
                    vev.layer?.masksToBounds = false
                    vev.layer?.backgroundColor = .clear
                }
            }
            // Один уровень глубже — SwiftUI hosting view может обернуть VEV
            if let vev = sidebarColumn as? NSVisualEffectView {
                vev.material = .windowBackground
                vev.blendingMode = .withinWindow
                vev.state = .inactive
                vev.wantsLayer = true
                vev.layer?.cornerRadius = 0
                vev.layer?.masksToBounds = false
                vev.layer?.backgroundColor = .clear
            }
        }
    }
}
