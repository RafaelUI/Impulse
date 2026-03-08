import SwiftUI
import SwiftData

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Заголовок ────────────────────────────────────────
                HStack {
                    Text("Настройки")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Color("PrimaryText"))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("SecondaryText"))
                            .padding(6)
                            .background(Circle().fill(Color("SecondaryText").opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 24)

                Divider().padding(.horizontal, 28)

                // ── Секции настроек (будущие) ─────────────────────────
                // Здесь можно добавлять новые секции настроек выше корзины

                Spacer().frame(height: 24)

                Divider().padding(.horizontal, 28)

                // ── Корзина — всегда внизу ───────────────────────────
                TrashSectionView()
                    .padding(.top, 8)
            }
        }
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Trash Section

struct TrashSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrashItem.deletedAt, order: .reverse) private var trashItems: [TrashItem]

    @State private var selectedItem: TrashItem? = nil
    @State private var itemToDelete: TrashItem? = nil
    @State private var showDeleteAllAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Заголовок секции ─────────────────────────────────────
            HStack {
                Label("Корзина", systemImage: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("SecondaryText"))

                Spacer()

                if !trashItems.isEmpty {
                    Button("Очистить всё") {
                        showDeleteAllAlert = true
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)

            Text("Объекты хранятся 2 месяца, затем удаляются автоматически. Восстановление не поддерживается — вы можете скопировать нужные данные.")
                .font(.caption)
                .foregroundStyle(Color("SecondaryText").opacity(0.6))
                .padding(.horizontal, 28)

            if trashItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 28))
                            .foregroundStyle(Color("SecondaryText").opacity(0.3))
                        Text("Корзина пуста")
                            .font(.subheadline)
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(trashItems) { item in
                        TrashItemRow(item: item) {
                            selectedItem = item
                        } onDelete: {
                            itemToDelete = item
                        }

                        if item.id != trashItems.last?.id {
                            Divider().padding(.leading, 56).padding(.horizontal, 28)
                        }
                    }
                }
                .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 28)
            }
        }
        .padding(.bottom, 28)
        .sheet(item: $selectedItem) { item in
            TrashItemDetailView(item: item)
        }
        .alert("Удалить навсегда?", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Удалить", role: .destructive) {
                if let item = itemToDelete {
                    modelContext.delete(item)
                    itemToDelete = nil
                }
            }
            Button("Отмена", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("«\(itemToDelete?.title ?? "")» будет удалён без возможности восстановления.")
        }
        .alert("Очистить корзину?", isPresented: $showDeleteAllAlert) {
            Button("Очистить", role: .destructive) {
                for item in trashItems { modelContext.delete(item) }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все \(trashItems.count) объектов будут удалены навсегда.")
        }
    }
}

// MARK: - Trash Item Row

struct TrashItemRow: View {
    let item: TrashItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var daysLeft: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: item.expiresAt)
        return max(diff.day ?? 0, 0)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Иконка типа
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color("AccentColor").opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.itemType.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AccentColor").opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title.isEmpty ? "Без названия" : item.title)
                        .font(.body)
                        .foregroundStyle(Color("PrimaryText"))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.itemType.rawValue)
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))

                        Text("·")
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))

                        Text(item.projectTitle)
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                            .lineLimit(1)

                        Spacer()

                        Text(daysLeft == 0 ? "Скоро удалится" : "Ещё \(daysLeft) дн.")
                            .font(.caption2)
                            .foregroundStyle(daysLeft < 7 ? Color.red.opacity(0.6) : Color("SecondaryText").opacity(0.4))
                    }
                }

                // Кнопка удаления
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                        .padding(5)
                        .background(Circle().fill(Color("SecondaryText").opacity(0.08)))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isHovered ? Color("AccentColor").opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Trash Item Detail (просмотр снимка)

struct TrashItemDetailView: View {
    let item: TrashItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Шапка ────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.isEmpty ? "Без названия" : item.title)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(Color("PrimaryText"))
                        Text("\(item.itemType.rawValue) · \(item.projectTitle)")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText"))
                    }
                    Spacer()
                    Button("Закрыть") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                }
                .padding(24)

                Divider()

                // ── Снимок данных ────────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Данные объекта")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("SecondaryText"))
                            .tracking(0.8)
                            .padding(.bottom, 10)

                        Text(item.snapshot.isEmpty ? "Данные отсутствуют" : item.snapshot)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color("PrimaryText"))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(24)
                }

                Divider()

                // ── Подсказка ─────────────────────────────────────────
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    Text("Выделите нужный текст и скопируйте — восстановление объекта в проект недоступно.")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 460, minHeight: 360)
    }
}
