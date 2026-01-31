import Foundation

/// 本地化管理器 - 确保开发模式和打包模式都能正确加载本地化资源
enum L10n {
    /// 资源 Bundle（开发/打包模式通用）
    private static let resourceBundle: Bundle = {
        // 1. 首先尝试从应用 Bundle 加载（打包模式）
        if let bundlePath = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
           FileManager.default.fileExists(atPath: bundlePath) {
            return Bundle.main
        }
        
        // 2. 开发模式：查找 Resources 目录
        // 尝试多种可能的路径
        let possiblePaths = [
            // 从可执行文件位置向上查找
            Bundle.main.bundlePath + "/../../Resources",
            Bundle.main.bundlePath + "/../../../Resources",
            Bundle.main.bundlePath + "/../../../../Resources",
            // 从当前工作目录查找
            FileManager.default.currentDirectoryPath + "/Resources",
            // 从项目根目录查找（通过检测 Package.swift）
            findProjectRoot() + "/Resources"
        ]
        
        for path in possiblePaths {
            let expandedPath = (path as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: expandedPath + "/zh-Hans.lproj/Localizable.strings") {
                if let bundle = Bundle(path: expandedPath) {
                    return bundle
                }
                // 如果无法直接创建 Bundle，创建一个临时的
                return createResourceBundle(at: expandedPath) ?? Bundle.main
            }
        }
        
        // 3. 回退到主 Bundle
        return Bundle.main
    }()
    
    /// 用户手动选择的语言（存储在 UserDefaults）
    /// 值: nil = 跟随系统, "zh-Hans" = 中文, "en" = 英文
    private static var userOverrideLanguage: String? {
        get { UserDefaults.standard.string(forKey: "AppLanguageOverride") }
        set { UserDefaults.standard.set(newValue, forKey: "AppLanguageOverride") }
    }
    
    /// 动态获取用户首选语言（每次调用时检测）
    private static var preferredLanguage: String {
        // 1. 优先使用用户手动设置的语言
        if let override = userOverrideLanguage {
            return override
        }
        
        // 2. 回退到系统语言
        guard let firstLang = Locale.preferredLanguages.first else {
            return "en"
        }
        
        // 如果系统首选语言是中文，返回 zh-Hans
        if firstLang.hasPrefix("zh") {
            return "zh-Hans"
        }
        
        // 其他情况返回英文
        return "en"
    }
    
    /// 设置用户首选语言
    /// - Parameter language: 语言代码 ("zh-Hans", "en") 或 nil 表示跟随系统
    static func setLanguage(_ language: String?) {
        userOverrideLanguage = language
    }
    
    /// 获取当前语言设置状态
    /// - Returns: nil = 跟随系统, "zh-Hans" = 中文, "en" = 英文
    static func getCurrentLanguageSetting() -> String? {
        return userOverrideLanguage
    }
    
    /// 动态获取语言专用 Bundle
    private static var localizedBundle: Bundle {
        let lang = preferredLanguage
        if let path = resourceBundle.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        // 回退到英文
        if let path = resourceBundle.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return resourceBundle
    }
    
    /// 查找项目根目录
    private static func findProjectRoot() -> String {
        var path = FileManager.default.currentDirectoryPath
        
        // 向上查找包含 Package.swift 的目录
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: path + "/Package.swift") {
                return path
            }
            path = (path as NSString).deletingLastPathComponent
        }
        
        return FileManager.default.currentDirectoryPath
    }
    
    /// 创建资源 Bundle
    private static func createResourceBundle(at path: String) -> Bundle? {
        // 由于 Resources 目录本身不是一个 Bundle，我们需要返回 nil
        // 但我们可以直接使用路径加载字符串
        return nil
    }
    
    /// 获取本地化字符串
    static func string(_ key: String, comment: String = "") -> String {
        // 首先尝试从语言专用 Bundle 加载
        let value = localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        
        // 如果返回的是 key 本身，说明没找到，尝试直接从文件加载
        if value == key {
            return loadStringDirectly(key: key) ?? key
        }
        
        return value
    }
    
    /// 直接从 .strings 文件加载（开发模式备用方案）
    private static func loadStringDirectly(key: String) -> String? {
        let lang = preferredLanguage
        let possiblePaths = [
            Bundle.main.bundlePath + "/../../Resources/\(lang).lproj/Localizable.strings",
            Bundle.main.bundlePath + "/../../../Resources/\(lang).lproj/Localizable.strings",
            FileManager.default.currentDirectoryPath + "/Resources/\(lang).lproj/Localizable.strings",
            findProjectRoot() + "/Resources/\(lang).lproj/Localizable.strings"
        ]
        
        for path in possiblePaths {
            let expandedPath = (path as NSString).standardizingPath
            if let dict = NSDictionary(contentsOfFile: expandedPath) as? [String: String],
               let value = dict[key] {
                return value
            }
        }
        
        return nil
    }
}

/// 便捷函数：替代 NSLocalizedString
func LocalizedString(_ key: String, comment: String = "") -> String {
    return L10n.string(key, comment: comment)
}
