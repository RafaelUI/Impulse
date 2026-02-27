import SwiftUI
import SwiftData

struct CharacterListView: View {
    var project: WritingProject
    @Binding var selectedCharacter: Character?
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingCharacter = false
    @State private var newCharacterName = ""

    var body: some View {
        List(project.characters, id: \.id, selection: $selectedCharacter) { character in
            CharacterRowView(character: character)
                .tag(character)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAddingCharacter = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Новый персонаж", isPresented: $isAddingCharacter) {
            TextField("Имя персонажа", text: $newCharacterName)
            Button("Создать") { addCharacter() }
            Button("Отмена", role: .cancel) { newCharacterName = "" }
        }
        .overlay {
            if project.characters.isEmpty {
                ContentUnavailableView(
                    "Персонажей пока нет",
                    systemImage: "person.2.slash",
                    description: Text("Нажмите «+» чтобы добавить первого")
                )
            }
        }
    }

    private func addCharacter() {
        let name = newCharacterName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let char = Character(name: name)
        char.project = project
        project.characters.append(char)
        try? modelContext.save()
        selectedCharacter = char
        newCharacterName = ""
    }
}

// MARK: - Character Row

struct CharacterRowView: View {
    var character: Character

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("AccentColor").opacity(0.15))
                    .frame(width: 36, height: 36)

                if let data = character.photoData, let img = PlatformImage(data: data) {
                    Image(platformImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(character.name.prefix(1))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color("AccentColor"))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.body)
                if !character.role.isEmpty {
                    Text(character.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Character Card

struct CharacterCardView: View {
    @Bindable var character: Character
    var onChapterTap: (Chapter) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteAlert = false
    @State private var isPickingPhoto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Шапка ──────────────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [Color("AccentColor").opacity(0.25), Color("PrimaryAccent")],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .frame(height: 190)

                    HStack(alignment: .bottom, spacing: 16) {
                        Button { isPickingPhoto = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color("AccentColor").opacity(0.2))
                                    .frame(width: 140, height: 140)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color("AccentColor").opacity(0.35), lineWidth: 1.5)
                                    )

                                if let data = character.photoData, let img = PlatformImage(data: data) {
                                    Image(platformImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 140, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(Color("AccentColor").opacity(0.7))
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Имя персонажа", text: $character.name)
                                .font(.system(.title2, design: .serif, weight: .semibold))
                                .textFieldStyle(.plain)

                            TextField("Роль (главный герой, злодей...)", text: $character.role)
                                .font(.subheadline)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 34)
                }

                // ── Секции ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 24) {

                    CardSection(icon: "calendar", title: "Возраст") {
                        AgeField(age: $character.age)
                    }

                    Divider()

                    CardSection(icon: "eye", title: "Внешность") {
                        GrowingTextEditor(text: $character.appearance,
                                          placeholder: "Опишите внешность персонажа...")
                    }

                    Divider()

                    CardSection(icon: "book.closed", title: "Биография") {
                        GrowingTextEditor(text: $character.biography,
                                          placeholder: "История жизни, ключевые события...")
                    }

                    Divider()

                    CardSection(icon: "bolt", title: "Способности") {
                        GrowingTextEditor(text: $character.abilities,
                                          placeholder: "Магия, навыки, таланты...")
                    }

                    Divider()

                    CardSection(icon: "mappin.and.ellipse", title: "Локации") {
                        GrowingTextEditor(text: $character.locations,
                                          placeholder: "Места где обитает или бывал персонаж...")
                    }

                    Divider()

                    CardSection(icon: "theatermasks", title: "Роль в сюжете") {
                        GrowingTextEditor(text: $character.plotRole,
                                          placeholder: "Какую функцию выполняет в истории...")
                    }

                    Divider()

                    ChapterAppearancesSection(character: character, onChapterTap: onChapterTap)
                }
                .padding(24)
            }
        }
        .background(Color("PrimaryAccent"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        // TODO: экспорт
                    } label: {
                        Label("Экспортировать", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isPickingPhoto = true
                    } label: {
                        Label("Изменить фото", systemImage: "photo")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить персонажа", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .alert("Удалить персонажа?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) { deleteCharacter() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private func deleteCharacter() {
        modelContext.delete(character)
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct CardSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            content()
        }
    }
}

struct AgeField: View {
    @Binding var age: Int?
    @State private var text: String = ""

    var body: some View {
        TextField("Не указан", text: $text)
            .textFieldStyle(.plain)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onAppear { text = age.map { String($0) } ?? "" }
            .onChange(of: text) { _, new in age = Int(new) }
    }
}

struct GrowingTextEditor: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
            TextEditor(text: $text)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
        }
        .font(.system(.body, design: .serif))
    }
}
