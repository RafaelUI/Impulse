import Foundation
import SwiftUI
import ObjectiveC

private var bundleKey: UInt8 = 0

// MARK: - Custom LocalizedStringKey

struct LocalizedStringKey: ExpressibleByStringLiteral {
    let key: String
    let bundle: Bundle
    
    init(stringLiteral value: String) {
        self.key = value
        self.bundle = Bundle.localized
    }
    
    init(_ key: String, bundle: Bundle = Bundle.localized) {
        self.key = key
        self.bundle = bundle
    }
    
    var stringLiteral: String {
        return key
    }
}

// MARK: - Bundle Extension

extension Bundle {
    
    /// Переопределяет язык для всех локализованных строк
    static func setLanguage(_ language: String) {
        // Создаем кастомный Bundle с нужным языком
        let customBundle = LanguageBundle(language: language)
        object_setAssociatedObject(Bundle.main, &bundleKey, customBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Обновляем UserDefaults для локали (влияет на форматирование дат/чисел)
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    /// Возвращает текущий кастомный Bundle или main
    static var localized: Bundle {
        if let bundle = object_getAssociatedObject(Bundle.main, &bundleKey) as? LanguageBundle {
            return bundle
        }
        return Bundle.main
    }
}

// MARK: - Language Bundle

private class LanguageBundle: Bundle {
    private let language: String
    private let originalBundle: Bundle
    
    init(language: String) {
        self.language = language
        self.originalBundle = Bundle.main
        super.init(path: Bundle.main.bundlePath)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // Ищем в String Catalog (.xcstrings) через main bundle
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // Ищем ключ в JSON
            if let strings = json["strings"] as? [String: Any],
               let keyData = strings[key] as? [String: Any],
               let localizations = keyData["localizations"] as? [String: Any],
               let langData = localizations[language] as? [String: Any],
               let stringUnit = langData["stringUnit"] as? [String: Any],
               let value = stringUnit["value"] as? String {
                return value
            }
        }
        
        // Fallback: пробуем через main bundle
        return originalBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - Text Extension

extension Text {
    /// Создает Text с локализацией через наш кастомный Bundle
    init(localized key: LocalizedStringKey) {
        let localizedString = key.bundle.localizedString(forKey: key.key, value: nil, table: nil)
        self.init(localizedString)
    }
}
