import SwiftUI

// ContentView is the app's root — delegates to RootView in PetmojiApp.swift
// This file exists as the conventional Xcode entry point.
// Actual routing logic lives in AppState + RootView.

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
