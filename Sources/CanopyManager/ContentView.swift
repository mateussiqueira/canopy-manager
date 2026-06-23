import SwiftUI

struct ContentView: View {
  @State private var selectedModel = "mistral-7b"
  @State private var isRunning = false
  @State private var serverLog = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        ServerControlView(selectedModel: $selectedModel, isRunning: $isRunning, serverLog: $serverLog)
        Divider()
        QuickPromptView(selectedModel: $selectedModel, isRunning: $isRunning)
        Divider()
        ModelsListView()
      }
      .padding(20)
    }
    .frame(minWidth: 600, minHeight: 700)
  }

  var header: some View {
    HStack {
      Image(systemName: "leaf.fill")
        .font(.title).foregroundStyle(.green)
      VStack(alignment: .leading, spacing: 2) {
        Text("Canopy Manager").font(.title2).fontWeight(.bold)
        Text("MLX Local • Apple Silicon").font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Button("Abrir Canopy") {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "open -a Terminal \(ShellService.HomeDir())/.local/bin/canopy"]
        try? task.run()
      }
      .buttonStyle(.bordered)
    }
  }
}
