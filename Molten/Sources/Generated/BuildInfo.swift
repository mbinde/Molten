//
//  BuildInfo.swift
//  Molten
//
//  Fallback file - overwritten by set-build-number.sh during build
//  This file exists so the project compiles on fresh checkouts before the build script runs.
//

import Foundation

/// Build information generated at compile time
enum BuildInfo {
    /// Git commit count (build number)
    static let buildNumber = "dev"

    /// Short git commit hash
    static let gitHash = "local"

    /// Combined version string (e.g., "3536 (abc1234)")
    static var fullBuildString: String {
        "\(buildNumber) (\(gitHash))"
    }
}
