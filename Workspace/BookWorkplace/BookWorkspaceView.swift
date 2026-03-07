import SwiftUI
import SwiftData

// MARK: - Book Workspace

struct BookWorkspace: View {
    var project: WritingProject
    @State private var selectedModule: BookModule? = .manuscript
    @State private var selectedCharacter: Character? = nil
    @State private var selectedChapter: Chapter? = nil
    @State private var selectedLocation: WorldLocation? = nil
    @State private var locationTabs: [UUID: WorldLocationTab] = [:]

    @Environment(\.dismiss) private var dismiss

    enum BookModule: String, CaseIterable, Identifiable {
        case manuscript    = "Рукопись"
        case characters    = "Персонажи"
        case worldBuilding = "Мироустройство"
        case timeline      = "Таймлайн"
        case search        = "Поиск"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .manuscript:    return "doc.text"
            case .characters:    return "person.2"
            case .worldBuilding: return "globe.europe.africa"
            case .timeline:      return "calendar.day.timeline.left"
            case .search:        return "magnifyingglass"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(BookModule.allCases.filter { $0 != .search }, selection: $selectedModule) { module in
                NavigationLink(value: module) {
                    Label(module.rawValue, systemImage: module.icon)
                        .foregroundStyle(Color("PrimaryText"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("PrimaryAccent"))
            .navigationTitle(project.title)
        } detail: {
            HStack(spacing: 0) {
                // ── Средняя колонка (список) ─────────────────────────
                listColumn
                    .frame(width: 220)
                    .background(Color("PrimaryAccent"))

                // ── Разделитель ──────────────────────────────────────
                Rectangle()
                    .fill(Color("Border"))
                    .frame(width: 0.5)

                // ── Detail (редактор / карточка) ─────────────────────
                detailColumn
                    .frame(maxWidth: .infinity)
                    .background(Color("PrimaryAccent"))
            }
            .navigationTitle("")
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbarBackground(Color("PrimaryAccent"), for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                   if selectedModule == .worldBuilding, let location = selectedLocation {
                       ScrollView(.horizontal, showsIndicators: false) {
                           HStack(spacing: 2) {
                               ForEach(WorldLocationTab.allCases) { tab in
                                   let isActive = (locationTabs[location.id] ?? .info) == tab
                                   Text(tab.rawValue)
                                       .font(.body)
                                       .foregroundStyle(isActive ? Color("AccentColor") : Color("PrimaryText"))
                                       .padding(.horizontal, 15)
                                       .padding(.vertical, 4)
                                       .background(
                                           RoundedRectangle(cornerRadius: 12)
                                               .fill(isActive ? Color("AccentColor").opacity(0.15) : Color.clear)
                                       )
                                       .clipShape(RoundedRectangle(cornerRadius: 12))
                                       .contentShape(RoundedRectangle(cornerRadius: 12))
                                       .onTapGesture {
                                           locationTabs[location.id] = tab
                                       }
                               }
                           }
                           .padding(.horizontal, 10)
                       }
                       .frame(maxWidth: .infinity)
                   }
               }
               ToolbarItem(placement: .navigation) {
                   Button {
                       handleBack()
                   } label: {
                       Image(systemName: "chevron.left")
                           .foregroundStyle(Color("PrimaryText"))
                   }
                   .buttonStyle(AccentToolbarButtonStyle())
               }

               ToolbarItem(placement: .automatic) {
                   WorkspaceSearchBar(project: project) { result in
                       if let chapter   = result.chapter   { selectedChapter = chapter;    selectedModule = .manuscript }
                       if let character = result.character { selectedCharacter = character; selectedModule = .characters }
                   }
                   .frame(width: 260)
               }
               .sharedBackgroundVisibility(.hidden)
           }
        .onChange(of: selectedModule) { _, newModule in
            if newModule != .characters { selectedCharacter = nil }
            if newModule != .manuscript { /* сохраняем selectedChapter для навигации из поиска */ }
            if newModule != .worldBuilding { selectedLocation = nil }
        }
        .background(WindowStyler(token: selectedModule).frame(width: 0, height: 0))
    }

    @ViewBuilder
    private var listColumn: some View {
        switch selectedModule {
        case .none:
            Color("PrimaryAccent")
        case .characters:
            CharacterListView(project: project, selectedCharacter: $selectedCharacter)
        case .manuscript:
            ChapterListView(project: project, selectedChapter: $selectedChapter)
        case .worldBuilding:
            WorldBuildingLocationListView(project: project, selectedLocation: $selectedLocation)
        case .search:
            SearchView(
                project: project,
                onChapterSelect: { chapter in
                    selectedChapter = chapter
                    selectedModule = .manuscript
                },
                onCharacterSelect: { character in
                    selectedCharacter = character
                    selectedModule = .characters
                }
            )
        default:
            ZStack {
                Color("PrimaryAccent").ignoresSafeArea()
                VStack(spacing: 8) {
                    Image(systemName: "hammer")
                        .font(.system(size: 36))
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                    Text("В разработке")
                        .foregroundStyle(Color("SecondaryText"))
                }
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selectedModule {
        case .characters:
            if let character = selectedCharacter {
                CharacterCardView(character: character) { chapter in
                    selectedChapter = chapter
                    selectedModule = .manuscript
                }
            } else {
                placeholderView(icon: "person", text: "Выберите персонажа")
            }
        case .manuscript:
            if let chapter = selectedChapter {
                ChapterEditorView(chapter: chapter)
            } else {
                placeholderView(icon: "doc.text", text: "Выберите главу")
            }
        case .worldBuilding:
            if let location = selectedLocation {
                WorldBuildingLocationDetailView(
                    location: location,
                    selectedTab: Binding(
                        get: { locationTabs[location.id] ?? .info },
                        set: { locationTabs[location.id] = $0 }
                    )
                )
            } else {
                placeholderView(icon: "mappin.and.ellipse", text: "Выберите локацию")
            }
        default:
            placeholderView(icon: "doc.text", text: "Выберите главу")
        }
    }

    @ViewBuilder
    private func placeholderView(icon: String, text: String) -> some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(Color("SecondaryText").opacity(0.4))
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color("SecondaryText"))
            }
        }
    }

    private func handleBack() {
        if selectedModule == .characters, selectedCharacter != nil {
            selectedCharacter = nil
            return
        }
        if selectedModule == .manuscript, selectedChapter != nil {
            selectedChapter = nil
            return
        }
        if selectedModule == .worldBuilding, selectedLocation != nil {
            selectedLocation = nil
            return
        }

        if selectedModule != .manuscript {
            selectedModule = .manuscript
            return
        }

        dismiss()
    }
}

// MARK: - Text Editor View

struct TextEditorView: View {
    @State private var text: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Начните писать свою историю здесь...")
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    .font(.system(.body, design: .serif))
                    .padding(.top, 20)
                    .padding(.leading, 36)
                    .allowsHitTesting(false)
                    .background(Color("PrimaryAccent"))
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .serif))
                .padding(.horizontal, 30)
                .scrollContentBackground(.hidden)
                .background(Color("PrimaryAccent"))
        }
        .background(Color("PrimaryAccent"))
    }
}

typealias PlatformImage = NSImage
extension Image {
    init(platformImage: NSImage) { self.init(nsImage: platformImage) }
}

// MARK: - Toolbar Button Style

struct AccentToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color("AccentColor").opacity(0.2) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

