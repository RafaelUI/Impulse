import SwiftUI
import SwiftData
import Foundation
import AuthenticationServices
import AppKit

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WritingProject.createdAt, order: .reverse) private var projects: [WritingProject]

    @StateObject private var signInManager = AppleSignInManager.shared
    @State private var isShowingCreateSheet = false
    @State private var selectedProject: WritingProject? = nil
    @State private var isShowingSettings = false
    @State private var showSignOutAlert = false
    @State private var showAboutPopover = false
    @AppStorage("appTheme") private var appTheme: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("PrimaryAccent")
                    .ignoresSafeArea()

                VStack(spacing: 60) {
                    Spacer()

                    Text("Impulse")
                        .font(.system(size: 240, weight: .thin, design: .serif))
                        .foregroundStyle(Color("AccentColor"))

                    VStack(spacing: 30) {
                        // Кнопка создания
                        Button(action: { isShowingCreateSheet = true }) {
                            Label(title: { Text("Создать проект") }, icon: { Image(systemName: "plus.circle.fill") })
                                .frame(width: 260)
                                .padding()
                                .overlay(Capsule().stroke(Color("AccentColor"), lineWidth: 5))
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
                            Label(title: { Text("Мои проекты") }, icon: { Image(systemName: "chevron.down") })
                                .frame(width: 260)
                                .padding()
                                .overlay(Capsule().stroke(Color("AccentColor"), lineWidth: 5))
                                .foregroundStyle(Color("AccentColor"))
                        }
                    }

                    Spacer()

                    HStack {
                        // Профиль пользователя (слева)
                        if signInManager.isSignedIn, let user = signInManager.signedInUser {
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color("AccentColor"))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(user.fullName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color("PrimaryText"))
                                    Text("iCloud")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color("SecondaryText"))
                                }
                                Button {
                                    showSignOutAlert = true
                                } label: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color("SecondaryText"))
                                }
                                .buttonStyle(.plain)
                                .help("Выйти из аккаунта")
                                .alert("account.alert.title", isPresented: $showSignOutAlert) {
                                    Button("account.alert.signout") {
                                        signInManager.signOut()
                                    }
                                    Button("account.alert.delete", role: .destructive) {
                                        Task { await signInManager.deleteAccount() }
                                    }
                                    Button("account.alert.cancel", role: .cancel) {}
                                } message: {
                                    Text("account.alert.message")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        } else {
                            Button {
                                if let window = NSApp.keyWindow {
                                    signInManager.signIn(presentingWindow: window)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Войти через Apple")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color("AccentColor"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .overlay(Capsule().stroke(Color("AccentColor"), lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                        }

                        Spacer()

                        Button {
                            showAboutPopover = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(Color("AccentColor"))
                                .font(.system(size: 40))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showAboutPopover, arrowEdge: .top) {
                            AboutPopoverView()
                        }

                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(Color("AccentColor"))
                                .font(.system(size: 40))
                        }
                        .buttonStyle(.plain)
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .frame(minWidth: 540, minHeight: 480)
        }
        .preferredColorScheme(preferredColorScheme)
        .background(WindowStyler().frame(width: 0, height: 0))

    }
}

// MARK: - About Popover

private struct AboutPopoverView: View {
    private let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок
            HStack(spacing: 10) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Impulse")
                        .font(.system(.body, design: .serif, weight: .semibold))
                        .foregroundStyle(Color("PrimaryText"))
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Ссылки
            VStack(spacing: 0) {
                AboutLinkRow(icon: "globe", label: "Website", url: "https://impulsewriting.app")
                Divider().padding(.leading, 36)
                AboutLinkRow(icon: "lock.shield", label: "Privacy Policy", url: "https://impulsewriting.app/privacy")
                Divider().padding(.leading, 36)
                AboutLinkRow(icon: "doc.text", label: "Terms of Service", url: "https://impulsewriting.app/terms")
                Divider().padding(.leading, 36)
                AboutLinkRow(icon: "envelope", label: "Support", url: "mailto:support@impulsewriting.app")
                Divider().padding(.leading, 36)
                AboutLinkRow(icon: "book.pages", label: "Help", url: "https://impulsewriting.app/help")
            }
            .padding(.vertical, 4)
        }
        .frame(width: 240)
        .background(Color("PrimaryAccent"))
    }
}

private struct AboutLinkRow: View {
    let icon: String
    let label: String
    let url: String

    var body: some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AccentColor").opacity(0.8))
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color("PrimaryText"))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color("SecondaryText").opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                                            Text(LocalizedStringKey(type.rawValue))
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
            // Ошибка сохранения — контекст откатится автоматически
        }
    }
}
