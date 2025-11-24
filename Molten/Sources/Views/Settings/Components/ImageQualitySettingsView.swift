//
//  ImageQualitySettingsView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct ImageQualitySettingsView: View {
    @State private var cacheSize: Int64 = 0
    @State private var showingClearCacheAlert = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { UserSettings.shared.downloadFullSizeImages },
                    set: { UserSettings.shared.downloadFullSizeImages = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Download Full-Size Images")
                            .font(.body)
                        Text("Use original high-resolution images instead of thumbnails")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier("image_quality_full_size_toggle")
            } footer: {
                if UserSettings.shared.downloadFullSizeImages {
                    Text("Full-size images provide better quality but use significantly more storage space. A typical full-size image is 200-500 KB vs 20-50 KB for thumbnails.")
                } else {
                    Text("Thumbnails (400px) are optimized for mobile viewing and use less storage space.")
                }
            }

            Section {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(formatBytes(cacheSize))
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    showingClearCacheAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Image Cache")
                    }
                }
                .disabled(cacheSize == 0)
                .accessibilityIdentifier("image_quality_clear_cache")
            } header: {
                Text("Storage Management")
            } footer: {
                Text("Clearing the cache will free up storage space. Images will be re-downloaded as needed when you view items.")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Image Quality vs Storage")
                                .font(.callout)
                                .foregroundStyle(.primary)

                            Text("Enabling full-size images will download higher resolution versions (typically 10x larger than thumbnails). This is recommended only if you have sufficient storage space and want the best image quality.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Image Quality & Cache")
        .task {
            updateCacheSize()
        }
        .alert("Clear Image Cache?", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Cache", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will delete all downloaded images (\(formatBytes(cacheSize))). Images will be re-downloaded as needed.")
        }
    }

    private func updateCacheSize() {
        cacheSize = ImageDownloadService.getCacheSize()
    }

    private func clearCache() {
        ImageDownloadService.clearAllCache()
        updateCacheSize()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
