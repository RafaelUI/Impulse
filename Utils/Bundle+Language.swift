import Foundation
import SwiftUI
import ObjectiveC

private var bundleKey: UInt8 = 0

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
        // Пробуем найти .lproj для выбранного языка
        if let path = originalBundle.path(forResource: language, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            let localized = langBundle.localizedString(forKey: key, value: value, table: tableName)
            // Если нашли перевод (не вернули ключ), используем его
            if localized != key {
                return localized
            }
        }
        
        // Fallback: пробуем через main bundle (для String Catalog)
        let localized = originalBundle.localizedString(forKey: key, value: value, table: tableName)
        
        return localized
    }
}

// MARK: - SwiftUI Text Extension

extension Text {
    /// Инициализатор для локализованных строк с поддержкой runtime смены языка
    init(localizedKey key: String, bundle: Bundle? = nil) {
        let bundle = bundle ?? Bundle.localized
        let string = bundle.localizedString(forKey: key, value: nil, table: nil)
        self.init(string)
    }
}
