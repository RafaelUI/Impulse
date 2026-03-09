import SwiftUI
import AppKit

// MARK: - Главный экран сравнения

struct SceneComparisonView: View {
    var project: WritingProject

    // Состояния экрана
    @State private var selectedScene: ScreenScene? = nil
    @State private var selectionA: SceneVariation? = nil
    @State private var selectionB: SceneVariation? = nil
    @State private var isComparing: Bool = false

    var body: some View {
        if isComparing, let a = selectionA, let b = selectionB {
            ComparisonResultView(variationA: a, variationB: b) {
                isComparing = false
            }
        } else {
            selectionScreen
        }
    }

    // MARK: Экран выбора

    private var selectionScreen: some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()

            VStack(spacing: 0) {
                // Заголовок + кнопки
                HStack {
                    Text("Сравнение вариаций")
                        .font(.headline)
                        .foregroundStyle(Color("PrimaryText"))
                    Spacer()

                    if selectionA != nil || selectionB != nil {
                        Button("Отменить") {
                            resetSelection()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                        .padding(.trailing, 8)
                    }

                    Button("Сравнить") {
                        guard selectionA != nil, selectionB != nil else { return }
                        isComparing = true
                    }
                    .buttonStyle(AccentToolbarButtonStyle())
                    .disabled(selectionA == nil || selectionB == nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()
                    .background(Color("Border"))

                // Список сцен
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(project.scenes.sorted { $0.orderIndex < $1.orderIndex }) { scene in
                            SceneComparisonRow(
                                scene: scene,
                                isExpanded: selectedScene?.id == scene.id,
                                selectionA: $selectionA,
                                selectionB: $selectionB,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedScene?.id == scene.id {
                                            selectedScene = nil
                                        } else {
                                            selectedScene = scene
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func resetSelection() {
        selectionA = nil
        selectionB = nil
        selectedScene = nil
    }
}

// MARK: - Строка сцены с раскрывающимися вариациями

private struct SceneComparisonRow: View {
    var scene: ScreenScene
    var isExpanded: Bool
    @Binding var selectionA: SceneVariation?
    @Binding var selectionB: SceneVariation?
    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок сцены
            Button(action: onTap) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color("SecondaryText"))
                        .frame(width: 16)

                    Text(scene.title.isEmpty ? "Без названия" : scene.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("PrimaryText"))

                    Spacer()

                    let count = scene.variations.count
                    Text("\(count) вар.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("SecondaryText"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Вариации
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(scene.variations) { variation in
                        VariationSelectionRow(
                            variation: variation,
                            state: rowState(for: variation),
                            onTap: { selectVariation(variation) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Divider()
                .background(Color("Border"))
                .padding(.leading, 20)
        }
    }

    private enum RowState { case none, selectedA, selectedB, disabled }

    private func rowState(for variation: SceneVariation) -> RowState {
        if selectionA?.id == variation.id { return .selectedA }
        if selectionB?.id == variation.id { return .selectedB }
        // Если уже выбраны 2 и это не одна из них — недоступна
        if selectionA != nil && selectionB != nil { return .disabled }
        return .none
    }

    private func selectVariation(_ variation: SceneVariation) {
        // Снять выделение
        if selectionA?.id == variation.id { selectionA = nil; return }
        if selectionB?.id == variation.id { selectionB = nil; return }
        // Назначить
        if selectionA == nil { selectionA = variation }
        else if selectionB == nil { selectionB = variation }
    }
}

// MARK: - Строка вариации с состоянием выделения

private struct VariationSelectionRow: View {
    var variation: SceneVariation
    var state: RowState
    var onTap: () -> Void

    enum RowState { case none, selectedA, selectedB, disabled }

    var body: some View {
        Button(action: { if state != .disabled { onTap() } }) {
            HStack(spacing: 10) {
                // Цветовой индикатор
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 8, height: 8)

                Text(variation.title)
                    .font(.system(size: 13))
                    .foregroundStyle(textColor)

                Spacer()

                if state == .selectedA {
                    Text("A")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 4))
                } else if state == .selectedB {
                    Text("B")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(backgroundFor(state: state), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .opacity(state == .disabled ? 0.4 : 1)
    }

    private var indicatorColor: Color {
        switch state {
        case .selectedA: return .blue
        case .selectedB: return .orange
        default: return Color("SecondaryText").opacity(0.4)
        }
    }

    private var textColor: Color {
        switch state {
        case .selectedA: return .blue
        case .selectedB: return .orange
        default: return Color("PrimaryText")
        }
    }

    private func backgroundFor(state: RowState) -> Color {
        switch state {
        case .selectedA: return Color.blue.opacity(0.08)
        case .selectedB: return Color.orange.opacity(0.08)
        default: return Color("SecondaryText").opacity(0.06)
        }
    }
}

// MARK: - Экран результата сравнения

struct ComparisonResultView: View {
    var variationA: SceneVariation
    var variationB: SceneVariation
    var onBack: () -> Void

    var body: some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()

            VStack(spacing: 0) {
                // Кнопка «Назад»
                HStack {
                    Spacer()
                    Button("Назад") { onBack() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                        .padding(.trailing, 20)
                }
                .padding(.vertical, 10)

                // Разделённые панели
                HStack(spacing: 0) {
                    // Левая панель — вариация A
                    DiffPaneView(
                        variation: variationA,
                        label: "A",
                        labelColor: .blue,
                        otherText: variationB.text
                    )

                    Rectangle()
                        .fill(Color("Border"))
                        .frame(width: 1)

                    // Правая панель — вариация B
                    DiffPaneView(
                        variation: variationB,
                        label: "B",
                        labelColor: .orange,
                        otherText: variationA.text
                    )
                }
            }
        }
    }
}

// MARK: - Панель одной вариации с diff-подсветкой

private struct DiffPaneView: View {
    var variation: SceneVariation
    var label: String
    var labelColor: Color
    var otherText: String

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок панели
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(labelColor, in: RoundedRectangle(cornerRadius: 4))
                    Text(variation.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("PrimaryText"))
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color("PrimaryAccent"))

            Divider().background(Color("Border"))

            // Текст с diff
            DiffTextView(
                text: variation.text,
                otherText: otherText,
                highlightColor: labelColor
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - NSTextView с AttributedString для diff

struct DiffTextView: NSViewRepresentable {
    var text: String
    var otherText: String
    var highlightColor: Color

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 24, height: 16)
        textView.font = NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor(named: "PrimaryText") ?? .labelColor

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(buildAttributedString())
    }

    /// Строит AttributedString: общие части — обычным цветом, уникальные — с фоновой подсветкой
    private func buildAttributedString() -> NSAttributedString {
        let baseFont = NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15)
        let baseColor = NSColor(named: "PrimaryText") ?? .labelColor
        let highlight = NSColor(highlightColor).withAlphaComponent(0.28)

        // Разбиваем на слова/токены
        let aTokens = tokenize(text)
        let bTokens = tokenize(otherText)

        // LCS diff
        let diffRanges = diffUniqueRanges(a: aTokens, b: bTokens)

        let result = NSMutableAttributedString()

        var charIndex = 0
        for (tokenIndex, token) in aTokens.enumerated() {
            let attrs: [NSAttributedString.Key: Any]
            if diffRanges.contains(tokenIndex) {
                attrs = [
                    .font: baseFont,
                    .foregroundColor: baseColor,
                    .backgroundColor: highlight
                ]
            } else {
                attrs = [
                    .font: baseFont,
                    .foregroundColor: baseColor
                ]
            }
            result.append(NSAttributedString(string: token, attributes: attrs))
            charIndex += token.count
        }

        return result
    }

    /// Разбивка на токены с сохранением пробелов/переносов строк
    private func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for ch in input {
            if ch == " " || ch == "\n" {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(ch))
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Возвращает индексы токенов в массиве `a`, которых нет в LCS(a, b)
    private func diffUniqueRanges(a: [String], b: [String]) -> Set<Int> {
        let lcs = longestCommonSubsequence(a: a, b: b)
        var lcsSet = Set(lcs)
        var unique: Set<Int> = []
        for (i, token) in a.enumerated() {
            if lcsSet.contains(token) {
                lcsSet.remove(token)
            } else {
                unique.insert(i)
            }
        }
        return unique
    }

    /// LCS через динамическое программирование
    private func longestCommonSubsequence(a: [String], b: [String]) -> [String] {
        let m = a.count, n = b.count
        // Ограничение для производительности на больших текстах
        guard m <= 2000, n <= 2000 else { return [] }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }

        // Обратный проход
        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] {
                result.append(a[i-1])
                i -= 1; j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return result.reversed()
    }
}
