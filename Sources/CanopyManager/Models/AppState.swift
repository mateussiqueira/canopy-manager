import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
  @Published var selectedModelId: String = UserDefaults.standard.string(forKey: "selectedModel") ?? "mistral-7b"
  @Published var isServerRunning = false
  @Published var serverLog = ""
  @Published var serverPid: String?
  @Published var modelSizes: [String: String] = [:]
  @Published var isScanningModels = true

  @Published var promptText = ""
  @Published var promptOutput = ""
  @Published var detectedModel = ""
  @Published var isProcessing = false
  @Published var errorMessage: String?
  @Published var showError = false

  @Published var downloadProgress: Double = 0
  @Published var downloadStatus = ""
  @Published var isDownloading = false
  @Published var showDownloadPanel = false

  @Published var settingsPort = UserDefaults.standard.string(forKey: "serverPort") ?? "8080"
  @Published var settingsMlxDir = UserDefaults.standard.string(forKey: "mlxDir") ?? "/Volumes/BACKUP/mlx"

  var selectedModel: MLXModel? { MLXModel.byId(selectedModelId) }

  func save() {
    UserDefaults.standard.set(selectedModelId, forKey: "selectedModel")
    UserDefaults.standard.set(settingsPort, forKey: "serverPort")
    UserDefaults.standard.set(settingsMlxDir, forKey: "mlxDir")
  }

  // MARK: - Server

  func refreshServerStatus() async {
    isServerRunning = await MLXService.isServerRunning(port: settingsPort)
  }

  func toggleServer() async {
    if isServerRunning {
      await stopServer()
    } else {
      await startServer()
    }
  }

  func startServer() async {
    isProcessing = true
    serverLog = "🚀 Iniciando servidor com \(selectedModel?.name ?? selectedModelId)...\n"

    let result = await MLXService.startServer(
      modelId: selectedModelId,
      port: settingsPort,
      mlxDir: settingsMlxDir
    )

    switch result {
    case .success(let pid):
      serverPid = pid
      isServerRunning = true
      serverLog += "✅ Servidor rodando (PID: \(pid))\n"
      // Watch logs in background
      Task { await streamServerLog() }
    case .failure(let error):
      serverLog += "❌ \(error.localizedDescription)\n"
      let logTail = await MLXService.tailLog(lines: 10)
      serverLog += logTail
      errorMessage = error.localizedDescription
      showError = true
    }

    isProcessing = false
  }

  func stopServer() async {
    isProcessing = true
    _ = await MLXService.stopServer(port: settingsPort)
    isServerRunning = false
    serverPid = nil
    serverLog += "⏹ Servidor parado\n"
    isProcessing = false
  }

  func streamServerLog() async {
    while isServerRunning {
      let newLog = await MLXService.tailLog(lines: 5)
      if !newLog.isEmpty {
        serverLog += newLog
      }
      try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
  }

  // MARK: - Models

  func scanModels() async {
    isScanningModels = true
    let sizes = await MLXService.modelSizes(mlxDir: settingsMlxDir)
    modelSizes = Dictionary(uniqueKeysWithValues: sizes)
    isScanningModels = false
  }

  func downloadModel(_ modelId: String) async {
    guard let model = MLXModel.byId(modelId) else { return }
    isDownloading = true
    downloadProgress = 0
    downloadStatus = "Preparando download de \(model.name)..."
    showDownloadPanel = true

    let result = await ModelDownloadService.download(
      model: model,
      mlxDir: settingsMlxDir,
      onProgress: { progress, status in
        Task { @MainActor in
          self.downloadProgress = progress
          self.downloadStatus = status
        }
      }
    )

    switch result {
    case .success:
      downloadStatus = "✅ \(model.name) baixado com sucesso!"
      await scanModels()
    case .failure(let error):
      downloadStatus = "❌ Erro: \(error.localizedDescription)"
      errorMessage = error.localizedDescription
      showError = true
    }

    try? await Task.sleep(nanoseconds: 2_000_000_000)
    isDownloading = false
    showDownloadPanel = false
  }

  // MARK: - Prompt

  func processPrompt() async {
    guard !promptText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    isProcessing = true
    promptOutput = ""
    detectedModel = ""

    let text = promptText.trimmingCharacters(in: .whitespaces)

    // Detect model
    if let model = selectedModel {
      detectedModel = model.name
    }

    // Call MLX API directly (no canopy CLI overhead)
    let result = await MLXChatService.sendMessage(text: text)
    switch result {
    case .success(let response):
      promptOutput = response.content
    case .failure(let error):
      promptOutput = "❌ \(error.localizedDescription)"
    }

    isProcessing = false
  }

  // MARK: - Canopy

  func openCanopy() {
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = ["-a", "Terminal", "\(NSHomeDirectory())/.local/bin/canopy"]
    try? task.run()
  }
}
