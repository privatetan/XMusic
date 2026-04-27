import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 应用全局背景层，与 Demo 保持系统背景和轻量蓝色氛围。
struct AppBackgroundView: View {
    @AppStorage(AppThemePreset.storageKey) private var selectedThemeRawValue = AppThemePreset.midnight.rawValue
    @AppStorage(AppThemeStorage.customAccentDataKey) private var customAccentData = Data()
    @AppStorage(AppThemeStorage.customBackgroundRevisionKey) private var customBackgroundRevision = 0
    @AppStorage(AppThemeStorage.customBackgroundBlurKey) private var customBackgroundBlur = 0.0

    private var theme: AppThemeConfiguration {
        AppThemeConfiguration(
            selectedThemeRawValue: selectedThemeRawValue,
            customAccentData: customAccentData,
            customBackgroundRevision: customBackgroundRevision,
            customBackgroundBlur: customBackgroundBlur
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let backgroundImage {
                    backgroundImage
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .blur(radius: theme.customBackgroundBlur)
                        .clipped()

                    AppThemeDefaults.demoBackground.opacity(0.78)
                }

                AppThemeDefaults.demoBackground
                    .opacity(backgroundImage == nil ? 1 : 0.86)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    #if canImport(UIKit)
    private var backgroundImage: Image? {
        guard let data = theme.customBackgroundImageData,
              let uiImage = UIImage(data: data)
        else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    #else
    private var backgroundImage: Image? { nil }
    #endif
}
