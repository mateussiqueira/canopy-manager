import SwiftUI

struct ContentView: View {
  @StateObject private var state = AppState()

  var body: some View {
    TabView {
      // Tab 1: Management
      managementView
        .tabItem { Label("Gerenciar", systemImage: "server.rack") }

      // Tab 2: Chat Multimodal
      ChatView()
        .environmentObject(state)
        .tabItem { Label("Chat", systemImage: "message.fill") }

      // Tab 3: Models
      ModelManagementView()
        .environmentObject(state)
        .tabItem { Label("Modelos", systemImage: "square.stack.3d.up.fill") }
    }
    .frame(minWidth: 800, minHeight: 600)
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
      .padding(30).frame(width: 350)
    }
    .onAppear {
      Task { await state.refreshServerStatus() }
      Task { await state.scanModels() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .toggleServer)) { _ in
      Task { await state.toggleServer() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .scanModels)) { _ in
      Task { await state.scanModels() }
    }
  }

  var managementView: some View {
    HSplitView {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header
          StatusDashboard().environmentObject(state)
          Divider()
          QuickPromptView().environmentObject(state)
        }
        .padding(16)
      }
      .frame(minWidth: 380)

      ServerLogView().environmentObject(state)
        .frame(minWidth: 300)
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
      Button("Settings") {
        let view = SettingsView().environmentObject(state)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Configurações"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
      }
      .buttonStyle(.bordered)
    }
  }
}
