import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum AppThemePreset: String, CaseIterable, Identifiable {
    case midnight
    case aurora
    case sunset
    case forest
    case custom

    static let storageKey = "XMusic.SelectedTheme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight:
            return "极夜"
        case .aurora:
            return "极光"
        case .sunset:
            return "日落"
        case .forest:
            return "森屿"
        case .custom:
            return "自定义"
        }
    }

    var subtitle: String {
        switch self {
        case .midnight:
            return "经典深色蓝紫氛围"
        case .aurora:
            return "冷调蓝青霓虹"
        case .sunset:
            return "暖调红橙电影感"
        case .forest:
            return "墨绿与金色层次"
        case .custom:
            return "自选背景图与按钮色"
        }
    }

    fileprivate var presetAccent: Color {
        AppThemeDefaults.demoAccent
    }

    fileprivate var presetGradientColors: [Color] {
        [
            AppThemeDefaults.demoBackground,
            AppThemeDefaults.demoBackground
        ]
    }

    fileprivate var presetPrimaryGlow: Color {
        AppThemeDefaults.demoAccent.opacity(0.16)
    }

    fileprivate var presetSecondaryGlow: Color {
        Color.primary.opacity(0.04)
    }

    static func resolve(from rawValue: String) -> AppThemePreset {
        AppThemePreset(rawValue: rawValue) ?? .midnight
    }
}

enum AppThemeDefaults {
    static let demoAccent = Color.blue
    static let customAccent = Color.blue

    #if canImport(UIKit)
    static let demoBackground = Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
    static let demoBackground = Color(NSColor.windowBackgroundColor)
    #else
    static let demoBackground = Color(.sRGB, white: 0, opacity: 1)
    #endif
}

enum AppThemeTextColors {
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let tertiary = Color.primary.opacity(0.45)
    static let accent = AppThemeDefaults.demoAccent
    static let inverse = Color.white
    static let selectedOnLight = Color.black
    static let selectedOnAccent = Color.white
    static let success = Color.green
    static let warning = Color.orange
    static let destructive = Color.red
}

private struct PersistedThemeColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    @MainActor
    init(color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var resolvedRed: CGFloat = 1
        var resolvedGreen: CGFloat = 1
        var resolvedBlue: CGFloat = 1
        var resolvedAlpha: CGFloat = 1
        uiColor.getRed(&resolvedRed, green: &resolvedGreen, blue: &resolvedBlue, alpha: &resolvedAlpha)
        red = Double(resolvedRed)
        green = Double(resolvedGreen)
        blue = Double(resolvedBlue)
        alpha = Double(resolvedAlpha)
        #elseif canImport(AppKit)
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
        alpha = Double(nsColor.alphaComponent)
        #else
        red = 1
        green = 1
        blue = 1
        alpha = 1
        #endif
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum AppThemeStorage {
    static let customAccentDataKey = "XMusic.CustomThemeAccent"
    static let customBackgroundRevisionKey = "XMusic.CustomThemeBackgroundRevision"
    static let customBackgroundBlurKey = "XMusic.CustomThemeBackgroundBlur"

    private static let backgroundFileName = "custom-theme-background.jpg"

    static func customAccent(from data: Data) -> Color {
        guard
            !data.isEmpty,
            let persisted = try? JSONDecoder().decode(PersistedThemeColor.self, from: data)
        else {
            return AppThemeDefaults.customAccent
        }
        return persisted.swiftUIColor
    }

    @MainActor
    static func customAccentData(from color: Color) -> Data {
        (try? JSONEncoder().encode(PersistedThemeColor(color: color))) ?? Data()
    }

    static func backgroundImageData() -> Data? {
        guard let url = backgroundImageURL(),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func saveBackgroundImageData(_ data: Data) throws {
        guard let url = backgroundImageURL() else {
            throw NSError(
                domain: "XMusic.AppTheme",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法定位主题背景存储目录。"]
            )
        }

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: url, options: .atomic)
    }

    static func removeBackgroundImage() throws {
        guard let url = backgroundImageURL(),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }

    private static func backgroundImageURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("XMusic", isDirectory: true)
            .appendingPathComponent(backgroundFileName)
    }
}

struct AppThemeConfiguration {
    let preset: AppThemePreset
    let customAccent: Color
    let customBackgroundImageData: Data?
    let customBackgroundBlur: CGFloat

    var accent: Color {
        preset == .custom ? customAccent : preset.presetAccent
    }

    var gradientColors: [Color] {
        preset.presetGradientColors
    }

    var primaryGlow: Color {
        preset == .custom ? customAccent.opacity(0.28) : preset.presetPrimaryGlow
    }

    var secondaryGlow: Color {
        preset.presetSecondaryGlow
    }

    var hasCustomBackgroundImage: Bool {
        !(customBackgroundImageData?.isEmpty ?? true)
    }

    init(
        selectedThemeRawValue: String,
        customAccentData: Data,
        customBackgroundRevision: Int,
        customBackgroundBlur: Double = 0
    ) {
        preset = AppThemePreset.resolve(from: selectedThemeRawValue)
        customAccent = AppThemeStorage.customAccent(from: customAccentData)
        let storedBackgroundData = customBackgroundRevision >= 0 ? AppThemeStorage.backgroundImageData() : nil
        customBackgroundImageData = preset == .custom ? storedBackgroundData : nil
        self.customBackgroundBlur = CGFloat(min(max(customBackgroundBlur, 0), 36))
    }
}
