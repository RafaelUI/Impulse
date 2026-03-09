import SwiftUI
import SwiftData

// MARK: - Screenplay Workspace

struct ScreenplayWorkspace: View {
    var project: WritingProject
    @State private var selectedModule: ScreenModule? = .screenplay
    @State private var selectedRole: ScreenRole? = nil
    @State private var selectedScene: Scene? = nil
    @State private var selectedTrack: TimelineTrack? = nil

    @Environment(\.dismiss) private var dismiss

    enum ScreenModule: String, CaseIterable, Identifiable {
        case screenplay = "Сценарий"
        case roles      = "Роли"
        case timeline   = "Таймлайн"
        case search     = "Поиск"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .screenplay: return "film"
            case .roles:      return "person.2"
            case .timeline:   return "calendar.day.timeline.left"
            case .search:     return "magnifyingglass"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(ScreenModule.allCases, selection: $selectedModule) { module in
                NavigationLink(value: module) {
                    Label(module.rawValue, systemImage: module.icon)
                        .foregroundStyle(Color("PrimaryText"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("PrimaryAccent"))
            .navigationTitle(project.title)
        } detail: {
            if selectedModule == .timeline {
                TimelineWorkspaceView(project: project, selectedTrack: $selectedTrack)
                    .navigationTitle("")
            } else if selectedModule == .search {
                ProjectSearchView(
                    project: project,
                    scope: .screenplay,
                    onSceneSelect: { scene in
                        selectedScene = scene
                        selectedModule = .screenplay
                    },
                    onScreenRoleSelect: { role in
                        selectedRole = role
                        selectedModule = .roles
                    }
                )
                .navigationTitle("")
            } else {
                HStack(spacing: 0) {
                    // ── Средняя колонка (список) ─────────────────────────
                    listColumn
                        .frame(width: 220)
                        .background(Color("PrimaryAccent"))

                    Rectangle()
                        .fill(Color("Border"))
                        .frame(width: 0.5)

                    // ── Detail ─────────────────────────────────────────
                    detailColumn
                        .frame(maxWidth: .infinity)
                        .background(Color("PrimaryAccent"))
                }
                .navigationTitle("")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbarBackground(Color("PrimaryAccent"), for: .windowToolbar)
        .toolbar {
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
                    if let scene      = result.scene      { selectedScene = scene;    selectedModule = .screenplay }
                    if let screenRole = result.screenRole { selectedRole = screenRole; selectedModule = .roles }
                }
                .frame(width: 260)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onChange(of: selectedModule) { _, newModule in
            if newModule != .roles      { selectedRole = nil }
            if newModule != .screenplay { /* сохраняем selectedScene для навигации */ }
        }
        .background(WindowStyler(token: selectedModule).frame(width: 0, height: 0))
    }

    @ViewBuilder
    private var listColumn: some View {
        switch selectedModule {
        case .none:
            Color("PrimaryAccent")
        case .screenplay:
            SceneListView(project: project, selectedScene: $selectedScene)
        case .roles:
            RoleListView(project: project, selectedRole: $selectedRole)
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
        case .screenplay:
            if let scene = selectedScene {
                SceneEditorView(scene: scene)
            } else {
                placeholderView(icon: "film", text: "Выберите сцену")
            }
        case .roles:
            if let role = selectedRole {
                RoleCardView(role: role) { scene in
                    selectedScene = scene
                    selectedModule = .screenplay
                }
            } else {
                placeholderView(icon: "person", text: "Выберите роль")
            }
        default:
            placeholderView(icon: "film", text: "Выберите сцену")
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
        if selectedModule == .roles, selectedRole != nil {
            selectedRole = nil
            return
        }
        if selectedModule == .screenplay, selectedScene != nil {
            selectedScene = nil
            return
        }

        if selectedModule != .screenplay {
            selectedModule = .screenplay
            return
        }

        dismiss()
    }
}
