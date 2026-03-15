import SwiftUI
import SwiftData

// MARK: - Focus Editor Window Value

/// Передаётся в FocusWindowManager.open() для открытия редактора
struct FocusEditorValue: Codable, Hashable {
    enum Kind: String, Codable { case chapter, scene }
    let kind: Kind
    let id: UUID
}

// MARK: - Focus Editor Dispatcher
// Получает значение из FocusWindowManager и загружает нужную модель

struct FocusEditorDispatchView: View {
    let value: FocusEditorValue

    @AppStorage("appColorScheme") private var colorSchemeRaw: String = "system"
    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        Group {
            switch value.kind {
            case .chapter:
                FocusChapterEditorView(chapterID: value.id)
            case .scene:
                FocusSceneEditorView(sceneID: value.id)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

// MARK: - Focus Chapter Editor

struct FocusChapterEditorView: View {
    let chapterID: UUID

    @Environment(\.modelContext) private var modelContext
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    @AppStorage("editorFocusPadding") private var focusPadding: Double = 120

    @Query private var chapters: [Chapter]
    private var chapter: Chapter? { chapters.first { $0.id == chapterID } }

    @State private var showControls = false

    var body: some View {
        Group {
            if let chapter {
                editorView(chapter: chapter)
            } else {
                Color("Editor").ignoresSafeArea()
                    .overlay {
                        Text("Глава не найдена")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private func editorView(chapter: Chapter) -> some View {
        ZStack(alignment: .top) {
            Color("Editor").ignoresSafeArea()

            // ── Редактор ──────────────────────────────────────────
            ZStack(alignment: .topLeading) {
                if chapter.text.isEmpty {
                    Text("Начните писать...")
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        .font(.system(size: fontSize, design: .serif))
                        .padding(.top, 16)
                        .padding(.leading, focusPadding + 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: Bindable(chapter).text)
                    .font(.system(size: fontSize, design: .serif))
                    .padding(.horizontal, focusPadding)
                    .scrollContentBackground(.hidden)
                    .padding(.top, showControls ? 44 : 16)
                    .animation(.easeInOut(duration: 0.2), value: showControls)
            }
            .background(Color("Editor"))

            // ── Плавающая панель ──────────────────────────────────
            if showControls {
                focusBar(
                    title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                    wordCount: chapter.text.split { $0.isWhitespace }.count
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Невидимая хот-зона (верхние 44px) ─────────────────
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        withAnimation(.easeOut(duration: 0.15)) { showControls = true }
                    case .ended:
                        break
                    }
                }
                .allowsHitTesting(!showControls)
        }
        // Скрываем когда курсор покидает окно
        .onContinuousHover { phase in
            if case .ended = phase {
                withAnimation(.easeIn(duration: 0.2)) { showControls = false }
            }
        }
        .onChange(of: chapter.text) { _, _ in
            chapter.updatedAt = Date()
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private func focusBar(title: String, wordCount: Int) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("SecondaryText").opacity(0.7))
                .lineLimit(1)
            Spacer()
            Text("\(wordCount) сл.")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Color("SecondaryText").opacity(0.5))
            Button { NSApp.keyWindow?.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color("SecondaryText").opacity(0.1)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Закрыть окно фокуса")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Material.ultraThin)
    }
}

// MARK: - Focus Scene Editor

struct FocusSceneEditorView: View {
    let sceneID: UUID

    @Environment(\.modelContext) private var modelContext
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    @AppStorage("editorFocusPadding") private var focusPadding: Double = 120

    @Query private var scenes: [ScreenScene]
    private var scene: ScreenScene? { scenes.first { $0.id == sceneID } }

    @State private var activeIndex: Int = 0
    @State private var showControls = false

    var body: some View {
        Group {
            if let scene {
                editorView(scene: scene)
            } else {
                Color("Editor").ignoresSafeArea()
                    .overlay {
                        Text("Сцена не найдена")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private func editorView(scene: ScreenScene) -> some View {
        let currentText = Binding<String>(
            get: {
                guard activeIndex < scene.variations.count else { return "" }
                return scene.variations[activeIndex].text
            },
            set: { newValue in
                var vars = scene.variations
                guard activeIndex < vars.count else { return }
                vars[activeIndex].text = newValue
                scene.variations = vars
            }
        )

        // Высота панели: строка + вкладки вариаций
        let barHeight: CGFloat = 60

        ZStack(alignment: .top) {
            Color("Editor").ignoresSafeArea()

            // ── Редактор ──────────────────────────────────────────
            ZStack(alignment: .topLeading) {
                if currentText.wrappedValue.isEmpty {
                    Text("Начните писать...")
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        .font(.system(size: fontSize, design: .serif))
                        .padding(.top, 16)
                        .padding(.leading, focusPadding + 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: currentText)
                    .font(.system(size: fontSize, design: .serif))
                    .padding(.horizontal, focusPadding)
                    .scrollContentBackground(.hidden)
                    .padding(.top, showControls ? barHeight : 16)
                    .animation(.easeInOut(duration: 0.2), value: showControls)
            }
            .background(Color("Editor"))

            // ── Плавающая панель ──────────────────────────────────
            if showControls {
                VStack(spacing: 0) {
                    focusBar(
                        title: scene.title.isEmpty ? "Без названия" : scene.title,
                        wordCount: currentText.wrappedValue.split { $0.isWhitespace }.count
                    )
                    variationTabBar(scene: scene)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 20)
                        .background(Material.ultraThin)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Невидимая хот-зона (верхние 60px) ─────────────────
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        withAnimation(.easeOut(duration: 0.15)) { showControls = true }
                    case .ended:
                        break
                    }
                }
                .allowsHitTesting(!showControls)
        }
        // Скрываем когда курсор покидает окно
        .onContinuousHover { phase in
            if case .ended = phase {
                withAnimation(.easeIn(duration: 0.2)) { showControls = false }
            }
        }
        .onAppear {
            activeIndex = min(scene.activeVariationIndex, max(0, scene.variations.count - 1))
        }
        .onChange(of: currentText.wrappedValue) { _, _ in
            scene.updatedAt = Date()
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private func focusBar(title: String, wordCount: Int) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("SecondaryText").opacity(0.7))
                .lineLimit(1)

            Spacer()

            Text("\(wordCount) сл.")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Color("SecondaryText").opacity(0.5))

            Button {
                NSApp.keyWindow?.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color("SecondaryText").opacity(0.1)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Закрыть окно фокуса")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Material.ultraThin)
    }

    @ViewBuilder
    private func variationTabBar(scene: ScreenScene) -> some View {
        SceneVariationTabBar(
            variations: scene.variations,
            activeIndex: $activeIndex,
            onAdd: {
                var vars = scene.variations
                guard vars.count < 6 else { return }
                vars.append(SceneVariation(title: "Variation \(vars.count + 1)"))
                scene.variations = vars
                activeIndex = vars.count - 1
                try? modelContext.save()
            },
            onDelete: { index in
                var vars = scene.variations
                guard vars.count > 1, index < vars.count else { return }
                vars.remove(at: index)
                for i in vars.indices { vars[i].title = "Variation \(i + 1)" }
                scene.variations = vars
                activeIndex = min(activeIndex, vars.count - 1)
                try? modelContext.save()
            }
        )
    }
}
