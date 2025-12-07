//
//  QRCodeScannerView.swift
//  Molten
//
//  In-app QR code scanner using DataScannerViewController (iOS 16+)
//  Scans Molten QR codes and processes them via deep link handling
//

import SwiftUI
import VisionKit
import Vision

/// SwiftUI wrapper for DataScannerViewController to scan QR codes
struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCodeScanned: (String) -> Void

    @State private var isScanning = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(
                        onCodeScanned: { code in
                            onCodeScanned(code)
                            dismiss()
                        }
                    )
                    .ignoresSafeArea()
                } else {
                    unsupportedView
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Camera Not Available")
                .font(DesignSystem.Typography.sectionTitle)

            Text("QR code scanning requires camera access. Please check your device settings.")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.accentPrimary)
        }
        .padding()
    }
}

/// UIViewControllerRepresentable wrapper for DataScannerViewController
struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Start scanning if not already
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCodeScanned: (String) -> Void
        private var hasScanned = false  // Prevent multiple scans

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            processItem(item, from: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Auto-process the first recognized QR code
            guard let item = addedItems.first else { return }
            processItem(item, from: dataScanner)
        }

        private func processItem(_ item: RecognizedItem, from scanner: DataScannerViewController) {
            guard !hasScanned else { return }

            switch item {
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    // Check if it's a Molten QR code
                    if payload.hasPrefix("molten://") {
                        hasScanned = true
                        scanner.stopScanning()

                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)

                        onCodeScanned(payload)
                    }
                }
            default:
                break
            }
        }
    }
}

#Preview {
    QRCodeScannerView { code in
        print("Scanned: \(code)")
    }
}
