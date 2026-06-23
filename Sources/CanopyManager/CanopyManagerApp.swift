import SwiftUI

@main
struct CanopyManagerApp: App {
  var body: some Scene {
    Window("Canopy Manager", id: "main") {
      ContentView()
        .task {
          NSApplication.shared.setActivationPolicy(.regular)
          NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    .windowResizability(.contentSize)
  }
}
