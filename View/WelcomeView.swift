import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WritingProject.createdAt, order: .reverse) private var projects: [WritingProject]

    @State private var isShowingCreateSheet = false
    @State private var selectedProject: WritingProject? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color("PrimaryAccent")
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    Text("Impulse")
                        .font(.system(size: 60, weight: .thin, design: .serif))
                        .foregroundStyle(Color("AccentColor"))

                    VStack(spacing: 15) {
                        // Кнопка создания
                        Button(action: { isShowingCreateSheet = true }) {
                            Label("Создать проект", systemImage: "plus.circle.fill")
                                .frame(width: 220)
                                .padding()
                                .background(Color("AccentColor"))
                                .foregroundStyle(Color("PrimaryAccent"))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Выпадающее меню проектов
                        Menu {
                            if projects.isEmpty {
                                Text("Проектов пока нет").disabled(true)
                            } else {
                                ForEach(projects) { project in
                                    Button(project.title) {
                                        selectedProject = project
                                    }
                                }
                            }
                        } label: {
                            Label("Мои проекты", systemImage: "chevron.down")
                                .frame(width: 220)
                                .padding()
                                .overlay(Capsule().stroke(Color("AccentColor"), lineWidth: 1))
                                .foregroundStyle(Color("AccentColor"))
                        }
                    }

                    Spacer()

                    HStack {
                        Spacer()
                        HStack(spacing: 20) {
                            Image(systemName: "apple.logo")
                            Image(systemName: "g.circle.fill")
                        }
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding()
                    }
                }
            }
            // Навигация к проекту
            .navigationDestination(item: $selectedProject) { project in
                MainWorkspaceView(project: project)
            }
        }
        // ✅ Убрали .modelContainer из sheet — он уже есть в environment
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateProjectSheet()
        }
    }
}

// MARK: - Создание проекта

struct CreateProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var projectTitle = ""
    @State private var selectedType: ProjectType = .book

    let types = ProjectType.allCases

    var body: some View {
        NavigationStack {
            Form {
                Section("Основная информация") {
                    TextField("Название проекта", text: $projectTitle)
                        .foregroundStyle(Color("AccentColor"))
                }

                Section("Тип проекта") {
                    Picker("Тип", selection: $selectedType) {
                        ForEach(types, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)  // ✅ .navigationLink — iOS only, .inline работает везде
                }

                Section {
                    Button(action: createProject) {
                        Text("Начать работу")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
                    .disabled(projectTitle.isEmpty)
                }
            }
            .navigationTitle("Новый проект")
            // ✅ Убрали .navigationBarTitleDisplayMode — iOS only
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    private func createProject() {
        let newProject = WritingProject(title: projectTitle, type: selectedType)
        modelContext.insert(newProject)
        do {
            try modelContext.save()
            print("✅ Проект создан: \(projectTitle)")
            dismiss()
        } catch {
            print("❌ Ошибка: \(error.localizedDescription)")
        }
    }
}
