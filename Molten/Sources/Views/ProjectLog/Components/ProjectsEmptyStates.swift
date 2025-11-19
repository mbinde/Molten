//
//  ProjectsEmptyStates.swift
//  Flameworker
//
//  Created by Assistant on 1/19/25.
//

import SwiftUI

struct ProjectsEmptyStates {
    /// Standard empty state when there are no projects
    static func standard(onCreatePlan: @escaping () async -> Void) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)

                Text("No Project Plans Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Save notes, photos, recipes, and tutorials to bring your glass art ideas to life")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Create Your First Plan") {
                    Task {
                        await onCreatePlan()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Empty state shown when search/filters return no results
    static var searchResults: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)

                Text("No Results Found")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Try adjusting your search")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
