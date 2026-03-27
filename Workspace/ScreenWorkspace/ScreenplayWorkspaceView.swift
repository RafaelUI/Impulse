import SwiftUI
import SwiftData

// MARK: - Screenplay Workspace

struct ScreenplayWorkspace: View {
    var project: WritingProject
    @State private var selectedModule: ScreenModule? = .screenplay
    @State private var selectedRole: ScreenRole? = nil
    @State private var selectedScene: ScreenScene? = nil
    @State private var selectedTrack: TimelineTrack? = nil

    @State private var showSceneInfo = false
    @State private var showFilterPopover = false
    @AppStorage("showSceneLabels") private var showLabels: Bool = false
    @Environment(\.dismiss) private var dismiss

    enum ScreenModule: String, CaseIterable, Identifiable {
        case screenplay  = "Сценарий"
        case roles       = "Роли"
        case timeline    = "Таймлайн"
        case comparison  = "Сравнение"
        case search      = "Поиск"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .screenplay:  return "film"
            case .roles:       return "person.2"
            case .timeline:    return "calendar.day.timeline.left"
            case .comparison:  return "rectangle.split.2x1"
            case .search:      return "magnifyingglass"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(ScreenModule.allCases, selection: $selectedModule) { module in
                NavigationLink(value: module) {
                    Label(title: { Text(LocalizedStringKey(module.rawValue)) }, icon: { Image(systemName: module.icon) })
                        .foregroundStyle(Color("PrimaryText"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("PrimaryAccent"))
            .navigationTitle(project.title)
        } detail: {
            if selectedModule == .comparison {
                SceneComparisonView(project: project)
                    .navigationTitle("")
            } else if selectedModule == .timeline {
                TimelineWorkspaceView(
                    project: project,
                    selectedTrack: $selectedTrack,
                    columns: (project.scenes ?? [])
                        .sorted { $0.orderIndex < $1.orderIndex }
                        .map { TimelineColumnItem(id: $0.id, title: $0.title) },
                    sidebarView: { track, nodeID, save, close in
                        AnyView(
                            ScreenTimelineNodeSidebarView(
                                track: track,
                                nodeID: nodeID,
                                project: project,
                                onSave: save,
                                onClose: close
                            )
                        )
                    }
                )
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
                    Image(systemName: "chevron.backward.circle")
                        .foregroundStyle(Color("AccentColor"))
                        .font(.system(size: 20))
                }
                .buttonStyle(AccentToolbarButtonStyle())
            }

            ToolbarItem(placement: .navigation) {
                Button {
                    showLabels.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: 20, height: 20)
                        Circle()
                            .strokeBorder(showLabels ? Color("AccentColor") : Color("SecondaryText").opacity(0.4), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                        if showLabels {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color("AccentColor"))
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .opacity(selectedModule == .screenplay ? 1 : 0)
                .disabled(selectedModule != .screenplay)
            }

            ToolbarItem(placement: .navigation) {
                Button {
                    showFilterPopover = true
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ChapterListFilter.isActive ? Color("AccentColor") : Color("SecondaryText").opacity(0.6))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                    ChapterFilterPopover()
                }
                .opacity(selectedModule == .screenplay ? 1 : 0)
                .disabled(selectedModule != .screenplay)
            }

            ToolbarItem(placement: .automatic) {
                WorkspaceSearchBar(project: project, allowedTypes: [.scene, .screenRole]) { result in
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
        .sheet(isPresented: $showSceneInfo) {
            if let scene = selectedScene {
                SceneInfoView(scene: scene, project: project)
                    .frame(minWidth: 640, idealWidth: 720, minHeight: 460)
            }
        }
        .background {
            if selectedScene != nil && selectedModule == .screenplay {
                Button("") { showSceneInfo = true }
                    .keyboardShortcut("i", modifiers: .command)
                    .hidden()
            }
        }
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
                RoleCardView(
                    role: role,
                    onSceneTap: { scene in
                        selectedScene = scene
                        selectedModule = .screenplay
                    }
                )
            } else {
                placeholderView(icon: "person", text: "Выберите роль")
            }
        default:
            placeholderView(icon: "film", text: "Выберите сцену")
        }
    }

    @ViewBuilder
    private func placeholderView(icon: String, text: LocalizedStringKey) -> some View {
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
