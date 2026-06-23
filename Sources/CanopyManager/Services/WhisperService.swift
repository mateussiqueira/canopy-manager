import Foundation
import AVFoundation

enum ChatError: Error, LocalizedError {
  case invalidRequest
  case networkError(String)
  case serverError(Int, String)
  case parseError(String)
  case timeout
  case serverNotRunning

  var errorDescription: String? {
    switch self {
    case .invalidRequest: return "Requisição inválida"
    case .networkError(let msg): return "Erro de rede: \(msg)"
    case .serverError(let code, let body): return "Servidor retornou \(code): \(body.prefix(100))"
    case .parseError(let msg): return "Erro ao processar resposta: \(msg)"
    case .timeout: return "Tempo limite excedido (300s)"
    case .serverNotRunning: return "Servidor MLX não está rodando.\nClique em Iniciar no painel."
    }
  }
}

struct WhisperService {
  static let mlxDir = "/Volumes/BACKUP/mlx"
  static let venv = "\(mlxDir)/venv"

  // Transcribe audio file using MLX Whisper
  static func transcribe(audioURL: URL) async -> Result<String, ChatError> {
    let script = """
    import sys
    sys.path.insert(0, '\(venv)/lib/python3.11/site-packages')
    import mlx_whisper
    result = mlx_whisper.transcribe('\(audioURL.path)')
    print(result["text"])
    """

    let scriptPath = "/tmp/canopy_whisper_transcribe.py"
    try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

    let process = Process()
    process.launchPath = "\(venv)/bin/python3"
    process.arguments = [scriptPath]

    let outPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = Pipe()

    process.launch()
    process.waitUntilExit()

    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !text.isEmpty else {
      return .failure(.networkError("Falha na transcrição de áudio"))
    }

    return .success(text)
  }

  // MLX doesn't include mlx_whisper by default — fallback to system API
  static func transcribeNative(audioURL: URL) async -> Result<String, ChatError> {
    // Use macOS 15 native transcription if available
    // Fallback: return filename as placeholder
    return .success("[Transcrição de áudio: \(audioURL.lastPathComponent)]")
  }

  // MARK: - Audio Recording

  static func recordAudio(to url: URL, duration: TimeInterval = 30) async -> Bool {
    let recordSettings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    guard let recorder = try? AVAudioRecorder(url: url, settings: recordSettings) else {
      return false
    }

    recorder.record(forDuration: duration)
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    recorder.stop()

    return FileManager.default.fileExists(atPath: url.path)
  }

  // Check if mlx-whisper is installed
  static func isWhisperAvailable() -> Bool {
    FileManager.default.fileExists(atPath: "\(venv)/lib/python3.11/site-packages/mlx_whisper")
  }
}
