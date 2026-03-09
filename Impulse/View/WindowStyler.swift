import SwiftUI
import AppKit

/// Невидимый NSView, который при встраивании в иерархию находит своё окно
/// и применяет к нему нужный стиль: прозрачный тулбар и цвет фона.
struct WindowStyler: NSViewRepresentable {
    var token: AnyHashable = 0

    func makeNSView(context: Context) -> StylerView {
        StylerView()
    }
    func updateNSView(_ nsView: StylerView, context: Context) {
        nsView.applyWindowStyle()
    }
}

final class StylerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWindowStyle()
    }

    func applyWindowStyle() {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        #if compiler(>=5.9)
        if #available(macOS 15, *) { } else {
            window.toolbar?.showsBaselineSeparator = false
        }
        #endif
        if let color = NSColor(named: "PrimaryAccent") {
            window.backgroundColor = color
        }
    }
}
