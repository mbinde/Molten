//
//  SettingsToolbarButton.swift
//  Molten
//
//  Created by Assistant on 10/20/25.
//

import SwiftUI

/// Provides a consistent settings gear icon toolbar button across all main tab views
///
/// Usage:
/// ```swift
/// .toolbar {
///     SettingsToolbarButton()
/// }
/// ```
struct SettingsToolbarButton: ToolbarContent {
    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            } label: {
                Image(systemName: "gear")
            }
        }
        #else
        ToolbarItem(placement: .navigation) {
            Button {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            } label: {
                Image(systemName: "gear")
            }
        }
        #endif
    }
}
