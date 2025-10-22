//
//  PDFPreviewView.swift
//  Molten
//
//  SwiftUI wrapper for PDF preview using PDFKit
//

import SwiftUI
import PDFKit

#if canImport(UIKit)
import UIKit

/// SwiftUI wrapper for previewing PDF files using PDFKit
struct PDFPreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("PDF Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingShare = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showingShare) {
                    ShareSheet(items: [url])
                }
        }
    }
}

/// UIViewRepresentable wrapper for PDFView
private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .white  // Always white background to match printed output

        // Load document synchronously on main thread
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update document if needed
        if uiView.document == nil {
            if let document = PDFDocument(url: url) {
                uiView.document = document
            }
        }
    }
}
#endif
