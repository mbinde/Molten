//
//  ProjectLogView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/29/25.
//

import SwiftUI

struct ProjectLogView: View {
    @State private var showingAddProject = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Icon and title
                VStack(spacing: 16) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Project Log")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your glass projects")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Feature description
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coming Soon")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Document project progress and techniques", systemImage: "note.text")
                        Label("Track glass usage per project", systemImage: "chart.bar.doc.horizontal")
                        Label("Photo documentation", systemImage: "camera")
                        Label("Project notes and observations", systemImage: "pencil.and.scribble")
                        Label("Time tracking for projects", systemImage: "timer")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Placeholder for future functionality
                VStack(spacing: 16) {
                    Text("This feature is planned for a future update.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Get Notified") {
                        // Placeholder for feedback or notification signup
                        showingAddProject = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true) // Disabled for now
                }
            }
            .padding()
            .navigationTitle("Project Log")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Coming Soon", isPresented: $showingAddProject) {
            Button("OK") { }
        } message: {
            Text("Project logging functionality will be available in a future update.")
        }
    }
}

#Preview {
    ProjectLogView()
}