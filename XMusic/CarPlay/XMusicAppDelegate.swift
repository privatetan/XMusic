//
//  XMusicAppDelegate.swift
//  XMusic
//
//  Created by Codex on 2026/4/19.
//

#if os(iOS)
import CarPlay
import UIKit

final class XMusicAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )

        if connectingSceneSession.role == .carTemplateApplication {
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = CarPlaySceneDelegate.self
        }

        return configuration
    }
}
#endif
