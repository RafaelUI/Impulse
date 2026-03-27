import Foundation
import SwiftUI
import ObjectiveC

private var bundleKey: UInt8 = 0

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
        // Для String Catalog (.xcstrings) используем специальный подход
        // Проверяем есть ли .xcstrings файл
        if let xcstringsPath = Bundle.main.path(forResource: "Localizable", ofType: "xcstrings") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: xcstringsPath))
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let strings = json?["strings"] as? [String: Any],
                   let keyData = strings[key] as? [String: Any],
                   let localizations = keyData["localizations"] as? [String: Any],
                   let langData = localizations[language] as? [String: Any],
                   let stringUnit = langData["stringUnit"] as? [String: Any],
                   let value = stringUnit["value"] as? String {
                    return value
                }
            } catch {
                break
            }
        }
        
        // Fallback: пробуем через .lproj папки
        if let path = originalBundle.path(forResource: language, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            let localized = langBundle.localizedString(forKey: key, value: value, table: tableName)
            if localized != key {
                return localized
            }
        }
        
        // Последний fallback: main bundle
        return originalBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - SwiftUI Text Extension

extension Text {
    /// Переопределяем стандартный инициализатор для локализованных строк
    init(_ key: LocalizedStringKey) {
        // Используем наш кастомный Bundle для локализации
        let bundle = Bundle.localized
        let localizedString = bundle.localizedString(forKey: key.key, value: nil, table: nil)
        self.init(localizedString)
    }
}
