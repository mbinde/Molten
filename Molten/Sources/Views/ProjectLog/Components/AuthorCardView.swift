//
//  AuthorCardView.swift
//  Molten
//
//  Displays read-only author information for a project plan
//

import SwiftUI

struct AuthorCardView: View {
    let author: AuthorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author name and email
            HStack {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(author.displayName)
                        .font(.headline)

                    if let email = author.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)

            // Social links
            if hasSocialLinks {
                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    if let website = author.website {
                        Link(destination: URL(string: addSchemeIfNeeded(website))!) {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(website)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    if let instagram = author.instagram {
                        Link(destination: URL(string: "https://instagram.com/\(instagram)")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("@\(instagram)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    if let facebook = author.facebook {
                        Link(destination: URL(string: "https://facebook.com/\(facebook)")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "f.square")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(facebook)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    if let youtube = author.youtube {
                        Link(destination: URL(string: "https://youtube.com/@\(youtube)")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.rectangle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("@\(youtube)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var hasSocialLinks: Bool {
        return author.website != nil || author.instagram != nil ||
               author.facebook != nil || author.youtube != nil
    }

    private func addSchemeIfNeeded(_ url: String) -> String {
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            return url
        }
        return "https://\(url)"
    }
}

#Preview {
    AuthorCardView(author: AuthorModel(
        name: "Jane Smith",
        email: "jane@example.com",
        website: "glassartist.com",
        instagram: "janeglassart"
    ))
    .padding()
}
