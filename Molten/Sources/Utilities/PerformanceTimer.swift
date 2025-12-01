//
//  PerformanceTimer.swift
//  Molten
//
//  Utility for measuring view load performance in DEBUG builds
//

import SwiftUI

/// Measures time elapsed since creation - useful for tracking view load performance
@MainActor
@Observable
class PerformanceTimer {
    private let startTime: CFAbsoluteTime
    var loadTime: TimeInterval?

    init() {
        self.startTime = CFAbsoluteTimeGetCurrent()
    }

    /// Mark loading as complete and record final time
    func complete() {
        guard loadTime == nil else { return }  // Only record first completion
        loadTime = CFAbsoluteTimeGetCurrent() - startTime
    }

    /// Formatted time string for display (e.g., "52ms" or "1.2s")
    var formattedTime: String {
        guard let time = loadTime else { return "..." }

        if time < 1.0 {
            return String(format: "%.0fms", time * 1000)
        } else {
            return String(format: "%.1fs", time)
        }
    }
}

/// View modifier that displays performance timing in the navigation title (DEBUG only)
struct PerformanceTitleModifier: ViewModifier {
    let title: String
    let timer: PerformanceTimer

    func body(content: Content) -> some View {
        #if DEBUG
        // Hide performance timing during screenshot/UI test runs
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")

        if isUITesting {
            content.navigationTitle(title)
        } else {
            content.navigationTitle(navigationTitleWithTiming)
        }
        #else
        content
            .navigationTitle(title)
        #endif
    }

    private var navigationTitleWithTiming: String {
        if let _ = timer.loadTime {
            return "\(title) (\(timer.formattedTime))"
        } else {
            return title
        }
    }
}

extension View {
    /// Adds performance timing to navigation title (DEBUG builds only)
    /// - Parameters:
    ///   - title: The base navigation title
    ///   - timer: The PerformanceTimer tracking load time
    /// - Returns: Modified view with timing appended to title in DEBUG builds
    func performanceTitle(_ title: String, timer: PerformanceTimer) -> some View {
        modifier(PerformanceTitleModifier(title: title, timer: timer))
    }
}
