import SwiftUI
import Combine

public extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

/// Управляет выбранным языком интерфейса приложения.
/// Смена языка применяется мгновенно через \.locale environment.
@MainActor final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @AppStorage("appLanguage") private(set) var currentLanguage: String = "ru"

    let availableLanguages: [(id: String, label: String)] = [
        ("ru", "Русский"),
        ("en", "English"),
    ]

    var currentLocale: Locale { Locale(identifier: currentLanguage) }

    private init() {
        // Сохраняем язык в UserDefaults чтобы AppleLanguages был корректен при холодном старте
        UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
    }

    func setLanguage(_ language: String) {
        guard availableLanguages.map({ $0.id }).contains(language),
              currentLanguage != language else { return }
        currentLanguage = language
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        // objectWillChange автоматически срабатывает из-за @AppStorage
    }
}
