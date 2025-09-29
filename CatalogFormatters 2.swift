//
//  CatalogFormatters.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation

struct CatalogFormatters {
    static let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}