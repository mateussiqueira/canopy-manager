import SwiftUI

struct ServerControlView: View {
  @Binding var selectedModel: String
  @Binding var isRunning: Bool
  @Binding var serverLog: String
  @State private var isStarting = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Servidor MLX").font(.headline)

      HStack {
        Circle()
          .fill(isRunning ? Color.green : Color.red)
          .frame(width: 10, height: 10)
        Text(isRunning ? "Rodando na porta 8080" : "Parado")
          .font(.subheadline).foregroundStyle(.secondary)
        Spacer()
      }

      HStack {
        Picker("Modelo", selection: $selectedModel) {
          ForEach(MLXModel.available) { model in
            HStack {
              Image(systemName: model.category.icon)
              Text(model.name)
            }.tag(model.id)
          }
        }
        .labelsHidden()
        .frame(width: 220)

        Button(isRunning ? "Parar" : "Iniciar") {
          Task { await toggleServer() }
        }
        .disabled(isStarting)
        .buttonStyle(.borderedProminent)
        .tint(isRunning ? .red : .green)

        if isStarting { ProgressView().scaleEffect(0.7) }
      }

      if !serverLog.isEmpty {
        ScrollView {
          Text(serverLog)
            .font(.caption).monospaced().foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 80)
        .padding(8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
      }
    }
    .onAppear { Task { isRunning = await ShellService.isServerRunning() } }
  }

  func toggleServer() async {
    isStarting = true
    if isRunning {
      _ = await ShellService.stopServer()
      isRunning = false
    } else {
      serverLog = "Iniciando \(selectedModel)...\n"
      let pid = await ShellService.startServer(modelId: selectedModel)
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      isRunning = await ShellService.isServerRunning()
      if isRunning {
        serverLog += "✅ Servidor rodando (PID: \(pid.trimmingCharacters(in: .whitespaces)))"
      } else {
        let log = await ShellService.shell("tail -5 /tmp/mlx-server.log 2>/dev/null")
        serverLog += "❌ Erro:\n\(log)"
      }
    }
    isStarting = false
  }
}
