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

    // KVO observation on toolbar.isVisible — guards against SwiftUI flipping it to false
    private var toolbarObservation: NSKeyValueObservation?
    private var observedToolbar: NSToolbar?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleStyle()
    }

    func scheduleStyle() {
        applyWindowStyle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyWindowStyle()
            self?.hideSplitViewDividers()
            self?.installToolbarGuard()
        }
    }

    // MARK: - Toolbar Guard (KVO)

    /// Устанавливает KVO-наблюдатель на toolbar.isVisible.
    /// Когда SwiftUI или AppKit сбрасывает isVisible = false (overlay-режим),
    /// наблюдатель немедленно восстанавливает isVisible = true.
    private func installToolbarGuard() {
        guard let toolbar = window?.toolbar else { return }
        // Переустанавливаем только если тулбар сменился
        guard toolbar !== observedToolbar else { return }

        toolbarObservation?.invalidate()
        toolbarObservation = nil
        observedToolbar = toolbar

        toolbarObservation = toolbar.observe(\.isVisible, options: [.new]) { [weak self] tb, change in
            guard let self, let newVal = change.newValue, !newVal else { return }
            // Восстанавливаем на следующем цикле runloop чтобы не входить в рекурсию
            DispatchQueue.main.async {
                if let toolbar = self.window?.toolbar, !toolbar.isVisible {
                    toolbar.isVisible = true
                }
            }
        }
    }

    // MARK: - Style Application

    private func applyWindowStyle() {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none

        // Форсируем toolbar в фиксированный (не overlay) режим.
        if let toolbar = window.toolbar, !toolbar.isVisible {
            toolbar.isVisible = true
        }

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
