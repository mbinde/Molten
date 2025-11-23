//
//  CatalogSheetModifiers.swift
//  Molten
//
//  View modifier for managing filter selection sheets in CatalogView
//

import SwiftUI

struct CatalogSheetModifiers: ViewModifier {
    @Binding var showingAllTags: Bool
    @Binding var showingCOESelection: Bool
    @Binding var showingManufacturerSelection: Bool
    let allAvailableTags: [String]
    let allUserTags: Set<String>
    @Binding var selectedTags: Set<String>
    let tagCounts: [String: Int]
    let allAvailableCOEs: [Int32]
    @Binding var selectedCOEs: Set<Int32>
    let coeCounts: [Int32: Int]
    let availableManufacturers: [String]
    @Binding var selectedManufacturers: Set<String>
    let manufacturerDisplayName: (String) -> String
    let manufacturerCounts: [String: Int]

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingAllTags) {
                FilterSelectionSheet.tags(
                    availableTags: allAvailableTags,
                    selectedTags: $selectedTags,
                    userTags: allUserTags,
                    itemCounts: tagCounts
                )
            }
            .sheet(isPresented: $showingCOESelection) {
                FilterSelectionSheet.coes(
                    availableCOEs: allAvailableCOEs,
                    selectedCOEs: $selectedCOEs,
                    itemCounts: coeCounts
                )
            }
            .sheet(isPresented: $showingManufacturerSelection) {
                FilterSelectionSheet.manufacturers(
                    availableManufacturers: availableManufacturers,
                    selectedManufacturers: $selectedManufacturers,
                    manufacturerDisplayName: manufacturerDisplayName,
                    itemCounts: manufacturerCounts
                )
            }
    }
}
