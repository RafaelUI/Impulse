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
    /// Поисковый запрос из тулбара — подсвечивает совпадения в тексте
    var searchQuery: String = ""

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
        if currentFont?.pointSize != CGFloat(targetSize) {
            applyFont(to: textView)
        }

        // Update padding
        let targetInset = NSSize(width: horizontalPadding, height: topPadding)
        if textView.textContainerInset != targetInset {
            textView.textContainerInset = targetInset
        }

        // NOTE: содержимое НЕ перезагружаем по сравнению RTF-байтов.
        // Сериализация RTF не идемпотентна (цветовые таблицы / нормализация
        // атрибутов), из-за чего любое сравнение почти всегда давало "не равно"
        // и триггерило перезагрузку, которая «запекала» чёрный цвет и сбрасывала
        // шрифты. Идентичность документа теперь задаётся через .id(chapter.id)
        // на уровне SwiftUI: при смене главы создаётся свежий NSTextView и
        // makeNSView -> loadContent отрабатывает заново.

        // Обновляем подсветку поискового запроса если он изменился
        if context.coordinator.lastHighlightedQuery != searchQuery {
            context.coordinator.lastHighlightedQuery = searchQuery
            applyHighlight(to: textView, query: searchQuery)
        }
    }

    // MARK: makeCoordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Helpers

    private func applyHighlight(to textView: NSTextView, query: String) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        // Сначала убираем все предыдущие подсветки
        storage.removeAttribute(.backgroundColor, range: fullRange)

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let text = storage.string as NSString
            var searchStart = 0
            while searchStart < storage.length {
                let range = text.range(
                    of: trimmed,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: NSRange(location: searchStart, length: storage.length - searchStart)
                )
                guard range.location != NSNotFound else { break }
                storage.addAttribute(
                    .backgroundColor,
                    value: NSColor(named: "AccentColor")?.withAlphaComponent(0.35) ?? NSColor.yellow.withAlphaComponent(0.4),
                    range: range
                )
                searchStart = range.location + max(range.length, 1)
            }
        }
        storage.endEditing()
    }

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

    /// Цвет текста редактора. Динамический системный/ассетный цвет, который
    /// следует за светлой/тёмной темой. Намеренно НЕ хранится в RTF —
    /// применяется только для отображения (см. applyTextColor / textDidChange).
    private var displayTextColor: NSColor {
        NSColor(named: "PrimaryText") ?? .labelColor
    }

    /// Принудительно проставляет цвет текста по всему содержимому и в
    /// typingAttributes. Без этого RTF round-trip терял цвет и текст
    /// становился чёрным (невидимым на тёмном фоне редактора).
    private func applyTextColor(to textView: NSTextView) {
        let color = displayTextColor
        if let storage = textView.textStorage, storage.length > 0 {
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: color,
                                 range: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }
        textView.typingAttributes[.foregroundColor] = color
        textView.insertionPointColor = color
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
        // Цвет применяем поверх любого загруженного контента (и пустого тоже).
        applyTextColor(to: textView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false
        var lastHighlightedQuery: String = ""

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            // Убираем подсветку как только пользователь начал печатать
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)
            storage.endEditing()
            lastHighlightedQuery = ""
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }

            isEditing = true
            defer { isEditing = false }

            // Extract plain text
            parent.plainText = storage.string

            // Extract RTF БЕЗ цвета текста, чтобы он не "запекался" в данные
            // и оставался независимым от темы (цвет проставляется при загрузке).
            let stripped = NSMutableAttributedString(attributedString: storage)
            let range = NSRange(location: 0, length: stripped.length)
            stripped.removeAttribute(.foregroundColor, range: range)
            if let rtf = stripped.rtf(from: range, documentAttributes: [:]) {
                parent.rtfData = rtf
            }
        }
    }
}

// MARK: - Text formatting helpers (called from Format menu)

extension NSTextView {

    /// Заголовок — Georgia 22pt Bold
    func applyHeading() {
        applyParagraphFont(size: 22, bold: true)
    }

    /// Подзаголовок — Georgia 17pt Bold
    func applySubheading() {
        applyParagraphFont(size: 17, bold: true)
    }

    /// Курсив — переключает italic на выделении (или на слове под курсором)
    func applyItalic() {
        guard let storage = textStorage else { return }
        let range = effectiveSelectionRange()
        guard range.length > 0 else { return }

        // Определяем: весь ли диапазон уже italic
        var allItalic = true
        storage.enumerateAttribute(.font, in: range) { val, _, stop in
            guard let font = val as? NSFont else { allItalic = false; stop.pointee = true; return }
            if !font.fontDescriptor.symbolicTraits.contains(.italic) {
                allItalic = false
                stop.pointee = true
            }
        }

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { val, r, _ in
            guard let font = val as? NSFont else { return }
            let newFont = allItalic
                ? NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                : NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: newFont, range: r)
        }
        storage.endEditing()
        didChangeText()
    }

    /// Подчёркивание — переключает underline на выделении
    func applyUnderline() {
        guard let storage = textStorage else { return }
        let range = effectiveSelectionRange()
        guard range.length > 0 else { return }

        // Определяем: весь ли диапазон уже подчёркнут
        var allUnderlined = true
        storage.enumerateAttribute(.underlineStyle, in: range) { val, _, stop in
            let style = (val as? Int) ?? 0
            if style == 0 { allUnderlined = false; stop.pointee = true }
        }

        let newStyle = allUnderlined ? 0 : NSUnderlineStyle.single.rawValue
        storage.beginEditing()
        if newStyle == 0 {
            storage.removeAttribute(.underlineStyle, range: range)
        } else {
            storage.addAttribute(.underlineStyle, value: newStyle, range: range)
        }
        storage.endEditing()
        didChangeText()
    }

    // MARK: Private helpers

    private func applyParagraphFont(size: CGFloat, bold: Bool) {
        guard let storage = textStorage else { return }
        let range = effectiveParagraphRange()

        let baseFont = NSFont(name: "Georgia", size: size)
            ?? NSFont.systemFont(ofSize: size)
        let font = bold
            ? NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            : baseFont

        storage.beginEditing()
        storage.addAttribute(.font, value: font, range: range)
        storage.endEditing()
        didChangeText()
    }

    /// Диапазон выделения (если есть) — для inline-стилей
    private func effectiveSelectionRange() -> NSRange {
        selectedRange()
    }

    /// Диапазон целых параграфов выделения — для блочных стилей (заголовки)
    private func effectiveParagraphRange() -> NSRange {
        let sel = selectedRange()
        let str = string as NSString
        if sel.length > 0 { return str.paragraphRange(for: sel) }
        return str.paragraphRange(for: NSRange(location: sel.location, length: 0))
    }
}
