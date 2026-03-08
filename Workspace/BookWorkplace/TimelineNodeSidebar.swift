import SwiftUI

// MARK: - Timeline Node Sidebar

struct TimelineNodeSidebarView: View {
    /// Трек содержащий редактируемый узел
    let track: TimelineTrack
    /// ID выбранного узла
    let nodeID: UUID
    /// Проект — для получения персонажей и локаций
    let project: WritingProject
    var onSave: () -> Void
    var onClose: () -> Void

    // MARK: Binding на узел через вычисляемые свойства
    private var nodeIndex: Int? {
        track.nodes.firstIndex(where: { $0.id == nodeID })
    }

    private var node: TimelineNode? {
        guard let i = nodeIndex else { return nil }
        return track.nodes[i]
    }

    // Вспомогательный Binding для мутации
    private func nodeBinding<V>(_ keyPath: WritableKeyPath<TimelineNode, V>) -> Binding<V>? {
        guard let i = nodeIndex else { return nil }
        return Binding(
            get: { self.track.nodes[i][keyPath: keyPath] },
            set: { newVal in
                var nodes = self.track.nodes
                nodes[i][keyPath: keyPath] = newVal
                self.track.nodes = nodes
                self.onSave()
            }
        )
    }

    // MARK: Picker state
    @State private var showCharacterPicker = false
    @State private var showLocationPicker  = false

    var body: some View {
        guard let node = node,
              let titleBinding = nodeBinding(\.title),
              let noteBinding  = nodeBinding(\.note)
        else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {
                // Заголовок панели
                HStack {
                    Label(
                        node.eventType == .range ? "Событие (диапазон)" : "Событие (момент)",
                        systemImage: node.eventType == .range
                            ? "arrow.left.and.right"
                            : "smallcircle.filled.circle"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("PrimaryText").opacity(0.6))
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color("SecondaryText"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Rectangle().fill(Color("Border")).frame(height: 0.5)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // MARK: Название
                        sectionLabel("Название")
                        TextField("Название события", text: titleBinding)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .glassEffect(in: .rect(cornerRadius: 8))

                        // MARK: Описание
                        sectionLabel("Описание")
                        ZStack(alignment: .topLeading) {
                            if noteBinding.wrappedValue.isEmpty {
                                Text("Заметки об этом событии...")
                                    .font(.body)
                                    .foregroundStyle(Color("SecondaryText").opacity(0.4))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: noteBinding)
                                .font(.body)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                        .glassEffect(in: .rect(cornerRadius: 8))

                        // MARK: Персонажи
                        sectionLabel("Персонажи")
                        charactersSection(node: node)

                        // MARK: Локации
                        sectionLabel("Локации")
                        locationsSection(node: node)
                    }
                    .padding(16)
                }
            }
            .background(Color("PrimaryAccent"))
        )
    }

    // MARK: - Sections

    @ViewBuilder
    private func charactersSection(node: TimelineNode) -> some View {
        let linked = project.characters.filter { node.characterIDs.contains($0.id) }
        let available = project.characters.filter { !node.characterIDs.contains($0.id) }

        VStack(alignment: .leading, spacing: 6) {
            if linked.isEmpty {
                Text("Нет персонажей")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.5))
            } else {
                ForEach(linked, id: \.id) { character in
                    linkedRow(
                        title: character.name,
                        subtitle: character.role.isEmpty ? nil : character.role,
                        icon: "person.fill"
                    ) {
                        removeCharacter(character.id)
                    }
                }
            }

            Button {
                showCharacterPicker = true
            } label: {
                Label("Добавить персонажа", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
            .disabled(available.isEmpty)
            .popover(isPresented: $showCharacterPicker, arrowEdge: .bottom) {
                pickerList(items: available, title: "Выберите персонажа") { c in
                    addCharacter(c.id)
                    showCharacterPicker = false
                } label: { c in
                    (primary: c.name, secondary: c.role.isEmpty ? nil : c.role)
                }
            }
        }
    }

    @ViewBuilder
    private func locationsSection(node: TimelineNode) -> some View {
        let allLocations = project.worldBuilding?.locations ?? []
        let linked    = allLocations.filter { node.locationIDs.contains($0.id) }
        let available = allLocations.filter { !node.locationIDs.contains($0.id) }

        VStack(alignment: .leading, spacing: 6) {
            if linked.isEmpty {
                Text("Нет локаций")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.5))
            } else {
                ForEach(linked, id: \.id) { loc in
                    linkedRow(
                        title: loc.name,
                        subtitle: loc.type.isEmpty ? nil : loc.type,
                        icon: "mappin.fill"
                    ) {
                        removeLocation(loc.id)
                    }
                }
            }

            Button {
                showLocationPicker = true
            } label: {
                Label("Добавить локацию", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
            .disabled(available.isEmpty)
            .popover(isPresented: $showLocationPicker, arrowEdge: .bottom) {
                pickerList(items: available, title: "Выберите локацию") { loc in
                    addLocation(loc.id)
                    showLocationPicker = false
                } label: { loc in
                    (primary: loc.name, secondary: loc.type.isEmpty ? nil : loc.type)
                }
            }
        }
    }

    // MARK: - Reusable UI

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color("PrimaryText").opacity(0.4))
            .textCase(.uppercase)
            .tracking(0.6)
    }

    @ViewBuilder
    private func linkedRow(title: String, subtitle: String?, icon: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color("AccentColor").opacity(0.8))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color("PrimaryText"))
                if let sub = subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText"))
                }
            }
            Spacer()
            Button { onRemove() } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(Color("SecondaryText").opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color("AccentColor").opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func pickerList<T: Identifiable>(
        items: [T],
        title: String,
        onSelect: @escaping (T) -> Void,
        label: (T) -> (primary: String, secondary: String?)
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        let l = label(item)
                        Button { onSelect(item) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.primary)
                                        .font(.body)
                                        .foregroundStyle(Color("PrimaryText"))
                                    if let sec = l.secondary, !sec.isEmpty {
                                        Text(sec)
                                            .font(.caption)
                                            .foregroundStyle(Color("SecondaryText"))
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(Color("AccentColor"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .frame(minWidth: 240)
    }

    // MARK: - Mutations

    private func mutateNode(_ mutation: (inout TimelineNode) -> Void) {
        guard let i = nodeIndex else { return }
        var nodes = track.nodes
        mutation(&nodes[i])
        track.nodes = nodes
        onSave()
    }

    private func addCharacter(_ id: UUID) {
        mutateNode { node in
            if !node.characterIDs.contains(id) { node.characterIDs.append(id) }
        }
    }

    private func removeCharacter(_ id: UUID) {
        mutateNode { node in node.characterIDs.removeAll { $0 == id } }
    }

    private func addLocation(_ id: UUID) {
        mutateNode { node in
            if !node.locationIDs.contains(id) { node.locationIDs.append(id) }
        }
    }

    private func removeLocation(_ id: UUID) {
        mutateNode { node in node.locationIDs.removeAll { $0 == id } }
    }
}
