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
        styleAllSplitViews(in: contentView)
    }

    /// Рекурсивно находит и стилизует все NSSplitView в иерархии
    private func styleAllSplitViews(in view: NSView) {
        if let sv = view as? NSSplitView {
            styleSplitView(sv)
        }
        for sub in view.subviews {
            styleAllSplitViews(in: sub)
        }
    }

    private func styleSplitView(_ splitView: NSSplitView) {
        // Скрываем divider — subview не входящий в arrangedSubviews
        let arranged = Set(splitView.arrangedSubviews.map { ObjectIdentifier($0) })
        for sub in splitView.subviews where !arranged.contains(ObjectIdentifier(sub)) {
            sub.alphaValue = 0
        }

        // Убираем NSVisualEffectView (серый фон сайдбара) в каждой колонке
        for column in splitView.arrangedSubviews {
            removeVisualEffect(in: column, depth: 2)
        }
    }

    private func removeVisualEffect(in view: NSView, depth: Int) {
        guard depth >= 0 else { return }
        if let vev = view as? NSVisualEffectView {
            vev.material = .windowBackground
            vev.blendingMode = .withinWindow
            vev.state = .inactive
            vev.wantsLayer = true
            vev.layer?.backgroundColor = .clear
        }
        for sub in view.subviews {
            removeVisualEffect(in: sub, depth: depth - 1)
        }
    }
}
