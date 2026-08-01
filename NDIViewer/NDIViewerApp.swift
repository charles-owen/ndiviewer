import SwiftUI

/// The main application class.
/// This simply displays the content view.,
/// The main window.  
@main
@MainActor
struct NDIViewerApp: App {
    @StateObject private var model: NDIViewModel

    init() {
        _model = StateObject(wrappedValue: NDIViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowStyle(.titleBar)
    }
}
