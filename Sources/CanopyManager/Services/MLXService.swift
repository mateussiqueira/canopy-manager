import Foundation

enum MLXError: Error, LocalizedError {
  case modelNotFound(String)
  case serverNotReady
  case processError(String)
  case timeout

  var errorDescription: String? {
    switch self {
    case .modelNotFound(let id): "Modelo não encontrado: \(id)"
    case .serverNotReady: "Servidor não respondeu após 30s"
    case .processError(let msg): msg
    case .timeout: "Comando excedeu o tempo limite"
    }
  }
}

struct PromptResult {
  let detectedModel: String
  let response: String
}

struct MLXService {
  static func shell(_ command: String, timeout: UInt32 = 60) async -> Result<String, MLXError> {
    await withCheckedContinuation { cont in
      DispatchQueue.global().async {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        process.launch()

        let deadline = DispatchTime.now() + .seconds(Int(timeout))
        DispatchQueue.global().asyncAfter(deadline: deadline) {
          if process.isRunning {
            process.terminate()
            cont.resume(returning: .failure(.timeout))
          }
        }

        process.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let errorOut = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && output.isEmpty {
          cont.resume(returning: .failure(.processError(errorOut.isEmpty ? "Exit code \(process.terminationStatus)" : errorOut)))
        } else {
          cont.resume(returning: .success(output))
        }
      }
    }
  }

  static func isServerRunning(port: String) async -> Bool {
    let result = await shell("lsof -ti:\(port) 2>/dev/null || echo 'stopped'", timeout: 5)
    switch result {
    case .success(let out):
      let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed != "stopped" && !trimmed.isEmpty
    case .failure: return false
    }
  }

  static func startServer(modelId: String, port: String, mlxDir: String) async -> Result<String, MLXError> {
    guard let model = MLXModel.byId(modelId) else {
      return .failure(.modelNotFound(modelId))
    }

    let modelPath = "\(mlxDir)/models/\(model.folderName)"
    let venv = "\(mlxDir)/venv"

    // Verify model exists
    guard FileManager.default.fileExists(atPath: modelPath) else {
      return .failure(.modelNotFound("\(model.name) não encontrado em \(modelPath)"))
    }

    let cmd = """
    source \(venv)/bin/activate && \
    nohup mlx_lm.server --model "\(modelPath)" --port \(port) --host 0.0.0.0 > /tmp/mlx-server.log 2>&1 & \
    echo $!
    """

    let result = await shell(cmd, timeout: 10)
    switch result {
    case .success(let pid):
      // Wait for server to be ready
      for _ in 0..<30 {
        if await isServerRunning(port: port) {
          return .success(pid.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
      }
      return .failure(.serverNotReady)
    case .failure(let error):
      return .failure(error)
    }
  }

  static func stopServer(port: String) async -> Result<String, MLXError> {
    await shell("kill $(lsof -ti:\(port)) 2>/dev/null; echo 'stopped'", timeout: 5)
  }

  static func tailLog(lines: Int = 10) -> String {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/mlx-server.log")),
          let content = String(data: data, encoding: .utf8) else { return "" }
    let parts = content.split(separator: "\n")
    return parts.suffix(lines).joined(separator: "\n") + "\n"
  }

  static func watchLogStream() -> AsyncStream<String> {
    AsyncStream { continuation in
      Task {
        var lastSize = 0
        while true {
          if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/mlx-server.log")) {
            if data.count > lastSize {
              let newData = data[lastSize...]
              if let newStr = String(data: newData, encoding: .utf8) {
                continuation.yield(newStr)
              }
              lastSize = data.count
            }
          }
          try? await Task.sleep(nanoseconds: 500_000_000)
        }
      }
    }
  }

  static func modelSizes(mlxDir: String) async -> [(String, String)] {
    let result = await shell("du -sh \(mlxDir)/models/*/ 2>/dev/null | sort -rh", timeout: 10)
    switch result {
    case .success(let out):
      return out.split(separator: "\n").compactMap { line in
        let parts = line.split(separator: "\t").map(String.init)
        guard parts.count >= 2 else { return nil }
        let name = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return (name, parts[0])
      }
    case .failure: return []
    }
  }

  static func runCanopy(prompt: String, mlxDir: String) async -> Result<PromptResult, MLXError> {
    let canopyAuto = "\(NSHomeDirectory())/.local/bin/canopy-auto"
    let escaped = prompt.replacingOccurrences(of: "'", with: "'\\''")

    // Detect model
    let detectCmd = "\(canopyAuto) --dry-run '\(escaped)' 2>&1 | grep 'Modelo selecionado' | sed 's/.*: //'"
    let detectResult = await shell(detectCmd, timeout: 10)
    let detectedModel: String
    switch detectResult {
    case .success(let out): detectedModel = out.trimmingCharacters(in: .whitespacesAndNewlines)
    case .failure: detectedModel = "auto"
    }

    // Run prompt
    let runResult = await shell("\(canopyAuto) '\(escaped)' 2>&1 | tail -20", timeout: 300)
    switch runResult {
    case .success(let output):
      return .success(PromptResult(detectedModel: detectedModel, response: output))
    case .failure(let error):
      return .failure(error)
    }
  }

  static func checkCanopyInstalled() -> Bool {
    let path = "\(NSHomeDirectory())/.local/bin/canopy"
    return FileManager.default.fileExists(atPath: path)
  }

  static func checkMlxInstalled(mlxDir: String) -> Bool {
    FileManager.default.fileExists(atPath: "\(mlxDir)/venv")
  }

  static func checkModelExists(modelId: String, mlxDir: String) -> Bool {
    guard let model = MLXModel.byId(modelId) else { return false }
    return FileManager.default.fileExists(atPath: "\(mlxDir)/models/\(model.folderName)")
  }
}
