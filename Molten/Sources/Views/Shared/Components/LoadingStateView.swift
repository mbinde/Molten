//
//  LoadingStateView.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Reusable loading state component for consistent loading UX
//

import SwiftUI

/// A reusable loading state view with centered progress indicator
/// Use this instead of inline ProgressView patterns for consistency
struct LoadingStateView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack {
            Spacer()
            ProgressView(message)
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Default") {
    LoadingStateView()
}

#Preview("Custom Message") {
    LoadingStateView(message: "Syncing data...")
}

#Preview("With Modifier") {
    List {
        Text("Item 1")
        Text("Item 2")
        Text("Item 3")
    }
    .loadingOverlay(isLoading: true, message: "Loading items...")
}
