//
//  CatalogOriginalDescriptionView.swift
//  Molten
//
//  Created on 2025-12-21.
//
//  Debug-only view showing the original manufacturer description and AI sources
//

import SwiftUI
import SQLite3

#if DEBUG

/// Debug-only view to show the original manufacturer description and AI sources
/// Queries the mfrdesc SQLite directly to avoid modifying the model
struct CatalogOriginalDescriptionView: View {
    let itemStableId: String

    @State private var originalDescription: String? = nil
    @State private var aiSources: [String] = []
    @State private var isExpanded = true  // Expanded by default
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("AI Sources (Debug)")
                        .font(DesignSystem.Typography.subsectionTitle)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if !aiSources.isEmpty {
                        Text("\(aiSources.count)")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.textSecondary)
                            .clipShape(Capsule())
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(DesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let error = error {
                Text(error)
                    .font(DesignSystem.Typography.formLabel)
                    .foregroundColor(DesignSystem.Colors.accentDanger)
            } else {
                // AI Sources section
                if !aiSources.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Sources:")
                            .font(DesignSystem.Typography.formLabel)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ForEach(aiSources, id: \.self) { source in
                            if source == "manufacturer" {
                                Text("• Manufacturer description")
                                    .font(DesignSystem.Typography.formValue)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            } else if let url = URL(string: source) {
                                Link(destination: url) {
                                    HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                                        Text("•")
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                        Text(source)
                                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                                            .underline()
                                            .multilineTextAlignment(.leading)
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption)
                                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                                    }
                                    .font(DesignSystem.Typography.formValue)
                                }
                            } else {
                                Text("• \(source)")
                                    .font(DesignSystem.Typography.formValue)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                } else {
                    Text("No AI sources available")
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
                }

                // Original description section (if available)
                if let desc = originalDescription, !desc.isEmpty {
                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.xs)

                    HStack {
                        Text("Original manufacturer text:")
                            .font(DesignSystem.Typography.formLabel)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Spacer()

                        Button {
                            UIPasteboard.general.string = desc
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(desc)
                        .font(DesignSystem.Typography.formValue)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Query the separate mfrdesc database
        guard let dbPath = Bundle.main.path(forResource: "mfrdesc", ofType: "sqlite") else {
            error = "Manufacturer descriptions database not found"
            return
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            error = "Failed to open database"
            return
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT manufacturer_description_orig, ai_sources FROM manufacturer_descriptions WHERE stable_id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            error = "Failed to prepare query"
            return
        }
        defer { sqlite3_finalize(stmt) }

        // Use withCString to ensure proper string binding
        let result = itemStableId.withCString { cString in
            sqlite3_bind_text(stmt, 1, cString, -1, nil)
            return sqlite3_step(stmt)
        }

        if result == SQLITE_ROW {
            // Column 0: manufacturer_description_orig
            if let textPtr = sqlite3_column_text(stmt, 0) {
                let desc = String(cString: textPtr)
                originalDescription = desc.isEmpty ? nil : desc
            } else {
                originalDescription = nil
            }

            // Column 1: ai_sources (JSON array)
            if let sourcesPtr = sqlite3_column_text(stmt, 1) {
                let sourcesJson = String(cString: sourcesPtr)
                aiSources = parseJsonArray(sourcesJson)
            } else {
                aiSources = []
            }
        } else {
            originalDescription = nil
            aiSources = []
        }
    }

    /// Parse a JSON array of strings
    private func parseJsonArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}

// MARK: - Preview

#Preview("With URLs") {
    // Amber Purple - has multiple URL sources
    CatalogOriginalDescriptionView(itemStableId: "0eewhU")
        .padding()
}

#Preview("Manufacturer Only") {
    // Has manufacturer description
    CatalogOriginalDescriptionView(itemStableId: "5BcNTw")
        .padding()
}

#endif
