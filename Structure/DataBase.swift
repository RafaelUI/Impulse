import Foundation
import SwiftData
import SwiftUI

// MARK: - Проект

@Model
final class WritingProject {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var typeRawValue: String = ProjectType.book.rawValue

    var genres: [String] = []
    var tags: [String] = []

    var type: ProjectType {
        get { ProjectType(rawValue: typeRawValue) ?? .book }
        set { typeRawValue = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade) var characters: [Character]? = nil
    @Relationship(deleteRule: .cascade) var chapters: [Chapter]? = nil
    @Relationship(deleteRule: .cascade) var worldBuilding: WorldBuilding? = nil
    @Relationship(deleteRule: .cascade) var timelineTracks: [TimelineTrack]? = nil
    var timelineContent: String = ""

    // Screenplay
    @Relationship(deleteRule: .cascade) var scenes: [ScreenScene]? = nil
    @Relationship(deleteRule: .cascade) var screenRoles: [ScreenRole]? = nil

    init(title: String, type: ProjectType = .book) {
        self.title = title
        self.typeRawValue = type.rawValue
    }
}

// MARK: - Персонаж

@Model
final class Character {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int? = nil
    var role: String = ""           // Главный герой, антагонист, второстепенный...
    var appearance: String = ""     // Описание внешности
    var biography: String = ""      // Биография
    var abilities: String = ""      // Способности и навыки
    @Relationship(inverse: \WorldLocation.characters) var worldLocations: [WorldLocation]? = nil  // Структурированные связи с локациями
    var plotRole: String = ""       // Роль в сюжете
    var photoData: Data? = nil      // Прикреплённое фото (Data для SwiftData)
    var createdAt: Date = Date()

    // Связи с главами где упоминается персонаж
    var appearsInChapters: [Chapter]? = nil

    // Родитель в древе персонажей (через UUID чтобы избежать краша SwiftData)
    var parentID: UUID? = nil

    var project: WritingProject?

    init(name: String, role: String = "", age: Int? = nil) {
        self.name = name
        self.role = role
        self.age = age
    }
}

// MARK: - Глава

@Model
final class Chapter {
    var id: UUID = UUID()
    var title: String = ""
    var orderIndex: Int = 0         // Порядок глав
    var text: String = ""           // Основной текст (plain-text копия для поиска и экспорта)
    var textData: Data = Data()     // RTF-данные для форматированного редактора
    var notes: String = ""          // Заметки отдельно от текста
    var statusRawValue: String = ChapterStatus.draft.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var status: ChapterStatus {
        get { ChapterStatus(rawValue: statusRawValue) ?? .draft }
        set { statusRawValue = newValue.rawValue }
    }

    // Цветная метка строки (пустая = нет метки)
    var colorLabel: String = ""

    // Теги главы (нарративные метки)
    var tags: [String] = []

    // Персонажи в этой главе
    @Relationship(inverse: \Character.appearsInChapters) var characters: [Character]? = nil

    // Локации упомянутые в главе
    var locations: [WorldLocation]? = nil

    var project: WritingProject?

    init(title: String, orderIndex: Int = 0) {
        self.title = title
        self.orderIndex = orderIndex
    }
}

enum ChapterStatus: String, Codable, CaseIterable {
    case draft = "Черновик"
    case inProgress = "В работе"
    case done = "Готово"
    case needsRevision = "На доработке"
    var color: Color {
        switch self {
        case .draft: return .gray
        case .inProgress: return .blue
        case .done: return .green
        case .needsRevision: return .orange
        }
    }

    var icon: String {
        switch self {
        case .draft: return "pencil"
        case .inProgress: return "pencil.line"
        case .done: return "checkmark.circle.fill"
        case .needsRevision: return "arrow.uturn.left.circle"
        }
    }
}

// MARK: - Мироустройство

@Model
final class WorldBuilding {
    var id: UUID = UUID()

    // Ресурсная система (мана, чакра, нэн и т.д.)
    @Relationship(deleteRule: .cascade) var resources: [WorldResource]? = nil

    // Метафизика — законы мира, природа реальности
    @Relationship(deleteRule: .cascade) var metaphysics: [MetaphysicsConcept]? = nil

    // Концепции — идеи, философия мира
    @Relationship(deleteRule: .cascade) var concepts: [WorldConcept]? = nil

    // Структура мира — страны, фракции, иерархии
    @Relationship(deleteRule: .cascade) var structures: [WorldStructure]? = nil

    @Relationship(deleteRule: .cascade, inverse: \WorldLocation.worldBuilding) var locations: [WorldLocation]? = nil

    // Карта мира — изображение
    var mapImageData: Data? = nil
    var mapDescription: String = ""

    var project: WritingProject?

    init() {}
}

@Model
final class WorldLocation {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = ""
    var shortDescription: String = ""
    var atmosphere: String = ""
    var geography: String = ""
    var photoData: Data? = nil
    var info: String = ""
    var artifacts: String = ""
    var organizations: String = ""
    var events: String = ""

    @Relationship(inverse: \Chapter.locations) var chapters: [Chapter]? = nil
    var characters: [Character]? = nil

    var parentID: UUID? = nil

    var worldBuilding: WorldBuilding?

    init(name: String) {
        self.name = name
    }
}

@Model
final class WorldResource {
    var id: UUID = UUID()
    var name: String = ""           // Мана, чакра, нэн...
    var details: String = ""    // Как работает
    var rules: String = ""          // Правила использования
    var limitations: String = ""    // Ограничения

    var worldBuilding: WorldBuilding?

    init(name: String) {
        self.name = name
    }
}

@Model
final class MetaphysicsConcept {
    var id: UUID = UUID()
    var name: String = ""
    var details: String = ""    // Что это такое в мире
    var implications: String = ""   // Последствия для мира и персонажей

    var worldBuilding: WorldBuilding?

    init(name: String) {
        self.name = name
    }
}

@Model
final class WorldConcept {
    var id: UUID = UUID()
    var name: String = ""
    var details: String = ""
    var category: String = ""       // Философия, религия, наука мира...

    var worldBuilding: WorldBuilding?

    init(name: String) {
        self.name = name
    }
}

@Model
final class WorldStructure {
    var id: UUID = UUID()
    var name: String = ""           // Империя, фракция, измерение...
    var type: String = ""           // Политическая, магическая, социальная
    var details: String = ""
    var parentID: UUID? = nil       // Для иерархии структур

    var worldBuilding: WorldBuilding?

    init(name: String, type: String = "") {
        self.name = name
        self.type = type
    }
}

// MARK: - Трек таймлайна

@Model
final class TimelineTrack {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var orderIndex: Int = 0
    /// JSON-encoded [TimelineNode]
    var nodesData: Data = Data()

    var project: WritingProject?

    init(title: String, orderIndex: Int = 0) {
        self.title = title
        self.orderIndex = orderIndex
    }
}

// MARK: - Узел таймлайна

struct TimelineNode: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// X-позиция точки на канвасе
    var x: CGFloat
    /// ID связанной точки (если есть линия — событие с началом и концом)
    var linkedID: UUID?

    // MARK: Метаданные события
    var title: String = ""
    var note: String = ""
    var eventType: NodeEventType = .instant
    /// UUID персонажей, участвующих в событии
    var characterIDs: [UUID] = []
    /// UUID локаций, связанных с событием
    var locationIDs: [UUID] = []
    /// UUID ролей (screenplay), участвующих в событии
    var roleIDs: [UUID] = []

    init(x: CGFloat, linkedID: UUID? = nil) {
        self.x = x
        self.linkedID = linkedID
        self.eventType = linkedID == nil ? .instant : .range
    }
}

/// Тип узла таймлайна
enum NodeEventType: String, Codable, Equatable {
    case instant  // мгновенное событие (одиночная точка)
    case range    // событие с диапазоном (две связанные точки)
}

// MARK: - Вариация сцены

struct SceneVariation: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var text: String = ""       // plain-text копия для поиска и экспорта
    var textData: Data = Data() // RTF-данные для форматированного редактора

    init(title: String) {
        self.title = title
    }
}

// MARK: - Сцена (сценарий)

@Model
final class ScreenScene {
    var id: UUID = UUID()
    var title: String = ""
    var orderIndex: Int = 0
    var text: String = ""
    var notes: String = ""
    var sceneDescription: String = ""
    var sceneLocations: String = ""
    var timing: String = ""
    var statusRawValue: String = ChapterStatus.draft.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var status: ChapterStatus {
        get { ChapterStatus(rawValue: statusRawValue) ?? .draft }
        set { statusRawValue = newValue.rawValue }
    }

    // Цветная метка строки (пустая = нет метки)
    var colorLabel: String = ""

    var tags: [String] = []
    var roles: [ScreenRole]? = nil

    /// JSON-encoded [SceneVariation]
    var variationsData: Data = Data()
    var activeVariationIndex: Int = 0

    var project: WritingProject?

    // MARK: Computed helpers

    var variations: [SceneVariation] {
        get {
            guard !variationsData.isEmpty,
                  let decoded = try? JSONDecoder().decode([SceneVariation].self, from: variationsData)
            else { return [SceneVariation(title: "Вариация 1")] }
            return decoded
        }
        set {
            variationsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(title: String, orderIndex: Int = 0) {
        self.title = title
        self.orderIndex = orderIndex
        self.variations = [SceneVariation(title: "Вариация 1")]
    }
}

// MARK: - Роль (сценарий)

@Model
final class ScreenRole {
    var id: UUID = UUID()
    var name: String = ""
    var role: String = ""
    var appearance: String = ""
    var biography: String = ""
    var abilities: String = ""
    var plotRole: String = ""
    var photoData: Data? = nil
    var createdAt: Date = Date()

    @Relationship(inverse: \ScreenScene.roles) var appearsInScenes: [ScreenScene]? = nil

    var project: WritingProject?

    init(name: String, role: String = "") {
        self.name = name
        self.role = role
    }
}

// MARK: - Тип проекта

enum ProjectType: String, Codable, CaseIterable {
    case book = "Книга"
    case visualNovel = "Визуальная новелла(в разработке)"
    case screenplay = "Сценарий"
    var icon: String {
        switch self {
        case .book: return "book.closed"
        case .visualNovel: return "sparkles.tv"
        case .screenplay: return "film"
        }
    }
}

// MARK: - Журнал аудита

/// Снимок текста главы — создаётся автоматически раз в 30 минут при редактировании
@Model
final class ChapterSnapshot: Identifiable {
    var id: UUID = UUID()
    var chapterID: UUID = UUID()
    var chapterTitle: String = ""
    var content: String = ""
    var createdAt: Date = Date()

    init(chapterID: UUID, chapterTitle: String, content: String) {
        self.chapterID = chapterID
        self.chapterTitle = chapterTitle
        self.content = content
    }
}

// MARK: - Корзина

/// Тип удалённого объекта
enum TrashItemType: String, Codable {
    case chapter   = "Глава"
    case character = "Персонаж"
    case location  = "Локация"
    var icon: String {
        switch self {
        case .chapter:   return "doc.text"
        case .character: return "person.fill"
        case .location:  return "mappin.and.ellipse"
        }
    }
}

/// Снимок удалённого объекта — хранит данные для просмотра, восстановление не поддерживается
@Model
final class TrashItem {
    var id: UUID = UUID()
    var deletedAt: Date = Date()
    var typeRawValue: String = TrashItemType.chapter.rawValue
    var projectTitle: String = ""   // Из какого проекта
    var title: String = ""          // Название объекта
    var snapshot: String = ""       // JSON-снимок данных для просмотра

    var itemType: TrashItemType {
        get { TrashItemType(rawValue: typeRawValue) ?? .chapter }
        set { typeRawValue = newValue.rawValue }
    }

    /// Дата автоудаления — через 2 месяца после удаления
    var expiresAt: Date {
        Calendar.current.date(byAdding: .month, value: 2, to: deletedAt) ?? deletedAt
    }

    init(type: TrashItemType, projectTitle: String, title: String, snapshot: String) {
        self.typeRawValue = type.rawValue
        self.projectTitle = projectTitle
        self.title = title
        self.snapshot = snapshot
    }
}
