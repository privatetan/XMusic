//
//  XMusicApp.swift
//  XMusic
//
//  Created by Galio on 2026/3/20.
//

import SwiftUI

@main
struct XMusicApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(XMusicAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(context: .shared)
        }
    }
}
