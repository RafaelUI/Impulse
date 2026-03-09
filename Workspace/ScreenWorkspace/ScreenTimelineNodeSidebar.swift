import SwiftUI

// MARK: - Screen Timeline Node Sidebar
// Аналог TimelineNodeSidebarView для сценарного таймлайна:
// — роли вместо персонажей
// — локаций нет

struct ScreenTimelineNodeSidebarView: View {
    let track: TimelineTrack
    let nodeID: UUID
    let project: WritingProject
    var onSave: () -> Void
    var onClose: () -> Void

    // MARK: Binding на узел

    private var nodeIndex: Int? {
        track.nodes.firstIndex(where: { $0.id == nodeID })
    }

    private var node: TimelineNode? {
        guard let i = nodeIndex else { return nil }
        return track.nodes[i]
    }

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

    @State private var showRolePicker = false

    var body: some View {
        guard let node = node,
              let titleBinding = nodeBinding(\.title),
              let noteBinding  = nodeBinding(\.note)
        else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 4) {
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

                        // MARK: Роли
                        sectionLabel("Роли")
                        rolesSection(node: node)
                    }
                    .padding(16)
                }
            }
            .background(Color("PrimaryAccent"))
        )
    }

    // MARK: - Roles Section

    @ViewBuilder
    private func rolesSection(node: TimelineNode) -> some View {
        let linked    = project.screenRoles.filter { node.roleIDs.contains($0.id) }
        let available = project.screenRoles.filter { !node.roleIDs.contains($0.id) }

        VStack(alignment: .leading, spacing: 6) {
            if linked.isEmpty {
                Text("Нет ролей")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.5))
            } else {
                ForEach(linked, id: \.id) { role in
                    linkedRow(
                        title: role.name,
                        subtitle: role.role.isEmpty ? nil : role.role,
                        icon: "person.fill"
                    ) {
                        removeRole(role.id)
                    }
                }
            }

            Button {
                showRolePicker = true
            } label: {
                Label("Добавить роль", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
            .disabled(available.isEmpty)
            .popover(isPresented: $showRolePicker, arrowEdge: .bottom) {
                pickerList(items: available, title: "Выберите роль") { r in
                    addRole(r.id)
                    showRolePicker = false
                } label: { r in
                    (primary: r.name, secondary: r.role.isEmpty ? nil : r.role)
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
        label: @escaping (T) -> (primary: String, secondary: String?)
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

    private func addRole(_ id: UUID) {
        mutateNode { node in
            if !node.roleIDs.contains(id) { node.roleIDs.append(id) }
        }
    }

    private func removeRole(_ id: UUID) {
        mutateNode { node in node.roleIDs.removeAll { $0 == id } }
    }
}
