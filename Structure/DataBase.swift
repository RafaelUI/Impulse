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

    @Relationship(deleteRule: .cascade) var characters: [Character] = []
    @Relationship(deleteRule: .cascade) var chapters: [Chapter] = []
    @Relationship(deleteRule: .cascade) var worldBuilding: WorldBuilding? = nil

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
    var locations: String = ""      // Локации персонажа
    var plotRole: String = ""       // Роль в сюжете
    var photoData: Data? = nil      // Прикреплённое фото (Data для SwiftData)
    var createdAt: Date = Date()

    // Таймлайн персонажа — когда появляется, ключевые события
    @Relationship(deleteRule: .cascade) var timeline: [TimelineEvent] = []

    // Связи с главами где упоминается персонаж
    var appearsInChapters: [Chapter] = []

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
    var text: String = ""           // Основной текст
    var notes: String = ""          // Заметки отдельно от текста
    var statusRawValue: String = ChapterStatus.draft.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var status: ChapterStatus {
        get { ChapterStatus(rawValue: statusRawValue) ?? .draft }
        set { statusRawValue = newValue.rawValue }
    }

    // Таймлайн главы — события которые происходят в этой главе
    @Relationship(deleteRule: .cascade) var timeline: [TimelineEvent] = []

    // Персонажи в этой главе
    var characters: [Character] = []

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
    @Relationship(deleteRule: .cascade) var resources: [WorldResource] = []

    // Метафизика — законы мира, природа реальности
    @Relationship(deleteRule: .cascade) var metaphysics: [MetaphysicsConcept] = []

    // Концепции — идеи, философия мира
    @Relationship(deleteRule: .cascade) var concepts: [WorldConcept] = []

    // Структура мира — страны, фракции, иерархии
    @Relationship(deleteRule: .cascade) var structures: [WorldStructure] = []

    // Карта мира — изображение
    var mapImageData: Data? = nil
    var mapDescription: String = ""

    var project: WritingProject?

    init() {}
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

// MARK: - Таймлайн (общий для персонажей и глав)

@Model
final class TimelineEvent {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var date: String = ""           // Строка т.к. дата может быть выдуманной ("3-й цикл")
    var orderIndex: Int = 0         // Порядок в таймлайне
    var typeRawValue: String = TimelineEventType.event.rawValue

    var type: TimelineEventType {
        get { TimelineEventType(rawValue: typeRawValue) ?? .event }
        set { typeRawValue = newValue.rawValue }
    }

    init(title: String, date: String = "") {
        self.title = title
        self.date = date
    }
}

enum TimelineEventType: String, Codable, CaseIterable {
    case birth = "Рождение"
    case death = "Смерть"
    case event = "Событие"
    case turning = "Поворотный момент"
    case appearance = "Появление"

    var icon: String {
        switch self {
        case .birth: return "star.fill"
        case .death: return "xmark.circle.fill"
        case .event: return "circle.fill"
        case .turning: return "arrow.triangle.turn.up.right.circle.fill"
        case .appearance: return "person.fill.badge.plus"
        }
    }
}

// MARK: - Тип проекта

enum ProjectType: String, Codable, CaseIterable {
    case book = "Книга"
    case visualNovel = "Визуальная новелла"
    case screenplay = "Сценарий"
    case scientific = "Научный проект"

    var icon: String {
        switch self {
        case .book: return "book.closed"
        case .visualNovel: return "sparkles.tv"
        case .screenplay: return "film"
        case .scientific: return "graduationcap"
        }
    }
}
