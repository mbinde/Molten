//
//  ViewUtilitiesWarningFixTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import SwiftUI
@testable import Flameworker

@Suite("ViewUtilities Warning Fix Tests")
struct ViewUtilitiesWarningFixTests {
    
    @Test("EmptyStateView can be created with basic parameters")
    func emptyStateViewBasicCreation() {
        let view = EmptyStateView(
            icon: "folder",
            title: "No Items",
            subtitle: "Add some items to get started"
        )
        
        #expect(view.icon == "folder")
        #expect(view.title == "No Items")
        #expect(view.subtitle == "Add some items to get started")
        #expect(view.buttonTitle == nil)
        #expect(view.features == nil)
    }
    
    @Test("EmptyStateView can be created with action button")
    func emptyStateViewWithButton() {
        var buttonTapped = false
        let view = EmptyStateView(
            icon: "plus",
            title: "Add Item",
            subtitle: "Tap to add your first item",
            buttonTitle: "Add Now"
        ) {
            buttonTapped = true
        }
        
        #expect(view.buttonTitle == "Add Now")
        #expect(buttonTapped == false, "Button action should not be called during creation")
    }
    
    @Test("SearchEmptyStateView can be created")
    func searchEmptyStateViewCreation() {
        let view = SearchEmptyStateView(searchText: "test query")
        
        #expect(view.searchText == "test query")
    }
    
    @Test("FeatureDescription can be created")
    func featureDescriptionCreation() {
        let feature = FeatureDescription(title: "Test Feature", icon: "star")
        
        #expect(feature.title == "Test Feature")
        #expect(feature.icon == "star")
    }
    
    @Test("LoadingOverlay shows when loading is true")
    func loadingOverlayShowsWhenLoading() {
        let overlay = LoadingOverlay(isLoading: true, message: "Loading data...")
        
        #expect(overlay.isLoading == true)
        #expect(overlay.message == "Loading data...")
    }
    
    @Test("LoadingOverlay is hidden when loading is false")
    func loadingOverlayHiddenWhenNotLoading() {
        let overlay = LoadingOverlay(isLoading: false, message: "Loading...")
        
        #expect(overlay.isLoading == false)
    }
    
    @Test("AlertBuilders can create deletion confirmation alert")
    func alertBuildersCreateDeletionAlert() {
        @State var isPresented = false
        var confirmCalled = false
        
        let alert = AlertBuilders.deletionConfirmation(
            title: "Delete Items",
            message: "Are you sure you want to delete {count} items?",
            itemCount: 3,
            isPresented: $isPresented
        ) {
            confirmCalled = true
        }
        
        // The alert should be created without errors
        #expect(confirmCalled == false, "Confirmation should not be called during alert creation")
    }
    
    @Test("AlertBuilders can create error alert")
    func alertBuildersCreateErrorAlert() {
        @State var isPresented = false
        
        let alert = AlertBuilders.error(
            message: "Something went wrong",
            isPresented: $isPresented
        )
        
        // The alert should be created without errors
        #expect(isPresented == false)
    }
}