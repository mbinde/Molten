//
//  CatalogManufacturerFilterView.swift
//  Molten
//
//  Filter sheet for selecting manufacturers in CatalogView
//

import SwiftUI

struct CatalogManufacturerFilterView: View {
    let availableManufacturers: [String]
    @Binding var selectedManufacturer: String?
    let manufacturerDisplayName: (String) -> String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button("All Manufacturers") {
                    selectedManufacturer = nil
                    dismiss()
                }
                .foregroundColor(.primary)

                ForEach(availableManufacturers, id: \.self) { manufacturer in
                    Button(action: {
                        selectedManufacturer = manufacturer
                        dismiss()
                    }) {
                        HStack {
                            Text(manufacturerDisplayName(manufacturer))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedManufacturer == manufacturer {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Manufacturer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
