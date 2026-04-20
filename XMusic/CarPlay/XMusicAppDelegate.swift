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
    private let carPlayTemplateRole = "CPTemplateApplicationSceneSessionRoleApplication"

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let role = connectingSceneSession.role
        let isCarPlayRole = role.rawValue == carPlayTemplateRole
        let configurationName: String?

        if isCarPlayRole {
            configurationName = "CarPlay Configuration"
        } else {
            configurationName = "Default Configuration"
        }

        let configuration = UISceneConfiguration(
            name: configurationName,
            sessionRole: role
        )

        if isCarPlayRole {
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = CarPlaySceneDelegate.self
        }

        return configuration
    }
}
#endif
