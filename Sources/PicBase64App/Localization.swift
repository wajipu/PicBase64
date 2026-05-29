import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case zhHans = "zh-Hans"
    case en
    case ug

    static let defaultsKey = "appLanguage"

    var bundleIdentifier: String? {
        switch self {
        case .system: nil
        case .zhHans: "zh-Hans"
        case .en: "en"
        case .ug: "ug"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .current
        case .zhHans: Locale(identifier: "zh-Hans")
        case .en: Locale(identifier: "en")
        case .ug: Locale(identifier: "ug")
        }
    }

    var titleKey: String {
        switch self {
        case .system: "language_system"
        case .zhHans: "language_zh_hans"
        case .en: "language_en"
        case .ug: "language_ug"
        }
    }
}

enum AppLocalization {
    static var selectedLanguage: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: AppLanguage.defaultsKey) ?? AppLanguage.system.rawValue
            return AppLanguage(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: AppLanguage.defaultsKey)
        }
    }

    static func localized(_ key: String) -> String {
        if let identifier = selectedLanguage.bundleIdentifier,
           let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key {
                return value
            }
        }

        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    static var locale: Locale {
        selectedLanguage.locale
    }
}

func L(_ key: String) -> String {
    AppLocalization.localized(key)
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: AppLocalization.locale, arguments: args)
}
