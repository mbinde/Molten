//
//  AddInventoryItemView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct AddInventoryItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let prefilledCatalogCode: String?
    
    init(prefilledCatalogCode: String? = nil) {
        self.prefilledCatalogCode = prefilledCatalogCode
    }
    
    var body: some View {
        NavigationStack {
            InventoryFormView(prefilledCatalogCode: prefilledCatalogCode)
        }
    }
}

#Preview {
    NavigationStack {
        AddInventoryItemView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
