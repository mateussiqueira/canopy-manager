import Foundation

struct ModelDownloadService {
  static func download(
    model: MLXModel,
    mlxDir: String,
    onProgress: @escaping (Double, String) -> Void
  ) async -> Result<Void, MLXError> {
    let modelPath = "\(mlxDir)/models/\(model.folderName)"
    let venv = "\(mlxDir)/venv"

    // Check if already downloaded
    if FileManager.default.fileExists(atPath: modelPath) {
      if let contents = try? FileManager.default.contentsOfDirectory(atPath: modelPath),
         contents.contains(where: { $0.hasSuffix(".safetensors") }) {
        return .success(())
      }
    }

    let hfModel = "mlx-community/\(model.folderName)"

    onProgress(0, "Baixando \(model.name) do HuggingFace...")

    let script = """
    import sys, json, time
    from huggingface_hub import snapshot_download
    from huggingface_hub.utils import HfHubHTTPError

    try:
      print("DOWNLOAD_START")
      sys.stdout.flush()
      snapshot_download(
        repo_id='\(hfModel)',
        local_dir='\(modelPath)',
        local_dir_use_symlinks=False,
        resume_download=True
      )
      print("DOWNLOAD_DONE")
    except HfHubHTTPError as e:
      print(f"HTTP_ERROR:{e}")
    except Exception as e:
      print(f"ERROR:{e}")
    """

    let scriptPath = "/tmp/canopy_download_model.py"
    try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

    let process = Process()
    process.launchPath = "\(venv)/bin/python3"
    process.arguments = [scriptPath]

    let outPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = Pipe()

    process.launch()

    // Monitor progress via file size changes
    var lastSize: UInt64 = 0
    let expectedSize = UInt64(model.sizeGB * 1e9)

    Task {
      while process.isRunning {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: modelPath),
           let size = attrs[.size] as? UInt64, size > 0 {
          let progress = min(Double(size) / Double(max(expectedSize, 1)), 1.0)
          await MainActor.run {
            onProgress(progress, "\(model.name): \(sizeFormatted(size)) / \(model.sizeGB) GB")
          }
          lastSize = size
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
      }
    }

    process.waitUntilExit()

    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if output.contains("DOWNLOAD_DONE") || output.contains("DOWNLOAD_START") {
      onProgress(1.0, "✅ Verificando arquivos...")
      return .success(())
    }

    if output.contains("HTTP_ERROR:404") {
      return .failure(.processError("Modelo \(hfModel) não encontrado no HuggingFace"))
    }

    return .success(())
  }

  static func sizeFormatted(_ bytes: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }
}
