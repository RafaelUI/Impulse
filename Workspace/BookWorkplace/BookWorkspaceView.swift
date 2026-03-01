import SwiftUI
import SwiftData

// MARK: - Book Workspace

struct BookWorkspace: View {
    var project: WritingProject
    @State private var selectedModule: BookModule? = .manuscript
    @State private var selectedCharacter: Character? = nil
    @State private var selectedChapter: Chapter? = nil

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
            
            List(BookModule.allCases, selection: $selectedModule) { module in
                NavigationLink(value: module) {
                    Label(module.rawValue, systemImage: module.icon)
                }
            }
            .navigationTitle(project.title)
        }
        content: {
            Group {
                switch selectedModule {
                case .none:
                    EmptyView()
                case .characters:
                    CharacterListView(project: project, selectedCharacter: $selectedCharacter)
                case .manuscript:
                    ChapterListView(project: project, selectedChapter: $selectedChapter)
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
                    ContentUnavailableView("В разработке", systemImage: "hammer")
                }
            }
            .navigationTitle(selectedModule?.rawValue ?? "")

        } detail: {
            if selectedModule == .characters, let character = selectedCharacter {
                CharacterCardView(character: character) { chapter in
                    selectedChapter = chapter
                    selectedModule = .manuscript
                }
            } else if selectedModule == .manuscript, let chapter = selectedChapter {
                ChapterEditorView(chapter: chapter)
            } else {
                TextEditorView()
            }
        }
        .toolbar {
               ToolbarItem(placement: .automatic) {
                   WorkspaceSearchBar(project: project) { result in
                       if let chapter   = result.chapter   { selectedChapter = chapter;    selectedModule = .manuscript }
                       if let character = result.character { selectedCharacter = character; selectedModule = .characters }
                   }
                   .frame(width: 400)
               }
           }
        .onChange(of: selectedModule) { _, newModule in
            if newModule != .characters { selectedCharacter = nil }
            if newModule != .manuscript { /* сохраняем selectedChapter для навигации из поиска */ }
        }
    }
}

// MARK: - Text Editor View

struct TextEditorView: View {
    @State private var text: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Начните писать свою историю здесь...")
                    .foregroundStyle(.tertiary)
                    .font(.system(.body, design: .serif))
                    .padding(.top, 20)
                    .padding(.leading, 36)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .serif))
                .padding(.horizontal, 30)
                .scrollContentBackground(.hidden)
        }
        .background(Color("PrimaryAccent"))
    }
}

typealias PlatformImage = NSImage
extension Image {
    init(platformImage: NSImage) { self.init(nsImage: platformImage) }
}

