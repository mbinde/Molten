import SwiftUI

struct ColorListView: View {
    @State private var colors: [ColorData] = []
    private let hapticsManager = HapticsManager()
    
    var body: some View {
        NavigationView {
            List {
                Section("JSON Files") {
                    ForEach(colors, id: \.id) { color in
                        ColorRowView(color: color)
                            .onTapGesture {
                                // Only trigger haptics if supported
                                if hapticsManager.isHapticsAvailable {
                                    hapticsManager.playSelection()
                                }
                            }
                    }
                }
            }
            .navigationTitle("Glass Colors")
            .onAppear {
                loadColors()
            }
        }
    }
    
    private func loadColors() {
        // Load your color data here
        // This would typically load from your colors.json file
    }
}

struct ColorRowView: View {
    let color: ColorData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(color.name)
                    .font(.headline)
                Text(color.code)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !color.tags.isEmpty {
                Text(color.tags.joined(separator: ", "))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ColorData: Codable {
    let id: String
    let code: String
    let manufacturer: String
    let name: String
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, code, manufacturer, name, tags
    }
}

#Preview {
    ColorListView()
}