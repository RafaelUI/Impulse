import SwiftUI
import AppKit

// MARK: - RichTextEditor
//
// NSViewRepresentable wrapping NSTextView with RTF storage.
// Stores formatted text as RTF Data; also keeps a plain-text
// mirror updated on every change for search and export.

struct RichTextEditor: NSViewRepresentable {

    /// RTF data binding (what gets persisted in SwiftData)
    @Binding var rtfData: Data
    /// Plain-text mirror binding (for search / export / word count)
    @Binding var plainText: String

    var fontSize: Double
    var horizontalPadding: Double
    var topPadding: Double

    // MARK: makeNSView

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = true
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(
            width: horizontalPadding,
            height: topPadding
        )

        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        applyFont(to: textView)
        loadContent(into: textView)

        return scrollView
    }

    // MARK: updateNSView

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update font when settings change
        let currentFont = textView.font
        let targetSize = fontSize
        if currentFont?.pointSize != targetSize {
            applyFont(to: textView)
        }

        // Update padding
        let targetInset = NSSize(width: horizontalPadding, height: topPadding)
        if textView.textContainerInset != targetInset {
            textView.textContainerInset = targetInset
        }

        // Only reload content if the data changed externally
        // (not from typing in this view — guard against feedback loop)
        guard !context.coordinator.isEditing else { return }

        let currentRTF = textView.textStorage.flatMap {
            $0.rtf(from: NSRange(location: 0, length: $0.length),
                   documentAttributes: [:])
        } ?? Data()

        if currentRTF != rtfData {
            loadContent(into: textView)
        }
    }

    // MARK: makeCoordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Helpers

    private func applyFont(to textView: NSTextView) {
        let font = NSFont(name: "Georgia", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)

        // Apply to entire storage if not empty
        if let storage = textView.textStorage, storage.length > 0 {
            storage.beginEditing()
            storage.enumerateAttribute(.font,
                                       in: NSRange(location: 0, length: storage.length)) { existingFont, range, _ in
                guard let existingFont = existingFont as? NSFont else { return }
                // Preserve traits (bold, italic) but update point size and family
                let newFont = NSFontManager.shared.convert(existingFont,
                                                           toSize: font.pointSize)
                storage.addAttribute(.font, value: newFont, range: range)
            }
            storage.endEditing()
        }
        textView.typingAttributes[.font] = font
    }

    private func loadContent(into textView: NSTextView) {
        if !rtfData.isEmpty,
           let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            // Restore text, then re-apply font size (RTF stores its own fonts)
            textView.textStorage?.setAttributedString(attrStr)
            applyFont(to: textView)
        } else if !plainText.isEmpty {
            // Migration path: existing plain text, no RTF yet
            let font = NSFont(name: "Georgia", size: fontSize)
                ?? NSFont.systemFont(ofSize: fontSize)
            let attrStr = NSAttributedString(
                string: plainText,
                attributes: [.font: font]
            )
            textView.textStorage?.setAttributedString(attrStr)
        } else {
            textView.string = ""
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }

            isEditing = true
            defer { isEditing = false }

            // Extract plain text
            parent.plainText = storage.string

            // Extract RTF
            let range = NSRange(location: 0, length: storage.length)
            if let rtf = storage.rtf(from: range, documentAttributes: [:]) {
                parent.rtfData = rtf
            }
        }
    }
}

// MARK: - Heading / Subheading helpers (called from menu)

extension NSTextView {

    /// Applies a heading style to the current selection (or paragraph if empty selection)
    func applyHeading() {
        applyParagraphStyle(fontSize: 26, bold: true)
    }

    /// Applies a subheading style to the current selection
    func applySubheading() {
        applyParagraphStyle(fontSize: 20, bold: true)
    }

    private func applyParagraphStyle(fontSize: CGFloat, bold: Bool) {
        guard let storage = textStorage else { return }
        let range = effectiveRange()

        let baseFont = NSFont(name: "Georgia", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
        let font = bold
            ? NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            : baseFont

        storage.beginEditing()
        storage.addAttribute(.font, value: font, range: range)
        storage.endEditing()
        didChangeText()
    }

    /// Range covering full paragraphs of the current selection
    private func effectiveRange() -> NSRange {
        let sel = selectedRange()
        let str = string as NSString
        if sel.length > 0 { return str.paragraphRange(for: sel) }
        // No selection — use paragraph under caret
        return str.paragraphRange(for: NSRange(location: sel.location, length: 0))
    }
}
