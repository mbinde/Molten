//
//  KeyboardDismissal.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Utility for dismissing the keyboard across iOS views
//

#if canImport(UIKit)
import UIKit
#endif

import SwiftUI

/// Utility for dismissing the keyboard
enum KeyboardDismissal {
    /// Dismisses the currently active keyboard
    static func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

// MARK: - View Extension

extension View {
    /// Dismisses the keyboard when this view is tapped
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            KeyboardDismissal.hideKeyboard()
        }
    }
}
