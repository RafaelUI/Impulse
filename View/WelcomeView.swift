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
                                .overlay(Capsule().stroke(Color("AccentColor"), lineWidth: 1))
                                .foregroundStyle(Color("AccentColor"))
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
                        .foregroundStyle(Color("SecondaryText"))
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
        .background(WindowStyler().frame(width: 0, height: 0))
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
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Заголовок ──
                HStack {
                    Text("Новый проект")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Color("PrimaryText"))
                    Spacer()
                    Button("Отмена") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()
                    .background(Color("Border"))

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Название ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text("НАЗВАНИЕ")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color("SecondaryText"))
                                .tracking(0.8)

                            TextField("Название проекта", text: $projectTitle)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .foregroundStyle(Color("PrimaryText"))
                                .padding(10)
                                .background(Color("AccentColor").opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        }

                        // ── Тип проекта ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ТИП ПРОЕКТА")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color("SecondaryText"))
                                .tracking(0.8)

                            VStack(spacing: 6) {
                                ForEach(types, id: \.self) { type in
                                    Button {
                                        selectedType = type
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: type.icon)
                                                .foregroundStyle(selectedType == type ? Color("AccentColor") : Color("SecondaryText"))
                                                .frame(width: 20)
                                            Text(type.rawValue)
                                                .foregroundStyle(selectedType == type ? Color("PrimaryText") : Color("SecondaryText"))
                                            Spacer()
                                            if selectedType == type {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(Color("AccentColor"))
                                                    .font(.caption.weight(.semibold))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(
                                            selectedType == type
                                                ? Color("AccentColor").opacity(0.12)
                                                : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(24)
                }

                Divider()
                    .background(Color("Border"))

                // ── Кнопка создать ──
                Button(action: createProject) {
                    Text("Начать работу")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(projectTitle.isEmpty ? Color("AccentColor").opacity(0.3) : Color("AccentColor"), lineWidth: 1))
                        .foregroundStyle(projectTitle.isEmpty ? Color("AccentColor").opacity(0.4) : Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(projectTitle.isEmpty)
                .padding(24)
            }
        }
        .frame(minWidth: 380, minHeight: 420)
    }

    private func createProject() {
        let newProject = WritingProject(title: projectTitle, type: selectedType)
        modelContext.insert(newProject)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Ошибка: \(error.localizedDescription)")
        }
    }
}
