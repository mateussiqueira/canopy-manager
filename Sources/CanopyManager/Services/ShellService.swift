import Foundation

struct ShellService {
  static let mlxDir = "/Volumes/BACKUP/mlx"
  static let venv = "\(mlxDir)/venv"
  static let modelsDir = "\(mlxDir)/models"
  static let startScript = "\(mlxDir)/start-server.sh"
  static let canopyAuto = "\(HomeDir())/.local/bin/canopy-auto"

  static func HomeDir() -> String {
    FileManager.default.homeDirectoryForCurrentUser.path
  }

  static func shell(_ command: String) async -> String {
    await withCheckedContinuation { cont in
      DispatchQueue.global().async {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.launch()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
      }
    }
  }

  static func serverPID() async -> String {
    await shell("lsof -ti:8080 2>/dev/null || echo 'stopped'")
  }

  static func isServerRunning() async -> Bool {
    let pid = await serverPID()
    return pid.trimmingCharacters(in: .whitespacesAndNewlines) != "stopped" && !pid.isEmpty
  }

  static func startServer(modelId: String) async -> String {
    guard let model = MLXModel.byId(modelId) else { return "Modelo não encontrado: \(modelId)" }
    let modelPath = "\(modelsDir)/\(model.folderName)"
    let cmd = """
    source \(venv)/bin/activate && \
    nohup mlx_lm.server --model "\(modelPath)" --port 8080 --host 0.0.0.0 > /tmp/mlx-server.log 2>&1 &
    echo $!
    """
    return await shell(cmd)
  }

  static func stopServer() async -> String {
    await shell("kill $(lsof -ti:8080) 2>/dev/null; echo 'stopped'")
  }

  static func modelSizes() async -> [(String, String)] {
    let out = await shell("du -sh \(modelsDir)/*/ 2>/dev/null | sort -rh")
    return out.split(separator: "\n").compactMap { line in
      let parts = line.split(separator: "\t").map(String.init)
      guard parts.count >= 2 else { return nil }
      let name = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return (name, parts[0])
    }
  }

  static func runCanopy(prompt: String) async -> String {
    let escaped = prompt.replacingOccurrences(of: "'", with: "'\\''")
    return await shell("\(canopyAuto) '\(escaped)' 2>&1 | tail -5")
  }
}
