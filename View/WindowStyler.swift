import SwiftUI
import AppKit

/// Невидимый NSView, который при встраивании в иерархию находит своё окно
/// и применяет к нему нужный стиль: тулбар и скрытие разделителей колонок.
struct WindowStyler: NSViewRepresentable {
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

    /// Скрывает системные разделители NSSplitView, окрашивая их в цвет фона
    private func hideSplitViewDividers() {
        guard let contentView = window?.contentView,
              let bgColor = NSColor(named: "PrimaryAccent") else { return }
        hideDividers(in: contentView, color: bgColor)
    }

    private func hideDividers(in view: NSView, color: NSColor) {
        if let splitView = view as? NSSplitView {
            splitView.dividerStyle = .thin
            let arranged = Set(splitView.arrangedSubviews.map { ObjectIdentifier($0) })
            for sub in splitView.subviews {
                if !arranged.contains(ObjectIdentifier(sub)) {
                    sub.wantsLayer = true
                    sub.layer?.backgroundColor = color.cgColor
                    // Скрываем и дочерние views внутри divider-view
                    for child in sub.subviews {
                        child.isHidden = true
                    }
                }
                hideDividers(in: sub, color: color)
            }
        } else {
            for sub in view.subviews {
                hideDividers(in: sub, color: color)
            }
        }
    }
}
