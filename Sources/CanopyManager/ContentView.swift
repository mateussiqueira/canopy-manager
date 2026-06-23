import SwiftUI

struct ContentView: View {
  @StateObject private var state = AppState()

  var body: some View {
    HSplitView {
      // Left panel — main content
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header
          StatusDashboard().environmentObject(state)
          Divider()
          QuickPromptView().environmentObject(state)
        }
        .padding(16)
      }
      .frame(minWidth: 400)

      // Right panel — logs + models
      VSplitView {
        ServerLogView().environmentObject(state)
          .frame(minHeight: 150)
        ModelManagementView().environmentObject(state)
          .frame(minHeight: 200)
      }
      .frame(minWidth: 320)
    }
    .frame(minWidth: 780, minHeight: 600)
    .sheet(isPresented: $state.showDownloadPanel) {
      DownloadPanelView().environmentObject(state)
    }
    .sheet(isPresented: $state.showError) {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 40)).foregroundStyle(.orange)
        Text(state.errorMessage ?? "Erro desconhecido")
          .multilineTextAlignment(.center)
        Button("OK") { state.showError = false }
          .buttonStyle(.borderedProminent)
      }
      .padding(30)
      .frame(width: 350)
    }
    .onAppear {
      Task { await state.refreshServerStatus() }
      Task { await state.scanModels() }
    }
  }

  var header: some View {
    HStack {
      Image(systemName: "leaf.fill")
        .font(.title).foregroundStyle(.green)
      VStack(alignment: .leading, spacing: 1) {
        Text("Canopy Manager").font(.title2).fontWeight(.bold)
        Text("MLX Local • Apple Silicon").font(.caption).foregroundStyle(.secondary)
      }
      Spacer()

      Button(action: { state.openCanopy() }) {
        Label("Canopy", systemImage: "terminal")
      }
      .buttonStyle(.bordered)
      .disabled(!MLXService.checkCanopyInstalled())

      Button(action: {
        let view = SettingsView().environmentObject(state)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Configurações"
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
      }) {
        Image(systemName: "gearshape")
      }
      .buttonStyle(.bordered)
    }
  }
}
